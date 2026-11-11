import json
from pathlib import Path

import pytest


@pytest.fixture(scope="module")
def listing_labels():
    return json.loads((Path(__file__).parent / "fixtures" / "listing_labels.json").read_text())
