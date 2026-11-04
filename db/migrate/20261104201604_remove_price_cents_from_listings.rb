# frozen_string_literal: true

class RemovePriceCentsFromListings < ActiveRecord::Migration[8.1]
  def change
    remove_column :listings, :price_cents, :integer, null: false
  end
end
