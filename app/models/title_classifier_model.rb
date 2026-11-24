# frozen_string_literal: true

class TitleClassifierModel < ApplicationRecord
  validates :vocabulary, :idf, :coef, :classes, :intercept, :version, presence: true

  def self.active
    find_by active: true
  end
end
