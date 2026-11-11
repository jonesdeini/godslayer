# frozen_string_literal: true

require "test_helper"

class Llm::GeminiClientTest < ActiveSupport::TestCase
  setup do
    ENV["GEMINI_API_KEY"] = "fake-key"
  end

  teardown do
    ENV.delete "GEMINI_API_KEY"
  end

  test "classifies a title, returning the model's single-word answer" do
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent")
      .with(headers: { "x-goog-api-key" => "fake-key" })
      .to_return(status: 200, body: { candidates: [ { content: { parts: [ { text: "computer" } ] } } ] }.to_json)

    assert_equal "computer", Llm::GeminiClient.new(rate_limit_delay_seconds: 0).classify_title("Dell R630 Server 2x E5-2650v4")
  end

  test "raises a clear error instead of parsing an error response as a verdict" do
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent")
      .with(headers: { "x-goog-api-key" => "fake-key" })
      .to_return(status: 429, body: { error: { message: "Quota exceeded" } }.to_json)

    error = assert_raises Llm::GeminiClient::RequestError do
      Llm::GeminiClient.new(rate_limit_delay_seconds: 0).classify_title "Dell R630 Server 2x E5-2650v4"
    end
    assert_match "429", error.message
  end
end
