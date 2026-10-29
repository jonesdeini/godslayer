# frozen_string_literal: true

class AddSellerItemRevisionToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :seller_item_revision, :string
  end
end
