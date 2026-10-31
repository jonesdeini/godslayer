# frozen_string_literal: true

class PublishReadyListingsJob < ApplicationJob
  queue_as :publishing

  def perform
    Rabbitmq::ListingReadyPublisher.new.publish_batch ready_listings do |listing|
      listing.update! published_at: Time.current
    end
  end

  private

  def ready_listings
    Listing.where.not(images_downloaded_at: nil).where published_at: nil
  end
end
