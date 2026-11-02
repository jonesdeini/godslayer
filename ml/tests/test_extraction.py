import json
from unittest.mock import Mock, patch

from godslayer_ml.extraction import extract_claimed_ram, extract_photo_ram


def ollama_response(parsed_json):
    response = Mock()
    response.raise_for_status.return_value = None
    response.json.return_value = {"response": json.dumps(parsed_json)}
    return response


def test_extract_claimed_ram_parses_the_model_s_json_response():
    response = ollama_response({"ram_value": 128, "ram_unit": "GB"})

    with patch("godslayer_ml.extraction.requests.post", return_value=response) as post:
        result = extract_claimed_ram("RAM Size: 128GB RAM", "128GB (4x32GB) DDR4", "http://ollama.example.com")

    assert result == {"ram_value": 128, "ram_unit": "GB"}
    url, kwargs = post.call_args.args[0], post.call_args.kwargs
    assert url == "http://ollama.example.com/api/generate"
    assert kwargs["json"]["format"] == "json"
    assert "RAM Size: 128GB RAM" in kwargs["json"]["prompt"]
    assert "128GB (4x32GB) DDR4" in kwargs["json"]["prompt"]


def test_extract_photo_ram_parses_the_model_s_json_response():
    response = ollama_response({"ram_value": 114688, "ram_unit": "MB"})

    with patch("godslayer_ml.extraction.requests.post", return_value=response) as post:
        result = extract_photo_ram("Total System Memory 114688 MB", "http://ollama.example.com")

    assert result == {"ram_value": 114688, "ram_unit": "MB"}
    assert "Total System Memory 114688 MB" in post.call_args.kwargs["json"]["prompt"]


def test_extract_returns_null_fields_when_the_model_finds_nothing():
    response = ollama_response({"ram_value": None, "ram_unit": None})

    with patch("godslayer_ml.extraction.requests.post", return_value=response):
        result = extract_photo_ram("a front panel photo, no BIOS text at all", "http://ollama.example.com")

    assert result == {"ram_value": None, "ram_unit": None}
