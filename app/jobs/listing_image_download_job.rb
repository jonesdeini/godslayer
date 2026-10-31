# frozen_string_literal: true

class ListingImageDownloadJob < ApplicationJob
  queue_as :image_downloads

  def perform(listing_id)
    listing = Listing.find listing_id
    image_urls = [ listing.primary_image_url, *listing.additional_image_urls ].compact

    image_urls.each { |url| attach_image listing, url }
    listing.update! images_downloaded_at: Time.current
  end

  private

  def attach_image(listing, url)
    return if listing.listing_images.exists? source_url: url

    response = HTTP.timeout(30).get url
    raise "failed to download #{url}: #{response.status}" unless response.status.success?

    listing_image = listing.listing_images.create! source_url: url
    listing_image.file.attach(
      io: StringIO.new(response.body.to_s),
      filename: File.basename(URI.parse(url).path),
      content_type: response.content_type.mime_type
    )
  end
end
