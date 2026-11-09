# frozen_string_literal: true

module Llm
  def self.classify_title_prompt(title)
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
