# frozen_string_literal: true

require "test_helper"

class Rabbitmq::ListingReadyPublisherTest < ActiveSupport::TestCase
  setup { purge_listing_ready_queue }

  test "publishes a message carrying the listing id, for real, against a live broker" do
    Rabbitmq::ListingReadyPublisher.publish listing_id: 999_001

    messages = pop_listing_ready_messages matching: 999_001
    assert_equal 1, messages.size
  end
end
