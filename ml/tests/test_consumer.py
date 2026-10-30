import json
from unittest.mock import Mock

from godslayer_ml.consumer import handle_message


def test_handle_message_parses_the_listing_id_and_acks():
    channel = Mock()
    method = Mock(delivery_tag=1)
    body = json.dumps({"listing_id": 42}).encode()

    listing_id = handle_message(channel, method, None, body)

    assert listing_id == 42
    channel.basic_ack.assert_called_once_with(delivery_tag=1)
