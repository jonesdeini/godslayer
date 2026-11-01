import logging

from godslayer_ml.api_client import fetch_listing
from godslayer_ml.determinations import compare_ram
from godslayer_ml.extraction import extract_claimed_ram, extract_photo_ram
from godslayer_ml.images import download
from godslayer_ml.ocr import read_text

logger = logging.getLogger(__name__)

NO_RAM_EVIDENCE = {"ram_value": None, "ram_unit": None}


def format_aspects(aspects: list[dict] | None) -> str:
    return ", ".join(f"{a['name']}: {a['value']}" for a in aspects or [])


def find_photo_ram(images: list[dict], ollama_url: str) -> dict:
    for image in images:
        text = read_text(download(image["url"]))
        photo_ram = extract_photo_ram(text, ollama_url)
        if photo_ram.get("ram_value") is not None:
            return photo_ram
    return NO_RAM_EVIDENCE


def process_listing(listing_id: int, api_base_url: str, ollama_url: str) -> None:
    listing = fetch_listing(listing_id, api_base_url)

    claimed_ram = extract_claimed_ram(
        format_aspects(listing.get("localized_aspects")),
        listing.get("description") or "",
        ollama_url,
    )
    photo_ram = find_photo_ram(listing.get("images", []), ollama_url)
    result = compare_ram(claimed_ram, photo_ram)

    logger.info("listing_id=%s ram_determination=%r", listing_id, result)
