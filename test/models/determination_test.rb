# frozen_string_literal: true

require "test_helper"

class DeterminationTest < ActiveSupport::TestCase
  def listing
    @listing ||= Listing.create!(
      ebay_item_id: "v1|determination-test|0",
      title: "Test Listing",
      price: 10.00,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/determination-test",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )
  end

  test "requires a verdict in the known set" do
    determination = listing.determinations.build field: "ram", verdict: "surely_not"

    assert_not determination.valid?
    assert_includes determination.errors[:verdict], "is not included in the list"
  end

  test "requires a field" do
    determination = listing.determinations.build verdict: "match"

    assert_not determination.valid?
    assert_includes determination.errors[:field], "can't be blank"
  end

  test "is valid with a known verdict and a field" do
    determination = listing.determinations.build field: "ram", verdict: "match"

    assert determination.valid?
  end
end
