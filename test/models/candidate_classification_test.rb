# frozen_string_literal: true

require "test_helper"

class CandidateClassificationTest < ActiveSupport::TestCase
  def candidate
    @candidate ||= ListingCandidate.create!(ebay_item_id: "v1|classification-test|0", title: "Test", raw_summary: {},
      first_seen_at: Time.current, last_seen_at: Time.current)
  end

  test "requires a verdict in the known set" do
    classification = candidate.candidate_classifications.build verdict: "surely_not"

    assert_not classification.valid?
    assert_includes classification.errors[:verdict], "is not included in the list"
  end

  test "is valid with a known verdict" do
    classification = candidate.candidate_classifications.build verdict: "computer"

    assert classification.valid?
  end
end
