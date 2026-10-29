# frozen_string_literal: true

class ListingImporter
  def self.import(raw_json, search_keyword_id:)
    new.import raw_json, search_keyword_id:
  end

  def import(raw_json, search_keyword_id:)
    raw = JSON.parse raw_json
    ListingSearchKeywordLinkJob.set(wait: 1.minute).perform_later(ebay_item_id: raw.fetch("itemId"), search_keyword_id:)

    listing = ListingWriter.write raw
    listing.save!
    listing.id
  end
end
