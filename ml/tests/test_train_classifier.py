import gzip
import json
from pathlib import Path
from unittest.mock import Mock

import pandas as pd
import pytest

from training import train_classifier
from training.identity_tokens import extract_identity_tokens
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
            "search_keyword_phrases": [[]] * 8,
        }
    )

    pipeline = train(labels)

    assert pipeline.named_steps["clf"].classes_.tolist() == ["computer", "part"]
    vocabulary = pipeline.named_steps["tfidf"].vocabulary_
    assert "replacement" in vocabulary


@pytest.fixture(scope="module")
def fixture_identity_tokens(listing_labels):
    """Union of every identity token tied to any labeled listing in the real
    production fixture, via its own search_keyword_phrases - same
    computation train_classifier.collect_identity_tokens does."""
    tokens: set[str] = set()
    for row in listing_labels:
        tokens |= extract_identity_tokens(row["search_keyword_phrases"])
    return tokens


@pytest.fixture(scope="module")
def trained_pipeline(listing_labels):
    """Matches what main() actually trains now: identity tokens collected
    from every labeled listing's own search_keyword_phrases (permanent, via
    listing_search_keywords - not today's active search_keywords), applied
    as one global stop-word list so the same word can't be excluded in some
    titles and leak through in others."""
    return train(pd.DataFrame(listing_labels))


@pytest.mark.parametrize(
    "example",
    json.loads(
        gzip.decompress((Path(__file__).parent / "fixtures" / "listing_label_predictions.json.gz").read_bytes())
    ),
    ids=lambda example: example["title"],
)
def test_train_distinguishes_unseen_computers_and_parts(trained_pipeline, listing_labels, example):
    assert example["title"] not in {row["title"] for row in listing_labels}

    prediction = trained_pipeline.predict([example["title"]])

    assert prediction[0] == example["label"]


def test_identity_tokens_are_excluded_from_the_learned_vocabulary(trained_pipeline, fixture_identity_tokens):
    vocabulary = trained_pipeline.named_steps["tfidf"].vocabulary_

    assert not fixture_identity_tokens & vocabulary.keys()
    for descriptive_word in ["server", "rails", "heatsink", "fan", "caddy", "cage"]:
        assert descriptive_word in vocabulary


def test_identity_tokens_stay_excluded_even_when_only_some_rows_matched_a_brand_keyword():
    # Codex's regression (reviewing 9027e08): per-row exclusion let "dell"/
    # "poweredge" leak through the part rows (matched via bare "r740", no
    # brand qualifier) while being stripped from the computer rows (matched
    # via "(r640,...) (dell,poweredge)") - 100% cleaned-holdout accuracy hid
    # that raw-title inference still called a real computer "part" (~55.5%)
    # once "dell"/"poweredge" became part-associated vocabulary. A single
    # global exclusion list, collected across every row rather than applied
    # per-row, can't have this asymmetry.
    labels = pd.DataFrame(
        {
            "title": ["Dell PowerEdge R640 Server"] * 40 + ["Dell PowerEdge R740 Fan"] * 40,
            "label": ["computer"] * 40 + ["part"] * 40,
            "search_keyword_phrases": [['(r640,"r 640") (dell,poweredge)']] * 40 + [["r740"]] * 40,
        }
    )

    pipeline = train(labels)

    vocabulary = pipeline.named_steps["tfidf"].vocabulary_
    assert "dell" not in vocabulary
    assert "poweredge" not in vocabulary
    assert pipeline.predict(["Dell PowerEdge R640 Server"])[0] == "computer"


def test_identity_token_exclusion_keeps_the_verdict_stable_across_model_identifiers(trained_pipeline):
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

    assert set(trained_pipeline.predict(computer_titles)) == {"computer"}
    assert set(trained_pipeline.predict(part_titles)) == {"part"}


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
    fetch_labels = Mock(return_value=listing_labels)
    upload = Mock(return_value={"id": 42})
    monkeypatch.setenv("GODSLAYER_API_URL", "http://api.example.com")
    monkeypatch.setattr(train_classifier, "load_dotenv", Mock())
    monkeypatch.setattr(train_classifier, "fetch_listing_labels", fetch_labels)
    monkeypatch.setattr(train_classifier, "post_title_classifier_model", upload)
    monkeypatch.setattr(train_classifier.uuid, "uuid4", lambda: "test-version")

    train_classifier.main()

    fetch_labels.assert_called_once_with("http://api.example.com")
    upload.assert_called_once_with("http://api.example.com", **export_weights(trained_pipeline, version="test-version"))
    json.dumps(upload.call_args.kwargs)
