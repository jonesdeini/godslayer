# frozen_string_literal: true

class AddReviewStatusToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :review_status, :string
  end
end
