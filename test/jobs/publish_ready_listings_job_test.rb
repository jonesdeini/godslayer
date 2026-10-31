# frozen_string_literal: true

require "test_helper"

class PublishReadyListingsJobTest < ActiveSupport::TestCase
  def build_listing(ebay_item_id:, images_downloaded_at:, published_at:)
    Listing.create!(
      ebay_item_id:,
      title: "Test Listing",
      price_cents: 1000,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/#{ebay_item_id}",
      raw: {},
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      images_downloaded_at:,
      published_at:
    )
  end

  test "publishes only listings with images downloaded and not yet published, stamping published_at" do
    ready = build_listing ebay_item_id: "ready", images_downloaded_at: Time.current, published_at: nil
    build_listing ebay_item_id: "no-images-yet", images_downloaded_at: nil, published_at: nil
    build_listing ebay_item_id: "already-published", images_downloaded_at: Time.current, published_at: Time.current

    PublishReadyListingsJob.perform_now

    assert_equal [ { "listing_id" => ready.id } ], published_listing_ready_messages
    assert ready.reload.published_at.present?
  end
end
