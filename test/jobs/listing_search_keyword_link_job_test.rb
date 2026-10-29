# frozen_string_literal: true

require "test_helper"

class ListingSearchKeywordLinkJobTest < ActiveJob::TestCase
  test "links the listing to the keyword once the listing exists" do
    listing = ListingWriter.write(
      "itemId" => "v1|110591042924|0",
      "title" => "Test Laptop",
      "price" => { "value" => "499.99", "currency" => "USD" },
      "itemWebUrl" => "https://sandbox.ebay.com/itm/110591042924"
    )
    listing.save!

    ListingSearchKeywordLinkJob.perform_now ebay_item_id: listing.ebay_item_id, search_keyword_id: search_keywords(:one).id

    assert ListingSearchKeyword.exists?(listing_id: listing.id, search_keyword_id: search_keywords(:one).id)
  end

  test "writing the same pairing twice doesn't create a duplicate row" do
    listing = ListingWriter.write(
      "itemId" => "v1|110591042924|0",
      "title" => "Test Laptop",
      "price" => { "value" => "499.99", "currency" => "USD" },
      "itemWebUrl" => "https://sandbox.ebay.com/itm/110591042924"
    )
    listing.save!

    2.times { ListingSearchKeywordLinkJob.perform_now ebay_item_id: listing.ebay_item_id, search_keyword_id: search_keywords(:one).id }

    assert_equal 1, ListingSearchKeyword.where(listing_id: listing.id, search_keyword_id: search_keywords(:one).id).count
  end

  test "raises if the listing was never actually written, instead of silently doing nothing" do
    assert_raises ActiveRecord::RecordNotFound do
      ListingSearchKeywordLinkJob.perform_now ebay_item_id: "does-not-exist", search_keyword_id: search_keywords(:one).id
    end
  end
end
