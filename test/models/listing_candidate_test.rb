# frozen_string_literal: true

require "test_helper"

class ListingCandidateTest < ActiveSupport::TestCase
  test "from_ebay_summary builds a new candidate from a search summary" do
    candidate = ListingCandidate.from_ebay_summary(
      "itemId" => "v1|candidate-1|0", "title" => "Dell R630 Server",
      "price" => { "value" => "100.00", "currency" => "USD" }, "condition" => "Used"
    )

    assert candidate.new_record?
    assert_equal "v1|candidate-1|0", candidate.ebay_item_id
    assert_equal "Dell R630 Server", candidate.title
    assert_equal BigDecimal("100.00"), candidate.price
    assert_equal "Used", candidate.condition
    assert_equal candidate.last_seen_at, candidate.first_seen_at
  end

  test "from_ebay_summary reuses an existing candidate by ebay_item_id and keeps first_seen_at" do
    first_seen = 1.day.ago
    existing = ListingCandidate.create!(
      ebay_item_id: "v1|candidate-2|0", title: "Old Title", raw_summary: {},
      first_seen_at: first_seen, last_seen_at: first_seen
    )

    candidate = ListingCandidate.from_ebay_summary(
      "itemId" => "v1|candidate-2|0", "title" => "New Title",
      "price" => { "value" => "50.00", "currency" => "USD" }, "condition" => "New"
    )

    assert_equal existing.id, candidate.id
    assert_equal "New Title", candidate.title
    assert_in_delta first_seen.to_f, candidate.first_seen_at.to_f, 1.0
  end

  test "changed_since_summary? is true when price or condition differ" do
    candidate = ListingCandidate.new price: BigDecimal("100.00"), condition: "Used"

    assert candidate.changed_since_summary?("price" => { "value" => "80.00" }, "condition" => "Used")
    assert candidate.changed_since_summary?("price" => { "value" => "100.00" }, "condition" => "New")
    assert_not candidate.changed_since_summary?("price" => { "value" => "100.00" }, "condition" => "Used")
  end

  test "active_classification returns the currently active classification" do
    candidate = ListingCandidate.create!(ebay_item_id: "v1|candidate-3|0", title: "Test", raw_summary: {},
      first_seen_at: Time.current, last_seen_at: Time.current)
    CandidateClassificationWriter.write candidate:, verdict: "part", model_version: "v1"
    second = CandidateClassificationWriter.write candidate:, verdict: "computer", model_version: "v2"

    assert_equal second.id, candidate.active_classification.id
  end
end
