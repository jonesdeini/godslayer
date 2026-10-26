# frozen_string_literal: true

require "test_helper"

class KeywordSweepJobTest < ActiveJob::TestCase
  setup do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  test "imports every item found by the search" do
    search_body = {
      itemSummaries: [ { itemId: "v1|111|0" }, { itemId: "v1|222|0" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=100")
      .to_return(status: 200, body: search_body)

    detail_111 = { itemId: "v1|111|0", title: "Dell R730xd", price: { value: "100.00", currency: "USD" },
                   itemWebUrl: "https://ebay.com/itm/111" }.to_json
    detail_222 = { itemId: "v1|222|0", title: "Dell R730xd #2", price: { value: "200.00", currency: "USD" },
                   itemWebUrl: "https://ebay.com/itm/222" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 200, body: detail_111
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C222%7C0").to_return status: 200, body: detail_222

    KeywordSweepJob.perform_now "R730xd"

    assert_equal 2, Listing.count
    assert Listing.exists?(ebay_item_id: "v1|111|0")
    assert Listing.exists?(ebay_item_id: "v1|222|0")
  end

  test "skips an item whose detail fetch fails, without losing the others" do
    search_body = { itemSummaries: [ { itemId: "v1|111|0" }, { itemId: "v1|222|0" } ] }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=100")
      .to_return(status: 200, body: search_body)

    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 500, body: "boom"
    detail_222 = { itemId: "v1|222|0", title: "Dell R730xd #2", price: { value: "200.00", currency: "USD" },
                   itemWebUrl: "https://ebay.com/itm/222" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C222%7C0").to_return status: 200, body: detail_222

    KeywordSweepJob.perform_now "R730xd"

    assert_equal 1, Listing.count
    assert Listing.exists?(ebay_item_id: "v1|222|0")
  end

  test "skips a summary that's missing itemId entirely, without losing the others" do
    search_body = {
      itemSummaries: [ { title: "malformed, no itemId" }, { itemId: "v1|222|0" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=100")
      .to_return(status: 200, body: search_body)

    detail_222 = { itemId: "v1|222|0", title: "Dell R730xd #2", price: { value: "200.00", currency: "USD" },
                   itemWebUrl: "https://ebay.com/itm/222" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C222%7C0").to_return status: 200, body: detail_222

    KeywordSweepJob.perform_now "R730xd"

    assert_equal 1, Listing.count
    assert Listing.exists?(ebay_item_id: "v1|222|0")
  end
end
