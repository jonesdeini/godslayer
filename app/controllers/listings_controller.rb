# frozen_string_literal: true

class ListingsController < ApplicationController
  VERDICT_RANK = { "mismatch" => 0, "match" => 1, "no_evidence" => 2 }.freeze

  def index
    listings = Listing.includes(:determinations).order(created_at: :desc).to_a
    listings.sort_by! { |listing| VERDICT_RANK.fetch active_determination(listing)&.verdict, 3 }
    render locals: { listings: }
  end

  def show
    listing = Listing.includes(:listing_images, :determinations).find params[:id]
    render locals: { listing:, determination: active_determination(listing) }
  end

  private

  def active_determination(listing)
    listing.determinations.find(&:active?)
  end
end
