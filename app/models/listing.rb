# frozen_string_literal: true

class Listing < ApplicationRecord
  has_many :images, dependent: :destroy
end
