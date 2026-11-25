# frozen_string_literal: true

class CandidatePromoter
  def self.promote(candidate)
    new.promote candidate
  end

  def promote(candidate)
    listing_id = ListingImporter.import Ebay::Item.detail(candidate.ebay_item_id)
    carry_forward_keywords candidate, listing_id
    candidate.update! detail_imported_at: Time.current
  end

  private

  def carry_forward_keywords(candidate, listing_id)
    candidate.search_keywords.find_each do |keyword|
      ListingSearchKeyword.find_or_create_by listing_id:, search_keyword_id: keyword.id
    end
  end
end
