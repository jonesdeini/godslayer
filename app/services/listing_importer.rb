# frozen_string_literal: true

class ListingImporter
  def self.import(raw_json)
    new.import raw_json
  end

  def import(raw_json)
    raw = JSON.parse raw_json
    listing = Listing.from_ebay_json raw
    return listing.id unless listing.new_record? || listing.seller_item_revision_changed?

    listing.published_at = nil
    listing.save!
    ListingImageDownloadJob.perform_later listing.id
    listing.id
  end
end
