# frozen_string_literal: true

require "test_helper"

class KeywordSweeperTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Sentry::TestHelper

  def title_classifier_model
    TitleClassifierModel.create!(
      vocabulary: { "server" => 0, "fan" => 1 }, idf: [ 1.0, 1.0 ], coef: [ -10.0, 10.0 ],
      intercept: 0.0, classes: [ "computer", "part" ], version: "test"
    )
  end

  setup do
    setup_sentry_test
    title_classifier_model
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  teardown { teardown_sentry_test }

  test "enqueues promotion for items the classifier calls computer" do
    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server" }, { itemId: "v1|222|0", title: "HP Server" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:one)

    assert_equal 2, ListingCandidate.count
    candidate_111 = ListingCandidate.find_by ebay_item_id: "v1|111|0"
    assert_equal "computer", candidate_111.active_classification.verdict
    assert_nil candidate_111.listing_id
    assert_equal [ search_keywords(:one) ], candidate_111.search_keywords
    assert_enqueued_with job: PromoteCandidateJob, args: [ candidate_111 ]
    assert_enqueued_with job: PromoteCandidateJob, args: [ ListingCandidate.find_by(ebay_item_id: "v1|222|0") ]
  end

  test "creates a candidate but never enqueues promotion for an item the classifier calls part" do
    search_body = { itemSummaries: [ { itemId: "v1|333|0", title: "Replacement Fan" } ] }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:one)

    assert_equal 1, ListingCandidate.count
    assert_no_enqueued_jobs only: PromoteCandidateJob
    candidate = ListingCandidate.find_by ebay_item_id: "v1|333|0"
    assert_equal "part", candidate.active_classification.verdict
    assert_nil candidate.listing_id
  end

  test "passes the keyword's exclude phrase through to the search" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Widget+-%22no+core%22&sort=newlyListed&limit=200")
      .to_return(status: 200, body: { itemSummaries: [] }.to_json)

    KeywordSweeper.sweep search_keywords(:with_exclude_phrase)

    assert_equal 0, ListingCandidate.count
  end

  test "skips reclassification and promotion for an unchanged, already-classified, already-promoted candidate" do
    listing = Listing.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      url: "https://ebay.com/itm/111", first_seen_at: Time.current, last_seen_at: Time.current, raw: {})
    candidate = ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Test Gadget", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current,
      listing_id: listing.id)
    CandidateClassification.create! listing_candidate_id: candidate.id, verdict: "computer", model_version: "test"

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:generic)

    assert_no_enqueued_jobs only: PromoteCandidateJob
    assert_equal 1, CandidateClassification.count
    assert_equal 1, ListingCandidate.count
    assert_equal [ search_keywords(:generic) ], listing.reload.search_keywords
  end

  test "retries classification for a candidate that exists but was never successfully classified" do
    ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current)

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:generic)

    candidate = ListingCandidate.find_by ebay_item_id: "v1|111|0"
    assert_equal "computer", candidate.active_classification.verdict
    assert_enqueued_with job: PromoteCandidateJob, args: [ candidate ]
  end

  test "enqueues promotion again for a computer-verdict candidate that was never promoted, even if unchanged" do
    candidate = ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current)
    CandidateClassification.create! listing_candidate_id: candidate.id, verdict: "computer", model_version: "test"

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:generic)

    assert_enqueued_with job: PromoteCandidateJob, args: [ candidate ]
    assert_equal 1, CandidateClassification.count
  end

  test "enqueues promotion again for a known candidate whose price has changed" do
    candidate = ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current)
    CandidateClassification.create! listing_candidate_id: candidate.id, verdict: "computer", model_version: "test"

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server", price: { value: "80.00", currency: "USD" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:generic)

    assert_enqueued_with job: PromoteCandidateJob, args: [ ListingCandidate.find_by(ebay_item_id: "v1|111|0") ]
    assert_equal 1, CandidateClassification.count
  end

  test "a part verdict never gets promoted, even if its price changes" do
    candidate = ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Replacement Fan", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current)
    CandidateClassification.create! listing_candidate_id: candidate.id, verdict: "part", model_version: "test"

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Replacement Fan", price: { value: "80.00", currency: "USD" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:generic)

    assert_no_enqueued_jobs only: PromoteCandidateJob
    assert_equal 1, CandidateClassification.count
  end

  test "reports a swallowed non-quota failure to Sentry" do
    listing = Listing.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      url: "https://ebay.com/itm/111", first_seen_at: Time.current, last_seen_at: Time.current, raw: {})
    candidate = ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current,
      listing_id: listing.id)
    CandidateClassification.create! listing_candidate_id: candidate.id, verdict: "computer", model_version: "test"

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server", price: { value: "not-a-number" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:generic)

    assert_equal 1, sentry_events.size
    assert_equal [ "ArgumentError" ], extract_sentry_exceptions(last_sentry_event).map(&:type)
  end

  test "a quota-exceeded failure propagates instead of being swallowed" do
    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server" }, { itemId: "v1|222|0", title: "HP Server" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 429, body: '{"errors":[{"errorId":2001,"message":"Too many requests."}]}')

    assert_raises(Ebay::Base::QuotaExceededError) { KeywordSweeper.sweep search_keywords(:one) }

    assert_equal 0, ListingCandidate.count
  end

  test "skips a summary that's missing itemId entirely, without losing the others" do
    search_body = {
      itemSummaries: [ { title: "malformed, no itemId" }, { itemId: "v1|222|0", title: "HP Server" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweeper.sweep search_keywords(:one)

    assert_equal 1, ListingCandidate.count
    assert ListingCandidate.exists?(ebay_item_id: "v1|222|0")
  end
end
