# frozen_string_literal: true

class ListingLabelWriter
  def self.write(listing:, **attributes)
    new.write listing:, **attributes
  end

  def write(listing:, **attributes)
    ListingLabel.transaction do
      listing.listing_labels.where(active: true).update_all active: false
      listing.listing_labels.create! attributes.merge(active: true)
    end
  end
end
