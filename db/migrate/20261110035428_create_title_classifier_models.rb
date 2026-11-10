# frozen_string_literal: true

class CreateTitleClassifierModels < ActiveRecord::Migration[8.1]
  def change
    create_table :title_classifier_models do |t|
      t.jsonb   :vocabulary, null: false
      t.jsonb   :idf, null: false
      t.jsonb   :coef, null: false
      t.decimal :intercept, null: false
      t.jsonb   :classes, null: false
      t.string  :version, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :title_classifier_models, :version, unique: true
  end
end
