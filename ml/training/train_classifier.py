import logging
import os

import joblib
import pandas as pd
from dotenv import load_dotenv
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline

from godslayer_ml.api_client import fetch_listing_labels

logger = logging.getLogger(__name__)

MODEL_PATH = os.path.join(os.path.dirname(__file__), "model.joblib")


def build_pipeline() -> Pipeline:
    return Pipeline(
        [
            ("tfidf", TfidfVectorizer()),
            ("clf", LogisticRegression()),
        ]
    )


def train(labels: pd.DataFrame) -> Pipeline:
    x_train, x_test, y_train, y_test = train_test_split(labels["title"], labels["label"], test_size=0.2, random_state=0)

    pipeline = build_pipeline()
    pipeline.fit(x_train, y_train)

    print(classification_report(y_test, pipeline.predict(x_test)))

    return pipeline


def main() -> None:
    load_dotenv()
    logging.basicConfig(level=logging.INFO)

    api_base_url = os.environ.get("GODSLAYER_API_URL", "http://localhost:3000")
    labels = pd.DataFrame(fetch_listing_labels(api_base_url))

    pipeline = train(labels)
    joblib.dump(pipeline, MODEL_PATH)
    logger.info("Wrote trained pipeline to %s", MODEL_PATH)


if __name__ == "__main__":
    main()
