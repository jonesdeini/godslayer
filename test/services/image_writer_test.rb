# frozen_string_literal: true

require "test_helper"

class ImageWriterTest < ActiveSupport::TestCase
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

  test "creates an image row at the given position" do
    image_id = ImageWriter.write listing_id: @listing.id, position: 0, source_url: "https://example.com/a.jpg"

    image = Image.find image_id
    assert_equal @listing.id, image.listing_id
    assert_equal 0, image.position
    assert_equal "https://example.com/a.jpg", image.source_url
    assert_nil image.local_path
  end

  test "on a repeat sighting at the same position, refreshes source_url without touching local_path" do
    first_id = ImageWriter.write listing_id: @listing.id, position: 0, source_url: "https://example.com/old.jpg"
    Image.find(first_id).update! local_path: "/images/old.jpg", downloaded_at: Time.current

    second_id = ImageWriter.write listing_id: @listing.id, position: 0, source_url: "https://example.com/new.jpg"

    assert_equal first_id, second_id
    image = Image.find second_id
    assert_equal "https://example.com/new.jpg", image.source_url
    assert_equal "/images/old.jpg", image.local_path
  end
end
