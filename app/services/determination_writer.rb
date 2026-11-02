# frozen_string_literal: true

class DeterminationWriter
  def self.write(listing:, **attributes)
    new.write listing:, **attributes
  end

  def write(listing:, **attributes)
    Determination.transaction do
      listing.determinations.where(field: attributes[:field], active: true).update_all active: false
      listing.determinations.create! attributes.merge(active: true)
    end
  end
end
