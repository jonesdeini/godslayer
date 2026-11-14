import gzip
import json
from pathlib import Path

import pytest


@pytest.fixture(scope="module")
def listing_labels():
    path = Path(__file__).parent / "fixtures" / "listing_labels.json.gz"
    return json.loads(gzip.decompress(path.read_bytes()))
