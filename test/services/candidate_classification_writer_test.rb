# frozen_string_literal: true

require "test_helper"

class CandidateClassificationWriterTest < ActiveSupport::TestCase
  def candidate
    @candidate ||= ListingCandidate.create!(ebay_item_id: "v1|writer-test|0", title: "Test", raw_summary: {},
      first_seen_at: Time.current, last_seen_at: Time.current)
  end

  test "writes a new active classification" do
    classification = CandidateClassificationWriter.write candidate:, verdict: "computer",
      confidence: 0.9, model_version: "v1"

    assert classification.persisted?
    assert classification.active?
    assert_equal "computer", classification.verdict
  end

  test "deactivates the previous active classification for the candidate" do
    first = CandidateClassificationWriter.write candidate:, verdict: "part", model_version: "v1"

    second = CandidateClassificationWriter.write candidate:, verdict: "computer", model_version: "v2"

    assert_not first.reload.active?
    assert second.active?
  end
end
