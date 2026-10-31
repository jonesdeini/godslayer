# frozen_string_literal: true

require "test_helper"

class ListingImporterTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Trimmed from a real sandbox item-detail response (2026-10-26) - same
  # field names/shapes, just with the (unrelated) 35-state tax array and
  # other noise stripped out for readability.
  REAL_SHAPED_DETAIL = {
    "itemId" => "v1|110591042924|0",
    "title" => "Test Laptop Computer 16GB RAM 512GB SSD",
    "price" => { "value" => "499.99", "currency" => "USD" },
    "condition" => "New",
    "categoryId" => "177",
    "categoryPath" => "Computers/Tablets & Networking|Laptops & Netbooks|PC Laptops & Netbooks",
    "itemLocation" => { "city" => "San Jose", "stateOrProvince" => "California", "postalCode" => "951**", "country" => "US" },
    "image" => { "imageUrl" => "https://images.example.com/primary.jpg" },
    "additionalImages" => [
      { "imageUrl" => "https://images.example.com/second.jpg" },
      { "imageUrl" => "https://images.example.com/third.jpg" }
    ],
    "seller" => { "username" => "testuser_developer514", "feedbackScore" => 1000 },
    "itemWebUrl" => "https://sandbox.ebay.com/itm/Test-Laptop/110591042924",
    "buyingOptions" => [ "FIXED_PRICE", "BEST_OFFER" ],
    "description" => "<p>A laptop.</p>",
    "localizedAspects" => [
      { "type" => "STRING", "name" => "Processor", "value" => "Intel Core i5" },
      { "type" => "STRING", "name" => "RAM Size", "value" => "16 GB" }
    ]
  }.to_json

  test "imports a listing with price parsed to cents and location fields pulled straight from itemLocation" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    listing = Listing.find listing_id
    assert_equal "v1|110591042924|0", listing.ebay_item_id
    assert_equal 49999, listing.price_cents
    assert_equal "USD", listing.currency
    assert_equal "951**", listing.postal_code
    assert_equal "US", listing.country
    assert_equal "testuser_developer514", listing.seller
    assert_equal JSON.parse(REAL_SHAPED_DETAIL), listing.raw
  end

  test "re-importing the same item is idempotent" do
    first_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id
    second_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    assert_equal first_id, second_id
    assert_equal 1, Listing.where(ebay_item_id: "v1|110591042924|0").count
  end

  test "schedules a delayed job to link the listing to the keyword, rather than writing the join inline" do
    ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    assert_enqueued_with job: ListingSearchKeywordLinkJob,
      args: [ { ebay_item_id: "v1|110591042924|0", search_keyword_id: search_keywords(:one).id } ]
  end

  test "seller_item_revision is nil when eBay doesn't send one (never-revised listing)" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    assert_nil Listing.find(listing_id).seller_item_revision
  end

  test "seller_item_revision is pulled from the detail response when present" do
    detail = JSON.parse(REAL_SHAPED_DETAIL).merge("sellerItemRevision" => "3").to_json

    listing_id = ListingImporter.import detail, search_keyword_id: search_keywords(:one).id

    assert_equal "3", Listing.find(listing_id).seller_item_revision
  end

  test "a resweep with no real revision does not touch last_seen_at or price_cents" do
    ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id
    original_last_seen_at = Listing.find_by!(ebay_item_id: "v1|110591042924|0").last_seen_at

    travel 1.hour do
      changed_price = JSON.parse REAL_SHAPED_DETAIL
      changed_price["price"]["value"] = "399.99"
      ListingImporter.import changed_price.to_json, search_keyword_id: search_keywords(:one).id

      listing = Listing.find_by! ebay_item_id: "v1|110591042924|0"
      assert_equal 49999, listing.price_cents
      assert_equal original_last_seen_at, listing.last_seen_at
    end
  end

  test "schedules the image download job for a brand new listing" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    assert_enqueued_with job: ListingImageDownloadJob, args: [ listing_id ]
  end

  test "does not re-schedule the image download job when re-swept with no real revision" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    assert_no_enqueued_jobs only: ListingImageDownloadJob do
      ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id
    end
  end

  test "re-schedules the image download job when a real revision comes in" do
    ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id
    revised = JSON.parse(REAL_SHAPED_DETAIL).merge("sellerItemRevision" => "2").to_json

    listing_id = ListingImporter.import revised, search_keyword_id: search_keywords(:one).id

    assert_enqueued_with job: ListingImageDownloadJob, args: [ listing_id ]
  end

  test "resets published_at when a real revision comes in, so the listing is picked up for republishing" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id
    Listing.find(listing_id).update! published_at: Time.current
    revised = JSON.parse(REAL_SHAPED_DETAIL).merge("sellerItemRevision" => "2").to_json

    ListingImporter.import revised, search_keyword_id: search_keywords(:one).id

    assert_nil Listing.find(listing_id).published_at
  end

  test "pulls category_path and the buying-option flags straight from the detail response" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    listing = Listing.find listing_id
    assert_equal "Computers/Tablets & Networking|Laptops & Netbooks|PC Laptops & Netbooks", listing.category_path
    assert listing.fixed_price
    assert_not listing.auction
    assert listing.best_offer
  end

  test "description and localized_aspects derive from raw" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    listing = Listing.find listing_id
    assert_equal "<p>A laptop.</p>", listing.description
    assert_equal [
      { "type" => "STRING", "name" => "Processor", "value" => "Intel Core i5" },
      { "type" => "STRING", "name" => "RAM Size", "value" => "16 GB" }
    ], listing.localized_aspects
  end
end
