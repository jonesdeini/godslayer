# frozen_string_literal: true

require "test_helper"

class KeywordSweepJobTest < ActiveJob::TestCase
  # Hand-built, not sklearn-trained - "server" always predicts computer, "fan" always part.
  def title_classifier_model
    TitleClassifierModel.create!(
      vocabulary: { "server" => 0, "fan" => 1 }, idf: [ 1.0, 1.0 ], coef: [ -10.0, 10.0 ],
      intercept: 0.0, classes: [ "computer", "part" ], version: "test"
    )
  end

  setup do
    title_classifier_model
    stub_request(:post, "https://api.ebay.com/identity/v1/oauth2/token")
      .to_return(status: 200, body: { access_token: "fake-token", expires_in: 7200 }.to_json)
  end

  test "imports and promotes items the classifier calls computer" do
    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server" }, { itemId: "v1|222|0", title: "HP Server" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    detail_111 = { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
                   itemWebUrl: "https://ebay.com/itm/111" }.to_json
    detail_222 = { itemId: "v1|222|0", title: "HP Server", price: { value: "200.00", currency: "USD" },
                   itemWebUrl: "https://ebay.com/itm/222" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 200, body: detail_111
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C222%7C0").to_return status: 200, body: detail_222

    KeywordSweepJob.perform_now search_keywords(:one)

    assert_equal 2, ListingCandidate.count
    assert_equal 2, Listing.count
    assert Listing.exists?(ebay_item_id: "v1|111|0")
    assert Listing.exists?(ebay_item_id: "v1|222|0")
    assert_equal "computer", ListingCandidate.find_by(ebay_item_id: "v1|111|0").active_classification.verdict
    assert ListingCandidate.find_by(ebay_item_id: "v1|111|0").detail_imported_at.present?
    assert_equal [ search_keywords(:one) ], Listing.find_by(ebay_item_id: "v1|111|0").search_keywords
  end

  test "creates a candidate but never fetches detail for an item the classifier calls part" do
    search_body = { itemSummaries: [ { itemId: "v1|333|0", title: "Replacement Fan" } ] }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweepJob.perform_now search_keywords(:one)

    assert_equal 1, ListingCandidate.count
    assert_equal 0, Listing.count
    assert_not_requested :get, "https://api.ebay.com/buy/browse/v1/item/v1%7C333%7C0"
    assert_equal "part", ListingCandidate.find_by(ebay_item_id: "v1|333|0").active_classification.verdict
    assert ListingCandidate.find_by(ebay_item_id: "v1|333|0").detail_imported_at.present?
  end

  test "passes the keyword's exclude phrase through to the search" do
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Widget+-%22no+core%22&sort=newlyListed&limit=200")
      .to_return(status: 200, body: { itemSummaries: [] }.to_json)

    KeywordSweepJob.perform_now search_keywords(:with_exclude_phrase)

    assert_equal 0, ListingCandidate.count
    assert_equal 0, Listing.count
  end

  test "skips reclassification entirely for an unchanged, already-finished candidate" do
    ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Test Gadget", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current,
      detail_imported_at: Time.current)

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    KeywordSweepJob.perform_now search_keywords(:generic)

    assert_not_requested :get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0"
    assert_equal 0, CandidateClassification.count
    assert_equal 1, ListingCandidate.count
  end

  test "reclassifies a candidate that was never finished, even if unchanged" do
    ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current,
      detail_imported_at: nil)

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)
    detail = { itemId: "v1|111|0", title: "Dell Server", price: { value: "100.00", currency: "USD" },
               itemWebUrl: "https://ebay.com/itm/111" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 200, body: detail

    KeywordSweepJob.perform_now search_keywords(:generic)

    assert_requested :get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0"
    assert_equal 1, Listing.count
    assert ListingCandidate.find_by(ebay_item_id: "v1|111|0").detail_imported_at.present?
  end

  test "still fetches detail for a known candidate whose price has changed" do
    ListingCandidate.create!(ebay_item_id: "v1|111|0", title: "Dell Server", price: BigDecimal("100.00"),
      condition: "Used", raw_summary: {}, first_seen_at: Time.current, last_seen_at: Time.current,
      detail_imported_at: Time.current)

    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server", price: { value: "80.00", currency: "USD" },
                         condition: "Used" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=Gadget&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)
    detail = { itemId: "v1|111|0", title: "Dell Server", price: { value: "80.00", currency: "USD" },
               itemWebUrl: "https://ebay.com/itm/111" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 200, body: detail

    KeywordSweepJob.perform_now search_keywords(:generic)

    assert_requested :get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0"
    assert_equal BigDecimal("80.00"), Listing.find_by(ebay_item_id: "v1|111|0").price
  end

  test "skips an item whose detail fetch fails, without losing the others or the candidate" do
    search_body = {
      itemSummaries: [ { itemId: "v1|111|0", title: "Dell Server" }, { itemId: "v1|222|0", title: "HP Server" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C111%7C0").to_return status: 500, body: "boom"
    detail_222 = { itemId: "v1|222|0", title: "HP Server", price: { value: "200.00", currency: "USD" },
                   itemWebUrl: "https://ebay.com/itm/222" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C222%7C0").to_return status: 200, body: detail_222

    KeywordSweepJob.perform_now search_keywords(:one)

    assert_equal 1, Listing.count
    assert Listing.exists?(ebay_item_id: "v1|222|0")
    assert_equal 2, ListingCandidate.count
    failed_candidate = ListingCandidate.find_by ebay_item_id: "v1|111|0"
    assert_equal "computer", failed_candidate.active_classification.verdict
    assert_nil failed_candidate.detail_imported_at
  end

  test "skips a summary that's missing itemId entirely, without losing the others" do
    search_body = {
      itemSummaries: [ { title: "malformed, no itemId" }, { itemId: "v1|222|0", title: "HP Server" } ]
    }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item_summary/search?q=R730xd&sort=newlyListed&limit=200")
      .to_return(status: 200, body: search_body)

    detail_222 = { itemId: "v1|222|0", title: "HP Server", price: { value: "200.00", currency: "USD" },
                   itemWebUrl: "https://ebay.com/itm/222" }.to_json
    stub_request(:get, "https://api.ebay.com/buy/browse/v1/item/v1%7C222%7C0").to_return status: 200, body: detail_222

    KeywordSweepJob.perform_now search_keywords(:one)

    assert_equal 1, Listing.count
    assert Listing.exists?(ebay_item_id: "v1|222|0")
  end
end
