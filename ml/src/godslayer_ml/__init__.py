import logging
import os

from dotenv import load_dotenv

from godslayer_ml.consumer import run


def main() -> None:
    load_dotenv()
    logging.basicConfig(level=logging.INFO)
    run(os.environ["RABBITMQ_URL"])
