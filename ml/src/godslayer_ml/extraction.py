import json

import requests

OLLAMA_MODEL = "granite4.2:8b"

CLAIM_PROMPT = """Below are a seller's own words describing a used server listing's RAM.

Item specifics: {aspects}
Description text: {description}

What total RAM capacity does the seller claim? Respond with ONLY a JSON object with keys "ram_value" (a number) and "ram_unit" (a string like "GB" or "MB"). If no RAM claim is present, respond with {{"ram_value": null, "ram_unit": null}}."""

PHOTO_PROMPT = """Below is raw OCR text extracted from a photo of a server's BIOS Memory Information screen. OCR is imperfect - expect garbled characters, especially in unit suffixes.

OCR text:
---
{ocr}
---

What does this screen report as the "Total System Memory" (the single overall total installed RAM for the whole system, not a per-processor subtotal, not a single DIMM's size)? Respond with ONLY a JSON object with keys "ram_value" (a number) and "ram_unit" (a string like "MB" or "GB"). If you cannot find a clear total system memory figure, respond with {{"ram_value": null, "ram_unit": null}}."""


def _generate_json(ollama_url: str, prompt: str) -> dict:
    response = requests.post(
        f"{ollama_url}/api/generate",
        json={
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "stream": False,
            "format": "json",
            "options": {"temperature": 0.1},
        },
        timeout=300,
    )
    response.raise_for_status()
    return json.loads(response.json()["response"])


def extract_claimed_ram(aspects: str, description: str, ollama_url: str) -> dict:
    prompt = CLAIM_PROMPT.format(aspects=aspects, description=description)
    return _generate_json(ollama_url, prompt)


def extract_photo_ram(ocr_text: str, ollama_url: str) -> dict:
    prompt = PHOTO_PROMPT.format(ocr=ocr_text)
    return _generate_json(ollama_url, prompt)
