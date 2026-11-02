import io

from PIL import Image, ImageDraw

from godslayer_ml.ocr import read_text


def test_read_text_extracts_text_from_a_real_image_via_tesseract():
    image = Image.new("RGB", (200, 60), color="white")
    ImageDraw.Draw(image).text((10, 20), "TOTAL MEMORY 112", fill="black")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")

    text = read_text(buffer.getvalue())

    assert "TOTAL" in text
    assert "112" in text
