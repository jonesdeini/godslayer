# frozen_string_literal: true

class AddImagesDownloadedAtAndPublishedAtToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :images_downloaded_at, :datetime
    add_column :listings, :published_at, :datetime
  end
end
