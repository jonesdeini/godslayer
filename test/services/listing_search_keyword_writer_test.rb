# frozen_string_literal: true

require "test_helper"

class ListingSearchKeywordWriterTest < ActiveSupport::TestCase
  setup do
    @listing = Listing.create!(
      ebay_item_id: "v1|110591042924|0",
      title: "Test Laptop",
      price_cents: 49999,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/110591042924",
      raw: {},
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )
  end

  test "creates a join row linking the listing to the keyword" do
    ListingSearchKeywordWriter.write listing_id: @listing.id, search_keyword_id: search_keywords(:one).id

    assert ListingSearchKeyword.exists?(listing_id: @listing.id, search_keyword_id: search_keywords(:one).id)
  end

  test "writing the same pairing twice doesn't create a duplicate row" do
    ListingSearchKeywordWriter.write listing_id: @listing.id, search_keyword_id: search_keywords(:one).id
    ListingSearchKeywordWriter.write listing_id: @listing.id, search_keyword_id: search_keywords(:one).id

    assert_equal 1, ListingSearchKeyword.where(listing_id: @listing.id, search_keyword_id: search_keywords(:one).id).count
  end
end
