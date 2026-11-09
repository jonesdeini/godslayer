# frozen_string_literal: true

class ListingLabel < ApplicationRecord
  LABELS = %w[computer part].freeze

  belongs_to :listing

  validates :label, inclusion: { in: LABELS }
  validates :model, presence: true
end
