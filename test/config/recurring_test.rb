# frozen_string_literal: true

require "test_helper"
require "fugit"

class RecurringConfigTest < ActiveSupport::TestCase
  teardown do
    ENV.delete "SWEEP_INTERVAL_HOURS"
  end

  test "omits sweep_scheduler entirely when SWEEP_INTERVAL_HOURS is unset" do
    ENV.delete "SWEEP_INTERVAL_HOURS"

    assert_not production_schedule.key? :sweep_scheduler
  end

  test "omits sweep_scheduler entirely when SWEEP_INTERVAL_HOURS is 0" do
    ENV["SWEEP_INTERVAL_HOURS"] = "0"

    assert_not production_schedule.key? :sweep_scheduler
  end

  test "schedules sweep_scheduler every N hours when SWEEP_INTERVAL_HOURS is set" do
    ENV["SWEEP_INTERVAL_HOURS"] = "24"

    sweep_scheduler = production_schedule.fetch :sweep_scheduler
    assert_equal "SweepSchedulerJob", sweep_scheduler.fetch(:class)
    assert_equal "every 24 hours", sweep_scheduler.fetch(:schedule)
    assert_equal 86_400, Fugit::Nat.parse(sweep_scheduler.fetch(:schedule)).rough_frequency
  end

  test "the every N hours grammar still parses for N=1" do
    ENV["SWEEP_INTERVAL_HOURS"] = "1"

    sweep_scheduler = production_schedule.fetch :sweep_scheduler
    assert_equal 3_600, Fugit::Nat.parse(sweep_scheduler.fetch(:schedule)).rough_frequency
  end

  private

  def production_schedule
    config = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).deep_symbolize_keys
    config.fetch :production
  end
end
