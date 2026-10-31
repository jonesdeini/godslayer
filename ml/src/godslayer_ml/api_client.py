import requests


def fetch_listing(listing_id: int, base_url: str) -> dict:
    response = requests.get(f"{base_url}/api/listings/{listing_id}", timeout=30)
    response.raise_for_status()
    return response.json()
