import json
import os

import pytest

from godslayer_ml.consumer import QUEUE_NAME, connect, handle_message


@pytest.fixture
def channel():
    connection = connect(os.environ.get("RABBITMQ_URL", "amqp://guest:guest@localhost:5672"))
    channel = connection.channel()
    channel.queue_declare(queue=QUEUE_NAME, durable=True)
    channel.queue_purge(QUEUE_NAME)
    yield channel
    connection.close()


def test_handle_message_parses_the_listing_id_and_acks(channel):
    channel.basic_publish(exchange="", routing_key=QUEUE_NAME, body=json.dumps({"listing_id": 42}))

    method, properties, body = channel.basic_get(QUEUE_NAME, auto_ack=False)
    listing_id = handle_message(channel, method, properties, body)

    assert listing_id == 42

    method, _, _ = channel.basic_get(QUEUE_NAME, auto_ack=False)
    assert method is None
