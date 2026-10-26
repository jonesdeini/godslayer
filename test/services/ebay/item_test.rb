# frozen_string_literal: true

require "test_helper"

class Ebay::ItemTest < ActiveSupport::TestCase
  setup do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  test "fetches item detail by item id, url-encoding the pipe-delimited id" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C110591042924%7C0")
      .to_return(status: 200, body: '{"itemId":"v1|110591042924|0"}')

    assert_equal '{"itemId":"v1|110591042924|0"}', Ebay::Item.detail("v1|110591042924|0")
  end
end
