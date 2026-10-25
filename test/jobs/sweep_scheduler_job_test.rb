# frozen_string_literal: true

require "test_helper"

class SweepSchedulerJobTest < ActiveJob::TestCase
  test "enqueues a KeywordSweepJob for each active keyword" do
    SweepSchedulerJob.perform_now

    assert_enqueued_with job: KeywordSweepJob, args: [ search_keywords(:one).phrase ]
    assert_enqueued_with job: KeywordSweepJob, args: [ search_keywords(:two).phrase ]
  end

  test "does not enqueue a job for a retired keyword" do
    SweepSchedulerJob.perform_now

    assert_enqueued_jobs 2, only: KeywordSweepJob
  end
end
