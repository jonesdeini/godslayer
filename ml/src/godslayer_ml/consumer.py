import json
import logging

import pika

QUEUE_NAME = "listing_ready"

logger = logging.getLogger(__name__)


def connect(amqp_url: str) -> pika.BlockingConnection:
    return pika.BlockingConnection(pika.URLParameters(amqp_url))


def handle_message(channel, method, properties, body) -> int:
    listing_id = json.loads(body)["listing_id"]
    logger.info("received listing_ready for listing_id=%s", listing_id)
    channel.basic_ack(delivery_tag=method.delivery_tag)
    return listing_id


def run(amqp_url: str) -> None:
    connection = connect(amqp_url)
    channel = connection.channel()
    channel.queue_declare(queue=QUEUE_NAME, durable=True)
    channel.basic_consume(queue=QUEUE_NAME, on_message_callback=handle_message)

    try:
        channel.start_consuming()
    finally:
        connection.close()
