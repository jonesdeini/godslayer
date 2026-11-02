# frozen_string_literal: true

require "test_helper"

class DeterminationWriterTest < ActiveSupport::TestCase
  def listing
    @listing ||= Listing.create!(
      ebay_item_id: "v1|writer-test|0",
      title: "Test Listing",
      price_cents: 1000,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/writer-test",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )
  end

  test "writes a new active determination" do
    determination = DeterminationWriter.write listing:, field: "ram", verdict: "mismatch",
      claimed_value: 16, claimed_unit: "GB", photo_value: 32, photo_unit: "GB"

    assert determination.persisted?
    assert determination.active?
    assert_equal "mismatch", determination.verdict
  end

  test "deactivates the previous active determination for the same field, leaving others alone" do
    first = DeterminationWriter.write listing:, field: "ram", verdict: "match"
    other_field = DeterminationWriter.write listing:, field: "storage", verdict: "match"

    second = DeterminationWriter.write listing:, field: "ram", verdict: "mismatch"

    assert_not first.reload.active?
    assert second.active?
    assert other_field.reload.active?
  end
end
