# frozen_string_literal: true

class TitleClassifier
  # Mirrors sklearn's default TfidfVectorizer token_pattern.
  TOKEN_PATTERN = /[a-z0-9_]{2,}/

  def self.classify(title)
    new.classify title
  end

  def self.version
    TitleClassifierModel.active&.version
  end

  def classify(title)
    model = TitleClassifierModel.active
    raise "No active TitleClassifierModel" unless model

    decision = dot(tfidf_vector(title, model), model.coef) + model.intercept.to_f
    probability_positive = sigmoid decision

    if decision.positive?
      [ model.classes[1], probability_positive ]
    else
      [ model.classes[0], 1 - probability_positive ]
    end
  end

  private

  def tfidf_vector(title, model)
    counts = Hash.new 0
    title.downcase.scan(TOKEN_PATTERN).each do |token|
      index = model.vocabulary[token]
      counts[index] += 1 if index
    end

    raw = Array.new model.idf.size, 0.0
    counts.each { |index, count| raw[index] = count * model.idf[index] }

    l2_normalize raw
  end

  def l2_normalize(vector)
    norm = Math.sqrt(vector.sum { |value| value * value })
    return vector if norm.zero?

    vector.map { |value| value / norm }
  end

  def dot(a, b)
    a.each_with_index.sum { |value, index| value * b[index] }
  end

  def sigmoid(x)
    1.0 / (1.0 + Math.exp(-x))
  end
end
