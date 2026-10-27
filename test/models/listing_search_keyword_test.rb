# frozen_string_literal: true

require "test_helper"

class ListingSearchKeywordTest < ActiveSupport::TestCase
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

  test "the same listing/keyword pairing can't be recorded twice" do
    ListingSearchKeyword.create! listing: @listing, search_keyword: search_keywords(:one)

    duplicate = ListingSearchKeyword.new listing: @listing, search_keyword: search_keywords(:one)

    refute duplicate.valid?
  end
end
