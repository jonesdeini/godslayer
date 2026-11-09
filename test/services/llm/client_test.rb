# frozen_string_literal: true

require "test_helper"

class Llm::ClientTest < ActiveSupport::TestCase
  teardown do
    ENV.delete "LLM_PROVIDER"
  end

  test "defaults to the gemini provider" do
    assert_equal Llm::GeminiClient, Llm::Client.provider
  end

  test "resolves to the gemini provider when configured" do
    ENV["LLM_PROVIDER"] = "gemini"

    assert_equal Llm::GeminiClient, Llm::Client.provider
  end

  test "raises for an unconfigured provider" do
    ENV["LLM_PROVIDER"] = "openai"

    assert_raises(ArgumentError) { Llm::Client.provider }
  end
end
