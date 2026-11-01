# frozen_string_literal: true

class Determination < ApplicationRecord
  VERDICTS = %w[match mismatch no_evidence].freeze

  belongs_to :listing
  belongs_to :listing_image, optional: true

  validates :field, presence: true
  validates :verdict, inclusion: { in: VERDICTS }
end
