#!/usr/bin/env -S uv run

# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "Pillow"
# ]
# ///

#!/usr/bin/env python3
"""
map_assembler.py — Assemble a series of images into one image along a compass direction.

Usage:
    python map_assembler.py -d north img_top.png img_second.png ... -o assembled_map.png

Directions define where successive images are placed relative to the first:
    north : stack images upward (later images go ABOVE earlier ones)
    south : stack images downward (later images go BELOW earlier ones)
    east  : place later images to the RIGHT of earlier ones
    west  : place later images to the LEFT of earlier ones

Notes:
    - All images are aligned at their top-left; mismatched sizes are padded
      with a fill color so nothing gets cropped.
    - If aspect ratios differ slightly (e.g., AI-generated maps), pass
      --scale-to-match to resize all images to the width/height of the first.
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required. Install it with: pip install Pillow")


def load_images(paths):
    """Load images, failing early with a clear message."""
    images = []
    for p in paths:
        path = Path(p)
        if not path.exists():
            sys.exit(f"Error: file not found: {path}")
        try:
            img = Image.open(path).convert("RGBA")
        except Exception as e:
            sys.exit(f"Error: could not open {path}: {e}")
        images.append(img)
    return images


def scale_to_reference(images):
    """Resize all images to match the width AND height of the first image."""
    ref_w, ref_h = images[0].size
    return [
        img.resize((ref_w, ref_h), Image.LANCZOS) if img.size != (ref_w, ref_h) else img
        for img in images
    ]


def assemble(images, direction, fill=(120, 120, 120, 255)):
    """
    Place images in order along the given direction.

    'north'/'west' reverse the stacking order so the LAST file lands
    farthest up/left, i.e., later images extend the map outward.
    """
    if direction in ("north", "west"):
        # Reverse so that assembling still "adds onto" the first image,
        # extending upward or leftward with each subsequent file.
        images = list(reversed(images))

    horizontal = direction in ("east", "west")

    if horizontal:
        canvas_w = sum(img.width for img in images)
        canvas_h = max(img.height for img in images)
    else:
        canvas_w = max(img.width for img in images)
        canvas_h = sum(img.height for img in images)

    canvas = Image.new("RGBA", (canvas_w, canvas_h), fill)

    x, y = 0, 0
    for img in images:
        canvas.paste(img, (x, y))
        if horizontal:
            x += img.width
        else:
            y += img.height

    return canvas


def main():
    parser = argparse.ArgumentParser(
        description="Assemble a series of images into one image along N/S/E/W."
    )
    parser.add_argument(
        "images", nargs="+",
        help="Image files in order (first image anchors the assembly)"
    )
    parser.add_argument(
        "-d", "--direction", default="north",
        choices=["north", "south", "east", "west"],
        help="Direction in which subsequent images extend the map"
    )
    parser.add_argument(
        "-o", "--output", default="assembled.png",
        help="Output file path (default: assembled.png)"
    )
    parser.add_argument(
        "--scale-to-match", action="store_true",
        help="Resize all images to the first image's dimensions (for AI-gen maps with slight size drift)"
    )
    parser.add_argument(
        "--fill", default="#787878",
        help="Background fill color for padding (hex, default: #787878)"
    )

    args = parser.parse_args()

    if len(args.images) < 2:
        sys.exit("Error: at least two images are required.")

    # Parse hex fill color
    try:
        fill_hex = args.fill.lstrip("#")
        fill = tuple(int(fill_hex[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    except (ValueError, IndexError):
        sys.exit(f"Error: invalid fill color '{args.fill}' (expected hex like #RRGGBB)")

    images = load_images(args.images)

    if args.scale_to_match:
        images = scale_to_reference(images)

    # Warn about aspect mismatches if not scaling
    if not args.scale_to_match:
        widths = {img.width for img in images}
        heights = {img.height for img in images}
        if len(widths) > 1 or len(heights) > 1:
            print(
                "Warning: images have differing dimensions; "
                "mismatched edges will be padded. Use --scale-to-match to force alignment.",
                file=sys.stderr,
            )

    result = assemble(images, args.direction, fill=fill)

    out_path = Path(args.output)
    if out_path.suffix.lower() == ".jpg":
        result = result.convert("RGB")  # JPEG has no alpha channel

    result.save(out_path)
    print(f"Assembled {len(args.images)} images -> {out_path} "
          f"({result.width}x{result.height})")


if __name__ == "__main__":
    main()