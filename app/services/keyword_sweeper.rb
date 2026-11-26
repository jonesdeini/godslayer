# frozen_string_literal: true

class KeywordSweeper
  def self.sweep(keyword)
    new.sweep keyword
  end

  def sweep(keyword)
    Ebay::Search.keyword(keyword.phrase, exclude_phrase: keyword.exclude_phrase).each do |summary|
      import_item summary, keyword.id
    end
  end

  private

  def import_item(summary, search_keyword_id)
    item_id = summary.fetch "itemId"
    existing = ListingCandidate.find_by ebay_item_id: item_id
    needs_classification = existing.nil? || existing.changed_since_summary?(summary)

    candidate = ListingCandidate.from_ebay_summary summary
    candidate.save!
    CandidateSearchKeyword.find_or_create_by(listing_candidate_id: candidate.id, search_keyword_id:)

    if needs_classification
      classify candidate
    elsif candidate.active_classification&.verdict == "computer" && candidate.listing_id.nil?
      PromoteCandidateJob.perform_later candidate
    end
  rescue Ebay::Base::QuotaExceededError
    raise
  rescue StandardError => e
    Sentry.capture_exception e
    Rails.logger.error "KeywordSweeper: failed to import #{summary.inspect}: #{e.class}: #{e.message}"
  end

  def classify(candidate)
    verdict, confidence = TitleClassifier.classify candidate.title
    CandidateClassificationWriter.write candidate:, verdict:, confidence:, model_version: TitleClassifier.version

    PromoteCandidateJob.perform_later candidate if verdict == "computer"
  end
end
