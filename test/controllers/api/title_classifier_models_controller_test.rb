# frozen_string_literal: true

require "test_helper"

class Api::TitleClassifierModelsControllerTest < ActionDispatch::IntegrationTest
  test "creates a title classifier model and returns it as JSON" do
    post api_title_classifier_models_path, as: :json, params: {
      title_classifier_model: {
        vocabulary: { "server" => 0, "fan" => 1 },
        idf: [ 1.2, 1.4 ],
        coef: [ 0.8, -0.3 ],
        intercept: 0.1,
        classes: [ "computer", "part" ],
        version: "v1"
      }
    }

    assert_response :created
    body = JSON.parse response.body
    assert_equal "v1", body["version"]
    assert_equal true, body["active"]
    assert_equal({ "server" => 0, "fan" => 1 }, body["vocabulary"])
  end

  test "deactivates a previous model when a new one is created" do
    post api_title_classifier_models_path, as: :json, params: {
      title_classifier_model: { vocabulary: { "a" => 0 }, idf: [ 1.0 ], coef: [ 0.5 ],
                                 intercept: 0.0, classes: [ "computer", "part" ], version: "v1" }
    }
    first_id = JSON.parse(response.body)["id"]

    post api_title_classifier_models_path, as: :json, params: {
      title_classifier_model: { vocabulary: { "b" => 0 }, idf: [ 1.0 ], coef: [ 0.5 ],
                                 intercept: 0.0, classes: [ "computer", "part" ], version: "v2" }
    }

    assert_response :created
    assert_not TitleClassifierModel.find(first_id).active?
  end

  test "renders a JSON 422 when required fields are missing" do
    post api_title_classifier_models_path, as: :json, params: { title_classifier_model: { version: "v1" } }

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["error"].present?
  end
end
