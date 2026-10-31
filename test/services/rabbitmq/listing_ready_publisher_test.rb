# frozen_string_literal: true

require "test_helper"

class Rabbitmq::ListingReadyPublisherTest < ActiveSupport::TestCase
  Fake = Struct.new :id

  test "publishes a message carrying each listing's id over one connection, yielding each one back after its own publish" do
    listings = [ Fake.new(999_001), Fake.new(999_002) ]
    yielded = []

    Rabbitmq::ListingReadyPublisher.new.publish_batch(listings) { |listing| yielded << listing.id }

    assert_equal [ { "listing_id" => 999_001 }, { "listing_id" => 999_002 } ], published_listing_ready_messages
    assert_equal [ 999_001, 999_002 ], yielded
  end
end
