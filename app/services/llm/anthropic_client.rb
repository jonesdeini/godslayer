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
                        messages: [ { role: "user", content: prompt(title) } ]
                      })

      JSON.parse(response.body.to_s).dig("content", 0, "text").strip
    end

    private

    def prompt(title)
      <<~PROMPT
        Classify this eBay listing title as exactly one word: computer or part.

        computer = a complete server or workstation, even if the listing doesn't mention
        RAM, drives, or an OS - it's still a whole machine.
        part = a standalone component or accessory being sold on its own (a CPU, a RAM
        stick, a drive caddy, a heatsink, a fan, a cable, a rail kit), not a whole machine.

        Respond with only the single word "computer" or "part", nothing else.

        Title: #{title}
      PROMPT
    end
  end
end
