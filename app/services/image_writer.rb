# frozen_string_literal: true

class ImageWriter
  def self.write(listing_id:, position:, source_url:)
    result = Image.upsert(
      { listing_id:, position:, source_url: },
      unique_by: [ :listing_id, :position ],
      update_only: [ :source_url ]
    )
    result.first["id"]
  end
end
