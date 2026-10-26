# frozen_string_literal: true

module Ebay
  class Item < Ebay::Base
    def self.detail(item_id)
      new.detail item_id
    end

    def detail(item_id)
      get "#{base_url}/item/#{ERB::Util.url_encode item_id}"
    end
  end
end
