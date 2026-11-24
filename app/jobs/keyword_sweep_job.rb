# frozen_string_literal: true

class KeywordSweepJob < ApplicationJob
  queue_as :sweep

  def perform(keyword)
    Ebay::Search.keyword(keyword.phrase, exclude_phrase: keyword.exclude_phrase).each do |summary|
      import_item summary, keyword.id
    end
  end

  private

  # One bad item (a missing itemId, a failed fetch, an unparseable
  # response) shouldn't sink the rest of the sweep - the whole thing
  # happens inside this one rescue-protected method, not just the parts
  # after we already know the item id.
  def import_item(summary, search_keyword_id)
    item_id = summary.fetch "itemId"
    existing = ListingCandidate.find_by ebay_item_id: item_id
    needs_classification = existing.nil? || existing.changed_since_summary?(summary) || existing.detail_imported_at.nil?

    candidate = ListingCandidate.from_ebay_summary summary
    candidate.save!
    CandidateSearchKeyword.find_or_create_by(listing_candidate_id: candidate.id, search_keyword_id:)

    classify_and_promote candidate if needs_classification
  rescue StandardError => e
    Rails.logger.error "KeywordSweepJob: failed to import #{summary.inspect}: #{e.class}: #{e.message}"
  end

  def classify_and_promote(candidate)
    verdict, confidence = TitleClassifier.classify candidate.title
    CandidateClassificationWriter.write candidate:, verdict:, confidence:, model_version: TitleClassifier.version

    if verdict == "computer"
      listing_id = ListingImporter.import Ebay::Item.detail(candidate.ebay_item_id)
      carry_forward_keywords candidate, listing_id
    end
    candidate.update! detail_imported_at: Time.current
  end

  def carry_forward_keywords(candidate, listing_id)
    candidate.search_keywords.find_each do |keyword|
      ListingSearchKeyword.find_or_create_by listing_id:, search_keyword_id: keyword.id
    end
  end
end
