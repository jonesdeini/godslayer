# frozen_string_literal: true

require "test_helper"

class KeywordSweepJobTest < ActiveJob::TestCase
  test "searches eBay for the given keyword" do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
    search = stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=100")
      .to_return(status: 200, body: "search results")

    KeywordSweepJob.perform_now "R730xd"

    assert_requested search
  end
end
