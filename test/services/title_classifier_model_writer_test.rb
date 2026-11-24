# frozen_string_literal: true

require "test_helper"

class TitleClassifierModelWriterTest < ActiveSupport::TestCase
  def valid_attributes
    { vocabulary: { "server" => 0 }, idf: [ 1.2 ], coef: [ 0.5 ], intercept: 0.1, classes: [ "computer", "part" ] }
  end

  test "writes a new active model" do
    model = TitleClassifierModelWriter.write(**valid_attributes, version: "v1")

    assert model.persisted?
    assert model.active?
    assert_equal "v1", model.version
  end

  test "deactivates the previous active model" do
    first = TitleClassifierModelWriter.write(**valid_attributes, version: "v1")

    second = TitleClassifierModelWriter.write(**valid_attributes, version: "v2")

    assert_not first.reload.active?
    assert second.active?
  end
end
