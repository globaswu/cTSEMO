"""Recompose the four classification maps with one shared categorical key."""

from pathlib import Path

from matplotlib import font_manager
from PIL import Image, ImageDraw, ImageFont


REPOSITORY = Path(__file__).resolve().parents[2]
OUTPUT_DIR = (
    REPOSITORY / "manuscript" / "artifacts" / "two_dimensional_campaign" / "figures"
)
SOURCE = OUTPUT_DIR / "classification_error_maps_source.png"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    properties = font_manager.FontProperties(
        family=["Times New Roman", "Times", "DejaVu Serif"],
        weight="bold" if bold else "normal",
    )
    path = font_manager.findfont(properties, fallback_to_default=True)
    return ImageFont.truetype(path, size=size)


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    if source.size != (3499, 2886):
        raise RuntimeError(f"Unexpected source size: {source.size}")

    crops = [
        source.crop((0, 70, 1365, 1490)),
        source.crop((1745, 70, 3180, 1490)),
        source.crop((0, 1495, 1365, 2886)),
        source.crop((1745, 1495, 3180, 2886)),
    ]
    panel_width = max(panel.width for panel in crops)
    top_height = max(panel.height for panel in crops[:2])
    bottom_height = max(panel.height for panel in crops[2:])
    gap = 28
    margin = 20
    legend_height = 150
    canvas = Image.new(
        "RGB",
        (
            2 * panel_width + gap + 2 * margin,
            top_height + bottom_height + gap + legend_height + 2 * margin,
        ),
        "white",
    )
    positions = [
        (margin, margin),
        (margin + panel_width + gap, margin),
        (margin, margin + top_height + gap),
        (margin + panel_width + gap, margin + top_height + gap),
    ]
    for panel, position in zip(crops, positions, strict=True):
        canvas.paste(panel, position)

    legend = [
        ("correct violating", (31, 43, 61)),
        ("false feasible", (209, 46, 33)),
        ("false infeasible", (46, 122, 209)),
        ("correct feasible", (242, 158, 31)),
    ]
    draw = ImageDraw.Draw(canvas)
    label_font = font(44)
    y = top_height + bottom_height + gap + margin + 45
    item_width = (canvas.width - 2 * margin) // len(legend)
    for index, (label, color) in enumerate(legend):
        x = margin + index * item_width + 18
        draw.rectangle((x, y, x + 62, y + 42), fill=color, outline="black", width=2)
        draw.text((x + 78, y - 3), label, fill="black", font=label_font)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    png_path = OUTPUT_DIR / "classification_error_maps.png"
    pdf_path = OUTPUT_DIR / "classification_error_maps.pdf"
    canvas.save(png_path, dpi=(600, 600))
    canvas.save(pdf_path, "PDF", resolution=600.0)
    print(png_path)
    print(pdf_path)


if __name__ == "__main__":
    main()
