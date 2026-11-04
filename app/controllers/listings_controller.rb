# frozen_string_literal: true

class ListingsController < ApplicationController
  def index
    show_reviewed = params[:show_reviewed].present?
    listings = Listing.includes(:determinations).ordered_for_review
    listings = listings.unreviewed unless show_reviewed
    render locals: { listings: listings.to_a, show_reviewed: }
  end

  def show
    listing = Listing.includes(:listing_images, :determinations).find params[:id]
    render locals: { listing:, determination: listing.active_determination }
  end

  def update
    listing.update! review_status_params
    redirect_to listings_path(show_reviewed: params[:show_reviewed].presence)
  end

  private

  def listing
    @listing ||= Listing.find params[:id]
  end

  def review_status_params
    params.expect listing: [ :review_status ]
  end
end
