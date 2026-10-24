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
  end
end
