import logging
import os
import uuid

import pandas as pd
from dotenv import load_dotenv
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline

from godslayer_ml.api_client import fetch_listing_labels, post_title_classifier_model
from training.identity_tokens import extract_identity_tokens

logger = logging.getLogger(__name__)


def build_pipeline(identity_tokens: set[str] | None = None) -> Pipeline:
    """identity_tokens are search-identity words (model numbers, brand/family
    names) excluded from the learned vocabulary - they identify which machine
    a result concerns, not whether it's the machine or an accessory, so
    letting the model learn from them risks tying the verdict to which
    search surfaced a result rather than to its actual content. Applied
    globally, the same way to every title: TfidfVectorizer only supports one
    fixed stop-word list for the whole corpus, and excluding a word from
    some titles but not others (e.g. only the ones whose own matched keyword
    happened to spell it out) lets it leak back in through the rest -
    inconsistent across rows is just as broken as not excluding it at all."""
    return Pipeline(
        [
            ("tfidf", TfidfVectorizer(stop_words=list(identity_tokens) if identity_tokens else None)),
            ("clf", LogisticRegression()),
        ]
    )


def collect_identity_tokens(labels: pd.DataFrame) -> set[str]:
    """Union of identity tokens across every search_keyword that has ever
    matched any labeled listing (labels["search_keyword_phrases"], from each
    listing's permanent listing_search_keywords history) - not scoped to
    which keywords are active today, so retiring one can't silently stop
    excluding the tokens tied to labels it already produced."""
    tokens: set[str] = set()
    for phrases in labels["search_keyword_phrases"]:
        tokens |= extract_identity_tokens(phrases)
    return tokens


def train(labels: pd.DataFrame) -> Pipeline:
    identity_tokens = collect_identity_tokens(labels)
    x_train, x_test, y_train, y_test = train_test_split(
        labels["title"], labels["label"], test_size=0.2, random_state=0, stratify=labels["label"]
    )

    pipeline = build_pipeline(identity_tokens)
    pipeline.fit(x_train, y_train)

    print(classification_report(y_test, pipeline.predict(x_test)))

    return pipeline


def export_weights(pipeline: Pipeline, version: str) -> dict:
    """The learned numbers behind a fitted pipeline, as plain JSON-able data."""
    tfidf = pipeline.named_steps["tfidf"]
    clf = pipeline.named_steps["clf"]

    return {
        "vocabulary": {word: int(index) for word, index in tfidf.vocabulary_.items()},
        "idf": tfidf.idf_.tolist(),
        "coef": clf.coef_[0].tolist(),
        "intercept": float(clf.intercept_[0]),
        "classes": clf.classes_.tolist(),
        "version": version,
    }


def main() -> None:
    load_dotenv()
    logging.basicConfig(level=logging.INFO)

    api_base_url = os.environ.get("GODSLAYER_API_URL", "http://localhost:3000")
    labels = pd.DataFrame(fetch_listing_labels(api_base_url))

    pipeline = train(labels)
    weights = export_weights(pipeline, version=str(uuid.uuid4()))
    model = post_title_classifier_model(api_base_url, **weights)
    logger.info("Posted trained model version=%s (id=%s) to %s", weights["version"], model["id"], api_base_url)


if __name__ == "__main__":
    main()
