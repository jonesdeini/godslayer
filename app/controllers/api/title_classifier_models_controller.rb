# frozen_string_literal: true

class Api::TitleClassifierModelsController < Api::BaseController
  def create
    model = TitleClassifierModelWriter.write(**title_classifier_model_params)
    render json: model, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def title_classifier_model_params
    params.expect(
      title_classifier_model: [ :intercept, :version, vocabulary: {}, idf: [], coef: [], classes: [] ]
    ).to_h.symbolize_keys
  end
end
