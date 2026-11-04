# frozen_string_literal: true

class ListingsController < ApplicationController
  def index
    listings = Listing.includes(:determinations).ordered_for_review.to_a
    render locals: { listings: }
  end

  def show
    listing = Listing.includes(:listing_images, :determinations).find params[:id]
    render locals: { listing:, determination: listing.active_determination }
  end
end
