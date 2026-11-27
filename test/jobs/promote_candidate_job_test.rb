# frozen_string_literal: true

require "test_helper"

class PromoteCandidateJobTest < ActiveJob::TestCase
  setup do
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  test "delegates to CandidatePromoter" do
    candidate = ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current)
    detail = { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
               itemWebUrl: "https://ebay.com/itm/111" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 200, body: detail

    PromoteCandidateJob.perform_now candidate

    assert candidate.reload.listing_id.present?
    assert Listing.exists?(ebay_item_id: "v1|111|0")
  end

  test "limits concurrency per candidate, discarding a conflicting promotion" do
    candidate = ListingCandidate.create!(ebay_item_id: "v1|222|0", title: "Dell Server", price: BigDecimal("50.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current)

    job = PromoteCandidateJob.new candidate

    assert_equal "PromoteCandidateJob/ListingCandidate/#{candidate.id}", job.concurrency_key
    assert_equal :discard, PromoteCandidateJob.concurrency_on_conflict
  end
end
