# frozen_string_literal: true

require "test_helper"

class ListingWriterTest < ActiveSupport::TestCase
  test "creates a new listing, setting first_seen_at and last_seen_at" do
    listing_id = ListingWriter.write(
      ebay_item_id: "v1|110591042924|0",
      title: "Test Laptop Computer 16GB RAM 512GB SSD",
      price_cents: 49999,
      currency: "USD",
      condition: "New",
      category_id: "177",
      seller: "testuser_developer514",
      postal_code: "95112",
      country: "US",
      url: "https://sandbox.ebay.com/itm/110591042924",
      raw: { "itemId" => "v1|110591042924|0" }
    )

    listing = Listing.find listing_id
    assert_equal "v1|110591042924|0", listing.ebay_item_id
    assert_equal 49999, listing.price_cents
    assert_equal "95112", listing.postal_code
    assert_equal "US", listing.country
    assert_not_nil listing.first_seen_at
    assert_equal listing.first_seen_at, listing.last_seen_at
  end

  test "on a repeat sighting, only updates last_seen_at, price_cents, and raw - not first_seen_at or title" do
    original_id = ListingWriter.write(
      ebay_item_id: "v1|110591042924|0",
      title: "Original Title",
      price_cents: 49999,
      currency: "USD",
      condition: "New",
      category_id: "177",
      seller: "testuser_developer514",
      postal_code: "95112",
      country: "US",
      url: "https://sandbox.ebay.com/itm/110591042924",
      raw: { "version" => 1 }
    )
    original_first_seen_at = Listing.find(original_id).first_seen_at

    travel 1.hour do
      updated_id = ListingWriter.write(
        ebay_item_id: "v1|110591042924|0",
        title: "Changed Title - should NOT be saved",
        price_cents: 39999,
        currency: "USD",
        condition: "New",
        category_id: "177",
        seller: "testuser_developer514",
        postal_code: "95112",
        country: "US",
        url: "https://sandbox.ebay.com/itm/110591042924",
        raw: { "version" => 2 }
      )

      assert_equal original_id, updated_id
      listing = Listing.find updated_id
      assert_equal 39999, listing.price_cents
      assert_equal({ "version" => 2 }, listing.raw)
      assert_equal original_first_seen_at.to_i, listing.first_seen_at.to_i
      assert_equal "Original Title", listing.title
      assert_equal Time.current.to_i, listing.last_seen_at.to_i
    end
  end
end
