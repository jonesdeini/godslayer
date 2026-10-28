# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect! allow_localhost: true

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize workers: :number_of_processors

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Ebay::Authenticator caches its token at the class level, so it has to
    # be reset before every test regardless of run order - otherwise a
    # token cached by one test leaks into another's assertions.
    setup { Ebay::Authenticator.reset! }

    # Unlike Postgres, RabbitMQ isn't wrapped in a per-test transaction that
    # rolls back automatically - tests that touch it call these explicitly.
    def purge_listing_ready_queue
      with_listing_ready_queue(&:purge)
    end

    def pop_listing_ready_messages(matching:)
      found = []
      with_listing_ready_queue do |queue|
        loop do
          _delivery_info, _properties, payload = queue.pop
          break if payload.nil?
          parsed = ::JSON.parse payload
          found << parsed if parsed["listing_id"] == matching
        end
      end
      found
    end

    def with_listing_ready_queue
      connection = Bunny.new Rails.application.config.x.rabbitmq.url
      connection.start
      channel = connection.create_channel
      yield channel.queue("listing_ready", durable: true)
    ensure
      connection&.close
    end
  end
end
