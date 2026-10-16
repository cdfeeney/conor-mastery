"""Find individual sprites in a tileset by connected alpha regions and write a numbered contact sheet.

Usage: python art/tools/extract_sprites.py <tileset.png> <out_dir> [--min 6]
Writes <out_dir>/<stem>-index.png (numbered boxes, 3x) and <out_dir>/<stem>-boxes.json ({index: [x, y, w, h]}).
The JSON boxes feed art/tools/build_sprites.py, which crops the chosen ones into the app's asset catalog.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def regions(img: Image.Image, min_size: int) -> list[tuple[int, int, int, int]]:
    """Bounding boxes of 8-connected opaque regions (alpha > 0), merged when they overlap."""
    w, h = img.size
    alpha = img.getchannel("A").load()
    seen = [[False] * w for _ in range(h)]
    boxes = []
    for y in range(h):
        for x in range(w):
            if seen[y][x] or alpha[x, y] == 0:
                continue
            stack = [(x, y)]
            seen[y][x] = True
            x0 = x1 = x
            y0 = y1 = y
            while stack:
                cx, cy = stack.pop()
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                for nx in (cx - 1, cx, cx + 1):
                    for ny in (cy - 1, cy, cy + 1):
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and alpha[nx, ny] > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if x1 - x0 + 1 >= min_size and y1 - y0 + 1 >= min_size:
                boxes.append((x0, y0, x1 - x0 + 1, y1 - y0 + 1))
    return sorted(boxes, key=lambda b: (b[1] // 16, b[0]))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tileset")
    parser.add_argument("out_dir")
    parser.add_argument("--min", type=int, default=6)
    args = parser.parse_args()
    img = Image.open(args.tileset).convert("RGBA")
    boxes = regions(img, args.min)
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    scale = 3
    sheet = Image.new("RGBA", img.size, (40, 44, 60, 255))
    sheet.alpha_composite(img)
    sheet = sheet.resize((img.width * scale, img.height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(sheet)
    for i, (x, y, w, h) in enumerate(boxes):
        draw.rectangle([x * scale, y * scale, (x + w) * scale - 1, (y + h) * scale - 1], outline=(255, 70, 70, 255))
        draw.text((x * scale + 2, y * scale + 1), str(i), fill=(255, 255, 0, 255))
    stem = Path(args.tileset).stem
    sheet.save(out / f"{stem}-index.png")
    (out / f"{stem}-boxes.json").write_text(json.dumps({i: b for i, b in enumerate(boxes)}), encoding="utf-8")
    print(f"{stem}: {len(boxes)} sprites")
    return 0


if __name__ == "__main__":
    sys.exit(main())
