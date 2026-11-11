import json
from pathlib import Path
from unittest.mock import Mock

import pandas as pd
import pytest

from training import train_classifier
from training.train_classifier import export_weights, train


def test_train_preserves_both_classes_when_parts_are_a_minority():
    # With random_state=0, an unstratified split puts rows 2 and 6 in
    # holdout, removing every part from the training set.
    labels = pd.DataFrame(
        {
            "title": [
                "Dell PowerEdge Server",
                "HP ProLiant Server",
                "Replacement Server Fan",
                "Lenovo ThinkStation Workstation",
                "Supermicro Rack Server",
                "Dell Precision Workstation",
                "Replacement Drive Caddy",
                "HP Z Workstation",
            ],
            "label": ["computer", "computer", "part", "computer", "computer", "computer", "part", "computer"],
        }
    )

    pipeline = train(labels)

    assert pipeline.named_steps["clf"].classes_.tolist() == ["computer", "part"]
    vocabulary = pipeline.named_steps["tfidf"].vocabulary_
    assert "replacement" in vocabulary


@pytest.fixture(scope="module")
def trained_pipeline(listing_labels):
    return train(pd.DataFrame(listing_labels))


@pytest.mark.parametrize(
    "example",
    json.loads((Path(__file__).parent / "fixtures" / "listing_label_predictions.json").read_text()),
    ids=lambda example: example["title"],
)
def test_train_distinguishes_unseen_computers_and_parts(trained_pipeline, listing_labels, example):
    assert example["title"] not in {row["title"] for row in listing_labels}

    prediction = trained_pipeline.predict([example["title"]])

    assert prediction[0] == example["label"]


def test_export_weights_produces_json_able_data_matching_the_fitted_pipeline(trained_pipeline):
    pipeline = trained_pipeline

    weights = export_weights(pipeline, version="test-version")

    tfidf = pipeline.named_steps["tfidf"]
    clf = pipeline.named_steps["clf"]
    assert weights["version"] == "test-version"
    assert weights["vocabulary"] == {word: int(index) for word, index in tfidf.vocabulary_.items()}
    assert weights["idf"] == tfidf.idf_.tolist()
    assert weights["coef"] == clf.coef_[0].tolist()
    assert weights["intercept"] == float(clf.intercept_[0])
    assert weights["classes"] == clf.classes_.tolist()
    json.dumps(weights)  # must be JSON-serializable, no numpy scalars


def test_main_trains_on_rails_labels_and_uploads_exported_weights(monkeypatch, listing_labels, trained_pipeline):
    fetch = Mock(return_value=listing_labels)
    upload = Mock(return_value={"id": 42})
    monkeypatch.setenv("GODSLAYER_API_URL", "http://api.example.com")
    monkeypatch.setattr(train_classifier, "load_dotenv", Mock())
    monkeypatch.setattr(train_classifier, "fetch_listing_labels", fetch)
    monkeypatch.setattr(train_classifier, "post_title_classifier_model", upload)
    monkeypatch.setattr(train_classifier.uuid, "uuid4", lambda: "test-version")

    train_classifier.main()

    fetch.assert_called_once_with("http://api.example.com")
    upload.assert_called_once_with("http://api.example.com", **export_weights(trained_pipeline, version="test-version"))
    json.dumps(upload.call_args.kwargs)
