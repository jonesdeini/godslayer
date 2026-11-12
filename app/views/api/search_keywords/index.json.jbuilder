# frozen_string_literal: true

json.array! keywords do |keyword|
  json.id keyword.id
  json.phrase keyword.phrase
end
