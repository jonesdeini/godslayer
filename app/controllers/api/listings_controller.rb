# frozen_string_literal: true

class Api::ListingsController < Api::BaseController
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not found" }, status: :not_found
  end

  def show
    listing = Listing.find params[:id]
    render json: listing_json(listing)
  end

  private

  def listing_json(listing)
    {
      id: listing.id,
      ebay_item_id: listing.ebay_item_id,
      title: listing.title,
      price_cents: listing.price_cents,
      currency: listing.currency,
      condition: listing.condition,
      seller: listing.seller,
      postal_code: listing.postal_code,
      country: listing.country,
      url: listing.url,
      primary_image_url: listing.primary_image_url,
      additional_image_urls: listing.additional_image_urls
    }
  end
end
