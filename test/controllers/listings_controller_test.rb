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

  test "index sorts listings by price descending, regardless of verdict" do
    cheap_mismatch = create_listing "cheap-mismatch"
    cheap_mismatch.update! price_cents: 1000
    DeterminationWriter.write listing: cheap_mismatch, field: "ram", verdict: "mismatch", claimed_value: 16,
      claimed_unit: "GB", photo_value: 32, photo_unit: "GB"
    pricey_pending = create_listing "pricey-pending"
    pricey_pending.update! price_cents: 5000

    get listings_path

    assert_response :success
    body = response.body
    assert_operator body.index(pricey_pending.title), :<, body.index(cheap_mismatch.title)
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
