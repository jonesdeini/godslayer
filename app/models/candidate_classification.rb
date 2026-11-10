# frozen_string_literal: true

class CandidateClassification < ApplicationRecord
  VERDICTS = %w[computer part].freeze

  belongs_to :listing_candidate

  validates :verdict, inclusion: { in: VERDICTS }
end
