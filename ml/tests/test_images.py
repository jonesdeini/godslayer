from unittest.mock import Mock, patch

from godslayer_ml.images import download


def test_download_returns_the_response_body_bytes():
    response = Mock(content=b"fake-image-bytes")
    response.raise_for_status.return_value = None

    with patch("godslayer_ml.images.requests.get", return_value=response) as get:
        body = download("http://images.example.com/a.jpg")

    get.assert_called_once_with("http://images.example.com/a.jpg", timeout=30)
    assert body == b"fake-image-bytes"
