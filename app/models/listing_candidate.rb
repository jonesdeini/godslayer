# frozen_string_literal: true

class ListingCandidate < ApplicationRecord
  belongs_to :listing, optional: true
  has_many :candidate_classifications, dependent: :destroy
  has_many :candidate_search_keywords, dependent: :destroy
  has_many :search_keywords, through: :candidate_search_keywords
  has_one :active_classification, -> { where(active: true) }, class_name: "CandidateClassification"

  def self.from_ebay_summary(summary)
    ebay_item_id = summary.fetch "itemId"
    candidate = find_or_initialize_by(ebay_item_id:)
    candidate.assign_attributes(
      title: summary["title"],
      price: summary.dig("price", "value"),
      condition: summary["condition"],
      raw_summary: summary,
      last_seen_at: Time.current
    )
    candidate.first_seen_at ||= candidate.last_seen_at
    candidate
  end

  def changed_since_summary?(summary)
    price != BigDecimal(summary.dig("price", "value")) || condition != summary["condition"]
  end
end
