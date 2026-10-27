# frozen_string_literal: true

class Listing < ApplicationRecord
  has_many :images, dependent: :destroy
  has_many :listing_search_keywords, dependent: :destroy
  has_many :search_keywords, through: :listing_search_keywords
end
