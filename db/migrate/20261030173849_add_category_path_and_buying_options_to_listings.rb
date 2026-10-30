# frozen_string_literal: true

class AddCategoryPathAndBuyingOptionsToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :category_path, :string
    add_column :listings, :fixed_price, :boolean, default: false, null: false
    add_column :listings, :auction, :boolean, default: false, null: false
    add_column :listings, :best_offer, :boolean, default: false, null: false
  end
end
