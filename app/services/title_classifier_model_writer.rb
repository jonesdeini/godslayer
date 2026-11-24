# frozen_string_literal: true

class TitleClassifierModelWriter
  def self.write(**attributes)
    new.write(**attributes)
  end

  def write(**attributes)
    TitleClassifierModel.transaction do
      TitleClassifierModel.where(active: true).update_all active: false
      TitleClassifierModel.create! attributes.merge(active: true)
    end
  end
end
