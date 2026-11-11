import json
from pathlib import Path
from unittest.mock import Mock

import pandas as pd
import pytest

from training import train_classifier
from training.train_classifier import export_weights, train

# Brand/product-family/model tokens actually present in the fixtures below -
# not the real production identity-token list, which depends on Godslayer's
# actual search_keywords and is still an open decision (see #45).
FIXTURE_IDENTITY_TOKENS = {
    "dell",
    "poweredge",
    "precision",
    "r630",
    "r730",
    "r740",
    "t5810",
    "hp",
    "hpe",
    "proliant",
    "dl360",
    "dl380",
    "lenovo",
    "thinkstation",
    "thinksystem",
    "sr630",
    "sr650",
    "supermicro",
}


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
    """Matches what main() actually trains today - no identity_tokens, since
    wiring a real identity-token source into production is still an open
    decision (see #45), not yet made."""
    return train(pd.DataFrame(listing_labels))


@pytest.fixture(scope="module")
def identity_token_pipeline(listing_labels):
    return train(pd.DataFrame(listing_labels), identity_tokens=FIXTURE_IDENTITY_TOKENS)


@pytest.mark.parametrize(
    "example",
    json.loads((Path(__file__).parent / "fixtures" / "listing_label_predictions.json").read_text()),
    ids=lambda example: example["title"],
)
def test_train_distinguishes_unseen_computers_and_parts(identity_token_pipeline, listing_labels, example):
    assert example["title"] not in {row["title"] for row in listing_labels}

    prediction = identity_token_pipeline.predict([example["title"]])

    assert prediction[0] == example["label"]


def test_identity_tokens_are_excluded_from_the_learned_vocabulary(identity_token_pipeline):
    vocabulary = identity_token_pipeline.named_steps["tfidf"].vocabulary_

    assert not FIXTURE_IDENTITY_TOKENS & vocabulary.keys()
    for descriptive_word in ["server", "workstation", "replacement", "fan", "caddy", "motherboard"]:
        assert descriptive_word in vocabulary


def test_identity_token_exclusion_keeps_the_verdict_stable_across_model_identifiers(identity_token_pipeline):
    # Same descriptive content, different model number - Codex's recommended
    # regression for the actual bug (the model learning from *which* search
    # surfaced a result, not from the listing's content).
    computer_titles = [
        "Dell PowerEdge R630 Server",
        "Dell PowerEdge R730 Server",
        "Dell PowerEdge R740 Server",
    ]
    part_titles = [
        "Dell PowerEdge R630 Replacement Fan Module",
        "Dell PowerEdge R730 Replacement Fan Module",
        "Dell PowerEdge R740 Replacement Fan Module",
    ]

    assert set(identity_token_pipeline.predict(computer_titles)) == {"computer"}
    assert set(identity_token_pipeline.predict(part_titles)) == {"part"}


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
