# frozen_string_literal: true

require "test_helper"

class ListingLabelWriterTest < ActiveSupport::TestCase
  def listing
    @listing ||= Listing.create!(
      ebay_item_id: "v1|label-writer-test|0",
      title: "Test Listing",
      price: 10.00,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/label-writer-test",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )
  end

  test "writes a new active label" do
    label = ListingLabelWriter.write listing:, label: "computer", model: "claude-haiku-4-5-20251001"

    assert label.persisted?
    assert label.active?
    assert_equal "computer", label.label
  end

  test "deactivates the previous active label for the listing" do
    first = ListingLabelWriter.write listing:, label: "part", model: "claude-haiku-4-5-20251001"

    second = ListingLabelWriter.write listing:, label: "computer", model: "claude-haiku-4-5-20251001"

    assert_not first.reload.active?
    assert second.active?
  end
end
