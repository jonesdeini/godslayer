import logging
import os

import sentry_sdk
from dotenv import load_dotenv

from godslayer_ml.consumer import run


def main() -> None:
    load_dotenv()
    logging.basicConfig(level=logging.INFO)

    if dsn := os.environ.get("SENTRY_DSN"):
        sentry_sdk.init(dsn=dsn, traces_sample_rate=0.0)

    run(
        os.environ["RABBITMQ_URL"],
        os.environ.get("GODSLAYER_API_URL", "http://localhost:3000"),
        os.environ.get("OLLAMA_URL", "http://localhost:11434"),
    )
