# frozen_string_literal: true

class ListingImage < ApplicationRecord
  belongs_to :listing
  has_one_attached :file
end
