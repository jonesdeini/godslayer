# frozen_string_literal: true

class Listing < ApplicationRecord
  has_many :listing_search_keywords, dependent: :destroy
  has_many :search_keywords, through: :listing_search_keywords

  def primary_image_url
    raw.dig "image", "imageUrl"
  end

  def additional_image_urls
    Array(raw["additionalImages"]).filter_map { |image| image["imageUrl"] }
  end
end
