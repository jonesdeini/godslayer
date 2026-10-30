# frozen_string_literal: true

require "bunny-mock"

BunnyMock.use_bunny_queue_pop_api = true

module Bunny
  class << self
    attr_accessor :test_session

    def new(*)
      self.test_session ||= BunnyMock.new.start
    end
  end
end
