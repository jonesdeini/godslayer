# frozen_string_literal: true

class ListingSearchKeyword < ApplicationRecord
  belongs_to :listing
  belongs_to :search_keyword

  validates :search_keyword_id, uniqueness: { scope: :listing_id }
end
