# frozen_string_literal: true

class AddPriceToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :price, :decimal
  end
end
