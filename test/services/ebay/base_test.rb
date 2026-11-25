# frozen_string_literal: true

require "test_helper"

class Ebay::BaseTest < ActiveSupport::TestCase
  class FakeEndpoint < Ebay::Base
    def ping
      get "#{base_url}/ping"
    end
  end

  setup do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(
        status: 200,
        body: { access_token: "fake-token", expires_in: 7200 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  test "sends the fetched token as a bearer Authorization header" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/ping")
      .with(headers: { "Authorization" => "Bearer fake-token" })
      .to_return(status: 200, body: "pong")

    assert_equal "pong", FakeEndpoint.new.ping
  end

  test "hits the sandbox host when EBAY_ENVIRONMENT is sandbox" do
    Rails.application.config.x.ebay.environment = "sandbox"
    stub_request(:post, "https://api.sandbox.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
    stub_request(:get, "https://api.sandbox.ebay.com/buy/browse/v1/ping")
      .to_return(status: 200, body: "pong")

    assert_equal "pong", FakeEndpoint.new.ping
  ensure
    Rails.application.config.x.ebay.environment = "production"
  end

  test "raises on an unrecognized EBAY_ENVIRONMENT value" do
    Rails.application.config.x.ebay.environment = "staging"

    assert_raises(KeyError) { FakeEndpoint.new.ping }
  ensure
    Rails.application.config.x.ebay.environment = "production"
  end

  test "raises QuotaExceededError on a 429" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/ping")
      .to_return(status: 429, body: '{"errors":[{"errorId":2001,"message":"Too many requests."}]}')

    assert_raises(Ebay::Base::QuotaExceededError) { FakeEndpoint.new.ping }
  end

  test "raises RequestError, not QuotaExceededError, on a non-429 failure" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/ping")
      .to_return(status: 500, body: "boom")

    error = assert_raises(Ebay::Base::RequestError) { FakeEndpoint.new.ping }
    assert_not_instance_of Ebay::Base::QuotaExceededError, error
  end
end
