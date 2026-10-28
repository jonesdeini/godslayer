# frozen_string_literal: true

class ListingImporter
  def self.import(raw_json, search_keyword_id:)
    new.import raw_json, search_keyword_id:
  end

  def import(raw_json, search_keyword_id:)
    raw = JSON.parse raw_json
    ListingSearchKeywordLinkJob.set(wait: 1.minute).perform_later(ebay_item_id: raw.fetch("itemId"), search_keyword_id:)

    listing = Listing.from_ebay_json raw
    new_listing = listing.new_record?
    return listing.id unless new_listing || listing.seller_item_revision_changed?

    listing.save!
    Rabbitmq::ListingReadyPublisher.publish(listing_id: listing.id) if new_listing
    listing.id
  end
end
