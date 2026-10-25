# frozen_string_literal: true

class CreateSearchKeywords < ActiveRecord::Migration[8.1]
  def change
    create_table :search_keywords do |t|
      t.string  :phrase, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :search_keywords, :phrase, unique: true
  end
end
