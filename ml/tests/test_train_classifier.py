import json
from unittest.mock import Mock

import pandas as pd

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


def test_train_fits_a_pipeline_that_distinguishes_computers_from_parts():
    labels = pd.DataFrame(
        {
            "title": [
                "Dell R630 Server 2x E5-2650v4 64GB RAM",
                "HP DL380 Gen9 Server 128GB RAM",
                "Supermicro 2U Server Dual Xeon",
                "Lenovo Workstation Tower Xeon",
                "Intel Xeon E5-2650 v4 CPU Only",
                "32GB DDR4 RDIMM Server Memory Stick",
                "HDD Caddy for Dell R630 3.5 inch",
                "Replacement Fan for HP DL380 Server",
            ],
            "label": ["computer", "computer", "computer", "computer", "part", "part", "part", "part"],
        }
    )

    pipeline = train(labels)

    predictions = pipeline.predict(["Dell PowerEdge R630 Server", "Intel Xeon Replacement CPU Only"])

    assert predictions[0] == "computer"
    assert predictions[1] == "part"


def test_export_weights_produces_json_able_data_matching_the_fitted_pipeline():
    labels = pd.DataFrame(
        {
            "title": [
                "Dell Server",
                "HP Server",
                "Lenovo Server",
                "Supermicro Server",
                "Replacement Fan",
                "RAM Stick",
                "Replacement CPU",
                "Drive Caddy",
            ],
            "label": ["computer", "computer", "computer", "computer", "part", "part", "part", "part"],
        }
    )
    pipeline = train(labels)

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


def test_main_uploads_exported_weights_to_the_configured_rails_app(monkeypatch):
    labels = [
        {"title": "Dell Server", "label": "computer"},
        {"title": "HP Server", "label": "computer"},
        {"title": "Replacement Fan", "label": "part"},
        {"title": "RAM Stick", "label": "part"},
    ]
    pipeline = train_classifier.build_pipeline()
    pipeline.fit([row["title"] for row in labels], [row["label"] for row in labels])
    fetch = Mock(return_value=labels)
    fit = Mock(return_value=pipeline)
    upload = Mock(return_value={"id": 42})
    monkeypatch.setenv("GODSLAYER_API_URL", "http://api.example.com")
    monkeypatch.setattr(train_classifier, "load_dotenv", Mock())
    monkeypatch.setattr(train_classifier, "fetch_listing_labels", fetch)
    monkeypatch.setattr(train_classifier, "train", fit)
    monkeypatch.setattr(train_classifier, "post_title_classifier_model", upload)
    monkeypatch.setattr(train_classifier.uuid, "uuid4", lambda: "test-version")

    train_classifier.main()

    fetch.assert_called_once_with("http://api.example.com")
    fit.assert_called_once()
    pd.testing.assert_frame_equal(fit.call_args.args[0], pd.DataFrame(labels))
    upload.assert_called_once_with("http://api.example.com", **export_weights(pipeline, version="test-version"))
