# frozen_string_literal: true

require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "primary_image_url and additional_image_urls read straight from raw" do
    listing = Listing.new raw: {
      "image" => { "imageUrl" => "https://images.example.com/primary.jpg" },
      "additionalImages" => [
        { "imageUrl" => "https://images.example.com/second.jpg" },
        { "imageUrl" => "https://images.example.com/third.jpg" }
      ]
    }

    assert_equal "https://images.example.com/primary.jpg", listing.primary_image_url
    assert_equal [ "https://images.example.com/second.jpg", "https://images.example.com/third.jpg" ], listing.additional_image_urls
  end

  test "additional_image_urls is empty when there's no additionalImages key at all" do
    listing = Listing.new raw: { "image" => { "imageUrl" => "https://images.example.com/primary.jpg" } }

    assert_equal [], listing.additional_image_urls
  end

  test "primary_image_url is nil when there's no image key at all, without raising" do
    listing = Listing.new raw: { "additionalImages" => [] }

    assert_nil listing.primary_image_url
  end
end
