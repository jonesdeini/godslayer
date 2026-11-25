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
    needs_classification = existing.nil? || existing.changed_since_summary?(summary) || existing.detail_imported_at.nil?

    candidate = ListingCandidate.from_ebay_summary summary
    candidate.save!
    CandidateSearchKeyword.find_or_create_by(listing_candidate_id: candidate.id, search_keyword_id:)

    classify candidate if needs_classification
  rescue Ebay::Base::QuotaExceededError
    raise
  rescue StandardError => e
    Sentry.capture_exception e
    Rails.logger.error "KeywordSweeper: failed to import #{summary.inspect}: #{e.class}: #{e.message}"
  end

  # A "part" verdict needs no detail call, so it's finished the instant
  # classification runs. A "computer" verdict isn't finished until
  # PromoteCandidateJob actually completes the detail call - stamping
  # detail_imported_at here, before that job even runs, would make this
  # candidate look done and stop it from ever being retried if promotion
  # fails.
  def classify(candidate)
    verdict, confidence = TitleClassifier.classify candidate.title
    CandidateClassificationWriter.write candidate:, verdict:, confidence:, model_version: TitleClassifier.version

    if verdict == "computer"
      PromoteCandidateJob.perform_later candidate
    else
      candidate.update! detail_imported_at: Time.current
    end
  end
end
