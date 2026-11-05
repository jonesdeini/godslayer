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
      params[:filter] = filters.join(",") if filters.any?
      URI.encode_www_form params
    end

    def filters
      [ price_filter, location_filter ].compact
    end

    def price_filter
      return unless price_cap_cents.positive?

      "price:[..#{price_cap_cents / 100.0}],priceCurrency:USD"
    end

    def location_filter
      return if item_location_country.blank?

      "itemLocationCountry:#{item_location_country}"
    end

    def price_cap_cents
      Rails.application.config.x.ebay.price_cap_cents
    end

    def item_location_country
      Rails.application.config.x.ebay.item_location_country
    end
  end
end
