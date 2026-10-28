# frozen_string_literal: true

module Rabbitmq
  class ListingReadyPublisher
    QUEUE_NAME = "listing_ready"

    def self.publish(listing_id:)
      new.publish listing_id:
    end

    def publish(listing_id:)
      with_channel do |channel|
        queue = channel.queue QUEUE_NAME, durable: true
        queue.publish({ listing_id: }.to_json, persistent: true)
      end
    end

    private

    def with_channel
      connection = Bunny.new Rails.application.config.x.rabbitmq.url
      connection.start
      yield connection.create_channel
    ensure
      connection&.close
    end
  end
end
