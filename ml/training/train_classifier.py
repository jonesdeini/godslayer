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
from training.identity_tokens import extract_identity_tokens, strip_identity_tokens

logger = logging.getLogger(__name__)


def build_pipeline() -> Pipeline:
    return Pipeline(
        [
            ("tfidf", TfidfVectorizer()),
            ("clf", LogisticRegression()),
        ]
    )


def clean_titles(labels: pd.DataFrame) -> pd.Series:
    """Strips each listing's own search-identity words (model numbers,
    brand/family names) out of its title before it ever reaches TF-IDF,
    scoped to the search_keyword(s) that actually matched that listing
    (labels["search_keyword_phrases"]) rather than to a single global list -
    these words identify which machine a result concerns, not whether it's
    the machine or an accessory, so letting the model learn from them risks
    tying the verdict to which search surfaced a result rather than to its
    actual content."""
    return labels.apply(
        lambda row: strip_identity_tokens(row["title"], extract_identity_tokens(row["search_keyword_phrases"])),
        axis=1,
    )


def train(labels: pd.DataFrame) -> Pipeline:
    titles = clean_titles(labels)
    x_train, x_test, y_train, y_test = train_test_split(
        titles, labels["label"], test_size=0.2, random_state=0, stratify=labels["label"]
    )

    pipeline = build_pipeline()
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
