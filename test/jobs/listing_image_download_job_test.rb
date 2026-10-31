# frozen_string_literal: true

require "test_helper"

class ListingImageDownloadJobTest < ActiveSupport::TestCase
  def build_listing(ebay_item_id:, raw:)
    Listing.create!(
      ebay_item_id:,
      title: "Test Listing",
      price_cents: 1000,
      currency: "USD",
      url: "https://sandbox.ebay.com/itm/#{ebay_item_id}",
      raw:,
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )
  end

  test "attaches every image and stamps images_downloaded_at on success" do
    listing = build_listing ebay_item_id: "v1|1|0", raw: {
      "image" => { "imageUrl" => "https://images.example.com/primary.jpg" },
      "additionalImages" => [ { "imageUrl" => "https://images.example.com/second.jpg" } ]
    }
    stub_request(:get, "https://images.example.com/primary.jpg")
      .to_return(status: 200, body: "fake-bytes-1", headers: { "Content-Type" => "image/jpeg" })
    stub_request(:get, "https://images.example.com/second.jpg")
      .to_return(status: 200, body: "fake-bytes-2", headers: { "Content-Type" => "image/jpeg" })

    ListingImageDownloadJob.perform_now listing.id

    listing.reload
    assert_equal 2, listing.listing_images.count
    assert listing.images_downloaded_at.present?
  end

  test "does not stamp images_downloaded_at when a download fails" do
    listing = build_listing ebay_item_id: "v1|2|0", raw: {
      "image" => { "imageUrl" => "https://images.example.com/broken.jpg" }
    }
    stub_request(:get, "https://images.example.com/broken.jpg").to_return status: 500

    assert_raises(RuntimeError) { ListingImageDownloadJob.perform_now listing.id }

    assert_nil listing.reload.images_downloaded_at
    assert_equal 0, listing.listing_images.count
  end

  test "does not re-download or duplicate an image whose source_url is already attached" do
    listing = build_listing ebay_item_id: "v1|3|0", raw: {
      "image" => { "imageUrl" => "https://images.example.com/primary.jpg" }
    }
    listing.listing_images.create! source_url: "https://images.example.com/primary.jpg"

    ListingImageDownloadJob.perform_now listing.id

    assert_not_requested :get, "https://images.example.com/primary.jpg"
    assert_equal 1, listing.reload.listing_images.count
    assert listing.images_downloaded_at.present?
  end
end
