# frozen_string_literal: true

class ListingImporter
  def self.import(raw_json, search_keyword_id:)
    new.import raw_json, search_keyword_id:
  end

  def import(raw_json, search_keyword_id:)
    raw = JSON.parse raw_json
    ListingSearchKeywordLinkJob.set(wait: 1.minute).perform_later(ebay_item_id: raw.fetch("itemId"), search_keyword_id:)

    listing = Listing.from_ebay_json raw
    return listing.id unless listing.new_record? || listing.seller_item_revision_changed?

    listing.published_at = nil
    listing.save!
    ListingImageDownloadJob.perform_later listing.id
    listing.id
  end
end
