# frozen_string_literal: true

require "test_helper"

class Rabbitmq::ListingReadyPublisherTest < ActiveSupport::TestCase
  test "publishes a message carrying the listing id" do
    Rabbitmq::ListingReadyPublisher.publish listing_id: 999_001

    assert_equal [ { "listing_id" => 999_001 } ], published_listing_ready_messages
  end
end
