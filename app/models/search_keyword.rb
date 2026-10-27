# frozen_string_literal: true

class SearchKeyword < ApplicationRecord
  has_many :listing_search_keywords, dependent: :destroy
  has_many :listings, through: :listing_search_keywords

  validates :phrase, presence: true, uniqueness: true
end
