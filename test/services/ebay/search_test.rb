# frozen_string_literal: true

require "test_helper"

class Ebay::SearchTest < ActiveSupport::TestCase
  setup do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  test "searches by keyword, newest first, with no price filter by default" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: { itemSummaries: [ { itemId: "v1|111|0" } ] }.to_json)

    assert_equal [ { "itemId" => "v1|111|0" } ], Ebay::Search.keyword("R730xd")
  end

  test "adds a quoted -term exclusion when an exclude phrase is given" do
    stub_request(
      :get,
      "https://api.ebay.com/buy/browse/v1/item_summary/search" \
      "?q=Widget+-%22no+core%22&sort=newlyListed&limit=200"
    ).to_return(status: 200, body: { itemSummaries: [ { itemId: "v1|111|0" } ] }.to_json)

    assert_equal [ { "itemId" => "v1|111|0" } ], Ebay::Search.keyword("Widget", exclude_phrase: "no core")
  end

  test "adds a price filter when a price cap is configured" do
    Rails.application.config.x.ebay.price_cap_cents = 25_000

    stub_request(
      :get,
      "https://api.ebay.com/buy/browse/v1/item_summary/search" \
      "?q=R730xd&sort=newlyListed&limit=200&filter=price%3A%5B..250.0%5D%2CpriceCurrency%3AUSD"
    ).to_return(status: 200, body: { itemSummaries: [ { itemId: "v1|111|0" } ] }.to_json)

    assert_equal [ { "itemId" => "v1|111|0" } ], Ebay::Search.keyword("R730xd")
  ensure
    Rails.application.config.x.ebay.price_cap_cents = 0
  end

  test "follows next across multiple pages and merges every itemSummaries array" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Widget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: {
        itemSummaries: [ { itemId: "v1|111|0" } ],
        next: "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Widget&limit=200&offset=200"
      }.to_json)
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Widget&limit=200&offset=200")
      .to_return(status: 200, body: { itemSummaries: [ { itemId: "v1|222|0" } ] }.to_json)

    assert_equal [ { "itemId" => "v1|111|0" }, { "itemId" => "v1|222|0" } ], Ebay::Search.keyword("Widget")
  end

  test "stops as soon as a page has no next" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Widget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: { itemSummaries: [ { itemId: "v1|111|0" } ] }.to_json)

    Ebay::Search.keyword "Widget"

    assert_requested :get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Widget&sort=newlyListed&limit=200", times: 1
  end
end
