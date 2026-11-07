# frozen_string_literal: true

require "test_helper"

class ListingLabelTest < ActiveSupport::TestCase
  def listing
    @listing ||= Listing.create!(
      ebay_item_id: "v1|listing-label-test|0",
      title: "Test Listing",
      price: 10.00,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/listing-label-test",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )
  end

  test "requires a label in the known set" do
    label = listing.listing_labels.build label: "surely_not", model: "claude-haiku-4-5-20251001"

    assert_not label.valid?
    assert_includes label.errors[:label], "is not included in the list"
  end

  test "requires a model" do
    label = listing.listing_labels.build label: "computer"

    assert_not label.valid?
    assert_includes label.errors[:model], "can't be blank"
  end

  test "is valid with a known label and a model" do
    label = listing.listing_labels.build label: "computer", model: "claude-haiku-4-5-20251001"

    assert label.valid?
  end
end
