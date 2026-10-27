# frozen_string_literal: true

class SweepSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    SearchKeyword.where(active: true).find_each do |keyword|
      KeywordSweepJob.perform_later keyword
    end
  end
end
