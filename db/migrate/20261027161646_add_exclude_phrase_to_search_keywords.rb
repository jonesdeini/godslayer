# frozen_string_literal: true

class AddExcludePhraseToSearchKeywords < ActiveRecord::Migration[8.1]
  def change
    add_column :search_keywords, :exclude_phrase, :string
  end
end
