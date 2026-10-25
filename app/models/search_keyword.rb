# frozen_string_literal: true

class SearchKeyword < ApplicationRecord
  validates :phrase, presence: true, uniqueness: true
end
