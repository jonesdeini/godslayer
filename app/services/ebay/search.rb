# frozen_string_literal: true

module Ebay
  class Search < Ebay::Base
    def self.keyword(phrase, exclude_phrase: nil)
      new.keyword phrase, exclude_phrase:
    end

    def keyword(phrase, exclude_phrase: nil)
      url = "#{base_url}/item_summary/search?#{query_string phrase, exclude_phrase}"
      summaries = []

      while url
        page = JSON.parse get(url)
        summaries.concat page.fetch("itemSummaries", [])
        url = page["next"]
      end

      summaries
    end

    private

    def query_string(phrase, exclude_phrase)
      q = exclude_phrase.present? ? %(#{phrase} -"#{exclude_phrase}") : phrase
      params = { q:, sort: "newlyListed", limit: 200 }
      params[:filter] = price_filter if price_cap_cents.positive?
      URI.encode_www_form params
    end

    def price_filter
      "price:[..#{price_cap_cents / 100.0}],priceCurrency:USD"
    end

    def price_cap_cents
      Rails.application.config.x.ebay.price_cap_cents
    end
  end
end
