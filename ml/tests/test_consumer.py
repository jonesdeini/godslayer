import json
from unittest.mock import Mock, patch

from godslayer_ml.consumer import handle_message


def test_handle_message_parses_the_listing_id_processes_it_and_acks():
    channel = Mock()
    method = Mock(delivery_tag=1)
    body = json.dumps({"listing_id": 42}).encode()

    with patch("godslayer_ml.consumer.process_listing") as process_listing:
        listing_id = handle_message(channel, method, None, body, api_base_url="http://api.example.com")

    assert listing_id == 42
    process_listing.assert_called_once_with(42, "http://api.example.com")
    channel.basic_ack.assert_called_once_with(delivery_tag=1)
