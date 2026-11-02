# frozen_string_literal: true

require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  def create_listing(ebay_item_id)
    Listing.create!(
      ebay_item_id:,
      title: "Test Listing #{ebay_item_id}",
      price_cents: 1000,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/#{ebay_item_id}",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      raw: {}
    )
  end

  test "index lists listings, sorting mismatches and matches above no_evidence and pending" do
    pending = create_listing "pending"
    no_evidence = create_listing "no-evidence"
    DeterminationWriter.write listing: no_evidence, field: "ram", verdict: "no_evidence"
    mismatch = create_listing "mismatch"
    DeterminationWriter.write listing: mismatch, field: "ram", verdict: "mismatch", claimed_value: 16,
      claimed_unit: "GB", photo_value: 32, photo_unit: "GB"

    get listings_path

    assert_response :success
    body = response.body
    assert_operator body.index(mismatch.title), :<, body.index(no_evidence.title)
    assert_operator body.index(no_evidence.title), :<, body.index(pending.title)
  end

  test "show renders a listing with its active determination" do
    listing = create_listing "show-test"
    DeterminationWriter.write listing:, field: "ram", verdict: "mismatch", claimed_value: 16,
      claimed_unit: "GB", photo_value: 32, photo_unit: "GB"

    get listing_path(listing)

    assert_response :success
    assert_match "mismatch", response.body
  end

  test "show renders a listing with no determination yet" do
    listing = create_listing "pending-show-test"

    get listing_path(listing)

    assert_response :success
    assert_match "Pending", response.body
  end
end
