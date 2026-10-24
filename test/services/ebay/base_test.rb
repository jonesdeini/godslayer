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
end
