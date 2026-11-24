# frozen_string_literal: true

class CandidateSearchKeyword < ApplicationRecord
  belongs_to :listing_candidate
  belongs_to :search_keyword
end
