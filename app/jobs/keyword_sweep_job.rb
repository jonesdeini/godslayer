# frozen_string_literal: true

class KeywordSweepJob < ApplicationJob
  queue_as :default

  def perform(phrase)
    Ebay::Search.keyword phrase
  end
end
