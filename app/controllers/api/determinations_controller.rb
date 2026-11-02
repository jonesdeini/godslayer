# frozen_string_literal: true

class Api::DeterminationsController < Api::BaseController
  def create
    determination = DeterminationWriter.write listing: Listing.find(params[:listing_id]), **determination_params

    render json: determination, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def determination_params
    params.expect(
      determination: [ :field, :verdict, :claimed_value, :claimed_unit, :photo_value, :photo_unit, :listing_image_id ]
    ).to_h.symbolize_keys
  end
end
