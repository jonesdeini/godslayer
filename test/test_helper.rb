# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect! allow_localhost: true

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

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

    setup { Bunny.test_session = nil }

    def published_listing_ready_messages
      queue = Bunny.test_session&.queues&.[]("listing_ready")
      return [] unless queue

      Array.new queue.message_count do
        _delivery_info, _properties, payload = queue.pop
        ::JSON.parse payload
      end
    end
  end
end
