# frozen_string_literal: true

class Api::ListingsController < Api::BaseController
  def show
    listing = Listing.find params[:id]
    render json: listing,
      only: [
        :id, :ebay_item_id, :title, :price_cents, :currency, :condition, :seller, :postal_code, :country, :url,
        :category_id, :category_path, :seller_item_revision, :fixed_price, :auction, :best_offer
      ],
      methods: [ :primary_image_url, :additional_image_urls, :description, :localized_aspects ]
  end
end
