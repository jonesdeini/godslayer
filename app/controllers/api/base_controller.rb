# frozen_string_literal: true

class Api::BaseController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid do
    render json: { error: "not found" }, status: :not_found
  end
end
