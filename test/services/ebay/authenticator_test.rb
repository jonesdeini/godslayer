# frozen_string_literal: true

require "test_helper"

class Ebay::AuthenticatorTest < ActiveSupport::TestCase
  test "reuses a cached token instead of fetching a new one every call" do
    stub = stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)

    Ebay::Authenticator.token
    Ebay::Authenticator.token

    assert_requested stub, times: 1
  end

  test "fetches a new token once the cached one has expired" do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(
        { status: 200, body: { access_token: "first-token", expires_in: 3600 }.to_json },
        { status: 200, body: { access_token: "second-token", expires_in: 3600 }.to_json }
      )

    first = Ebay::Authenticator.token
    travel 61.minutes
    second = Ebay::Authenticator.token

    assert_equal "first-token", first
    assert_equal "second-token", second
  end
end
