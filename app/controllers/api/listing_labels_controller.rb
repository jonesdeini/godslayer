# frozen_string_literal: true

class Api::ListingLabelsController < Api::BaseController
  def index
    render :index, locals: { labels: ListingLabel.where(active: true).includes(listing: :search_keywords) }
  end
end
