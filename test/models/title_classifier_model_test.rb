# frozen_string_literal: true

require "test_helper"

class TitleClassifierModelTest < ActiveSupport::TestCase
  def valid_attributes
    { vocabulary: { "server" => 0 }, idf: [ 1.2 ], coef: [ 0.5 ], intercept: 0.1,
      classes: [ "computer", "part" ], version: "v1" }
  end

  test "is valid with all required fields present" do
    model = TitleClassifierModel.new valid_attributes

    assert model.valid?
  end

  test "requires vocabulary, idf, coef, classes, intercept, and version" do
    model = TitleClassifierModel.new

    assert_not model.valid?
    %i[vocabulary idf coef classes intercept version].each do |field|
      assert_includes model.errors[field], "can't be blank"
    end
  end

  test ".active returns the currently active row" do
    TitleClassifierModel.create! valid_attributes.merge(version: "v1", active: false)
    active = TitleClassifierModel.create! valid_attributes.merge(version: "v2", active: true)

    assert_equal active.id, TitleClassifierModel.active.id
  end
end
