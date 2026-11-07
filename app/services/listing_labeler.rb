# frozen_string_literal: true

class ListingLabeler
  def self.label_all(limit:, force: false)
    new.label_all limit:, force:
  end

  def label_all(limit:, force: false)
    scope = force ? Listing.all : Listing.where.missing(:listing_labels)
    scope.order(:id).limit(limit).each { |listing| label listing }
  end

  private

  def label(listing)
    verdict = Llm::Client.classify_title listing.title
    ListingLabelWriter.write listing:, label: verdict, model: Llm::Client.model
  rescue StandardError => e
    Rails.logger.error "ListingLabeler: failed for listing #{listing.id}: #{e.class}: #{e.message}"
  end
end
