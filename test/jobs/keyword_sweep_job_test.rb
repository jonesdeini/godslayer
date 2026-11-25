# frozen_string_literal: true

require "test_helper"

class KeywordSweepJobTest < ActiveJob::TestCase
  setup do
    TitleClassifierModel.create!(
      vocabulary: { "server" => 0, "fan" => 1 }, idf: [ 1.0, 1.0 ], coef: [ -10.0, 10.0 ],
      intercept: 0.0, classes: [ "computer", "part" ], version: "test"
    )
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  # Full behavior coverage (classification, dedup, error handling) lives in
  # test/services/keyword_sweeper_test.rb, where it's much easier to test -
  # this just confirms the job actually delegates.
  test "delegates to KeywordSweeper" do
    search_body = { itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server" } ] }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweepJob.perform_now search_keywords(:one)

    assert ListingCandidate.exists?(ebay_item_id: "v1|111|0")
  end
end
