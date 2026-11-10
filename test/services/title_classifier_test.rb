# frozen_string_literal: true

require "test_helper"

class TitleClassifierTest < ActiveSupport::TestCase
  # Real scikit-learn output, not invented - see the commit that added this file.
  def fixture
    @fixture ||= JSON.parse Rails.root.join("test/fixtures/files/title_classifier_parity.json").read
  end

  def model
    @model ||= TitleClassifierModel.create!(
      vocabulary: fixture["vocabulary"], idf: fixture["idf"], coef: fixture["coef"],
      intercept: fixture["intercept"], classes: fixture["classes"], version: "parity-fixture"
    )
  end

  test "matches scikit-learn's prediction and confidence for every fixture case" do
    model

    fixture["cases"].each do |example|
      verdict, confidence = TitleClassifier.classify example["title"]

      expected_verdict = example["predicted"]
      expected_confidence = example["proba"].max

      assert_equal expected_verdict, verdict, "verdict mismatch for #{example['title'].inspect}"
      assert_in_delta expected_confidence, confidence, 1e-9, "confidence mismatch for #{example['title'].inspect}"
    end
  end

  test "produces the same TF-IDF vector scikit-learn did, not just the same final verdict" do
    model
    classifier = TitleClassifier.new

    fixture["cases"].each do |example|
      vector = classifier.send :tfidf_vector, example["title"], model

      vector.each_with_index do |value, index|
        assert_in_delta example["tfidf_vector"][index], value, 1e-9,
          "tfidf mismatch at index #{index} for #{example['title'].inspect}"
      end
    end
  end

  test "returns a zero vector, not NaN, for a title with no vocabulary matches at all" do
    model

    verdict, confidence = TitleClassifier.classify "asdf qwerty zxcv"

    assert_includes model.classes, verdict
    assert confidence.finite?
  end

  test "raises when there is no active model" do
    assert_raises(RuntimeError) { TitleClassifier.classify "Dell Server" }
  end

  test ".version returns the active model's version" do
    model

    assert_equal "parity-fixture", TitleClassifier.version
  end
end
