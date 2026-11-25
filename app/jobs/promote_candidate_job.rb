# frozen_string_literal: true

class PromoteCandidateJob < ApplicationJob
  queue_as :candidate_promotion

  def perform(candidate)
    CandidatePromoter.promote candidate
  end
end
