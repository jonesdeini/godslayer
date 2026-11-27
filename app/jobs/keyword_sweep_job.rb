# frozen_string_literal: true

class KeywordSweepJob < ApplicationJob
  queue_as :sweep

  def perform(keyword)
    KeywordSweeper.sweep keyword
  end
end
