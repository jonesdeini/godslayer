# frozen_string_literal: true

class PromoteCandidateJob < ApplicationJob
  queue_as :candidate_promotion
  limits_concurrency key: ->(candidate) { candidate }, on_conflict: :discard

  def perform(candidate)
    CandidatePromoter.promote candidate
  end
end
