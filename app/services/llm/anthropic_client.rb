# frozen_string_literal: true

module Llm
  class AnthropicClient
    API_URL = "https://api.anthropic.com/v1/messages"
    MODEL = "claude-haiku-4-5-20251001"

    def self.classify_title(title)
      new.classify_title title
    end

    def self.model
      MODEL
    end

    def classify_title(title)
      response = HTTP.timeout(30)
                      .headers(
                        "x-api-key" => ENV.fetch("ANTHROPIC_API_KEY"),
                        "anthropic-version" => "2023-06-01"
                      )
                      .post(API_URL, json: {
                        model: MODEL,
                        max_tokens: 5,
                        messages: [ { role: "user", content: Llm.classify_title_prompt(title) } ]
                      })

      JSON.parse(response.body.to_s).dig("content", 0, "text").strip
    end
  end
end
