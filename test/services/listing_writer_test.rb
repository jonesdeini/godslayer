# frozen_string_literal: true

require "test_helper"

class ListingWriterTest < ActiveSupport::TestCase
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

  test "builds a new, unsaved listing with first_seen_at and last_seen_at set" do
    listing = ListingWriter.write RAW

    assert listing.new_record?
    assert_equal "v1|110591042924|0", listing.ebay_item_id
    assert_equal 49999, listing.price_cents
    assert_equal "95112", listing.postal_code
    assert_equal "US", listing.country
    assert_not_nil listing.first_seen_at
    assert_equal listing.first_seen_at, listing.last_seen_at
  end

  test "on a repeat sighting with an unchanged seller_item_revision, leaves the existing listing untouched" do
    original = ListingWriter.write RAW
    original.save!
    original_last_seen_at = original.last_seen_at

    travel 1.hour do
      resweep = ListingWriter.write RAW.merge("title" => "Different title, same revision", "price" => { "value" => "399.99", "currency" => "USD" })

      refute resweep.new_record?
      refute resweep.changed?
      assert_equal original.id, resweep.id
      assert_equal "Test Laptop Computer 16GB RAM 512GB SSD", resweep.title
      assert_equal 49999, resweep.price_cents
      assert_equal original_last_seen_at, resweep.last_seen_at
    end
  end

  test "on a repeat sighting with a changed seller_item_revision, reassigns content and refreshes last_seen_at" do
    original = ListingWriter.write RAW
    original.save!
    original_first_seen_at = original.first_seen_at

    travel 1.hour do
      revised_raw = RAW.merge(
        "title" => "Changed Title",
        "price" => { "value" => "399.99", "currency" => "USD" },
        "sellerItemRevision" => "3"
      )
      resweep = ListingWriter.write revised_raw

      refute resweep.new_record?
      assert resweep.changed?
      assert_equal original.id, resweep.id
      assert_equal "Changed Title", resweep.title
      assert_equal 39999, resweep.price_cents
      assert_equal "3", resweep.seller_item_revision
      assert_equal original_first_seen_at.to_i, resweep.first_seen_at.to_i
      assert_equal Time.current.to_i, resweep.last_seen_at.to_i
    end
  end
end
