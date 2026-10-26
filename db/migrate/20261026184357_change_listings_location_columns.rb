# frozen_string_literal: true

class ChangeListingsLocationColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :listings, :item_location, :string
    add_column :listings, :postal_code, :string
    add_column :listings, :country, :string
  end
end
