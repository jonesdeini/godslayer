# frozen_string_literal: true

module Ebay
  class Search < Ebay::Base
    def self.keyword(phrase)
      new.keyword phrase
    end

    def keyword(phrase)
      get "#{base_url}/item_summary/search?#{query_string phrase}"
    end

    private

    def query_string(phrase)
      params = { q: phrase, sort: "newlyListed", limit: 100 }
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
