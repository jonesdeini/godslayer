# frozen_string_literal: true

module Rabbitmq
  class ListingReadyPublisher
    QUEUE_NAME = "listing_ready"

    def publish_batch(listings)
      with_channel do |channel|
        queue = channel.queue QUEUE_NAME, durable: true
        listings.each do |listing|
          queue.publish({ listing_id: listing.id }.to_json, persistent: true)
          yield listing
        end
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
