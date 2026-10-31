# frozen_string_literal: true

class Api::ListingsController < Api::BaseController
  def show
    listing = Listing.find params[:id]
    render :show, locals: { listing: }
  end
end
