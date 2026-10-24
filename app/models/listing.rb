class Listing < ApplicationRecord
  has_many :images, dependent: :destroy
end
