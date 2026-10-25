# frozen_string_literal: true

require "test_helper"

class Ebay::SearchTest < ActiveSupport::TestCase
  setup do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  test "searches by keyword, newest first, with no price filter by default" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=100")
      .to_return(status: 200, body: "search results")

    assert_equal "search results", Ebay::Search.keyword("R730xd")
  end

  test "adds a price filter when a price cap is configured" do
    Rails.application.config.x.ebay.price_cap_cents = 25_000

    stub_request(
      :get,
      "https://api.ebay.com/buy/browse/v1/item_summary/search" \
      "?q=R730xd&sort=newlyListed&limit=100&filter=price%3A%5B..250.0%5D%2CpriceCurrency%3AUSD"
    ).to_return(status: 200, body: "search results")

    assert_equal "search results", Ebay::Search.keyword("R730xd")
  ensure
    Rails.application.config.x.ebay.price_cap_cents = 0
  end
end
