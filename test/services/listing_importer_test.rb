# frozen_string_literal: true

require "test_helper"

class ListingImporterTest < ActiveSupport::TestCase
  # Trimmed from a real sandbox item-detail response (2026-10-26) - same
  # field names/shapes, just with the (unrelated) 35-state tax array and
  # other noise stripped out for readability.
  REAL_SHAPED_DETAIL = {
    "itemId" => "v1|110591042924|0",
    "title" => "Test Laptop Computer 16GB RAM 512GB SSD",
    "price" => { "value" => "499.99", "currency" => "USD" },
    "condition" => "New",
    "categoryId" => "177",
    "itemLocation" => { "city" => "San Jose", "stateOrProvince" => "California", "postalCode" => "951**", "country" => "US" },
    "image" => { "imageUrl" => "https://images.example.com/primary.jpg" },
    "additionalImages" => [
      { "imageUrl" => "https://images.example.com/second.jpg" },
      { "imageUrl" => "https://images.example.com/third.jpg" }
    ],
    "seller" => { "username" => "testuser_developer514", "feedbackScore" => 1000 },
    "itemWebUrl" => "https://sandbox.ebay.com/itm/Test-Laptop/110591042924",
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

  test "imports every image in order: primary first, then additionalImages" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    images = Image.where(listing_id:).order :position
    assert_equal 3, images.size
    assert_equal [ "https://images.example.com/primary.jpg",
                  "https://images.example.com/second.jpg",
                  "https://images.example.com/third.jpg" ], images.map(&:source_url)
    assert_equal [ 0, 1, 2 ], images.map(&:position)
  end

  test "handles an item with only a primary image, no additionalImages key at all" do
    detail = JSON.parse REAL_SHAPED_DETAIL
    detail.delete "additionalImages"

    listing_id = ListingImporter.import detail.to_json, search_keyword_id: search_keywords(:one).id

    assert_equal 1, Image.where(listing_id:).count
  end

  test "re-importing the same item is idempotent" do
    first_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id
    second_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    assert_equal first_id, second_id
    assert_equal 1, Listing.where(ebay_item_id: "v1|110591042924|0").count
    assert_equal 3, Image.where(listing_id: first_id).count
  end

  test "records which keyword surfaced the listing" do
    listing_id = ListingImporter.import REAL_SHAPED_DETAIL, search_keyword_id: search_keywords(:one).id

    assert ListingSearchKeyword.exists?(listing_id:, search_keyword_id: search_keywords(:one).id)
  end
end
