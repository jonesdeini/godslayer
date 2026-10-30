# frozen_string_literal: true

class Api::ListingsController < Api::BaseController
  def show
    listing = Listing.find params[:id]
    render json: listing,
      only: [ :id, :ebay_item_id, :title, :price_cents, :currency, :condition, :seller, :postal_code, :country, :url ],
      methods: [ :primary_image_url, :additional_image_urls ]
  end
end
