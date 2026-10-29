# frozen_string_literal: true

require "test_helper"

class ListingTest < ActiveSupport::TestCase
  RAW = {
    "itemId" => "v1|110591042924|0",
    "title" => "Test Laptop Computer 16GB RAM 512GB SSD",
    "price" => { "value" => "499.99", "currency" => "USD" },
    "condition" => "New",
    "categoryId" => "177",
    "seller" => { "username" => "testuser_developer514" },
    "itemLocation" => { "postalCode" => "95112", "country" => "US" },
    "itemWebUrl" => "https://sandbox.ebay.com/itm/110591042924",
    "sellerItemRevision" => nil
  }.freeze

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

  test "from_ebay_json builds a new, unsaved listing with price parsed to cents and first/last_seen_at set" do
    listing = Listing.from_ebay_json RAW

    assert listing.new_record?
    assert_equal "v1|110591042924|0", listing.ebay_item_id
    assert_equal 49999, listing.price_cents
    assert_equal "95112", listing.postal_code
    assert_equal "US", listing.country
    assert_not_nil listing.first_seen_at
    assert_equal listing.first_seen_at, listing.last_seen_at
  end

  test "from_ebay_json reassigns content unconditionally - gating whether that's worth persisting is the caller's job" do
    original = Listing.from_ebay_json RAW
    original.save!

    resweep = Listing.from_ebay_json RAW.merge("title" => "Different title, same revision")

    refute resweep.new_record?
    assert resweep.changed?
    assert_equal "Different title, same revision", resweep.title
    refute resweep.seller_item_revision_changed?
  end

  test "from_ebay_json flags seller_item_revision_changed? when the revision genuinely differs" do
    original = Listing.from_ebay_json RAW
    original.save!

    resweep = Listing.from_ebay_json RAW.merge("sellerItemRevision" => "3")

    assert resweep.seller_item_revision_changed?
  end
end
