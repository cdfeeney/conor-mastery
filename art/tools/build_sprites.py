"""Crop the garden sprites we use out of the Ninja Adventure tilesets (CC0) and compose a sample scene.

Every item id in MasteryCore's Catalog maps to (sheet, x, y, w, h) on the pack's 16 px grid. Output:
  art/sprites/<id>.png        individual sprites (1x, transparent)
  art/sprites/belt-<c>.png    the player character recoloured per belt (palette swap of the pack's Monk)
  art/preview/garden-mock.png a 4x sample garden in three states (bare, growing, thriving)

Usage: python art/tools/build_sprites.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "art" / "vendor" / "ninja-adventure" / "Ninja Adventure - Asset Pack"
TILES = PACK / "Backgrounds" / "Tilesets"
OUT = ROOT / "art" / "sprites"
PREVIEW = ROOT / "art" / "preview"

# id -> (sheet, x, y, w, h). Coordinates are in source pixels on the pack's 16 px grid.
SPRITES: dict[str, tuple[str, int, int, int, int]] = {
    "grass-tuft": ("TilesetNature.png", 0, 160, 16, 16),
    "sunflower": ("TilesetNature.png", 0, 176, 16, 16),
    "red-flower": ("TilesetNature.png", 48, 176, 16, 16),
    "bamboo": ("TilesetNature.png", 176, 128, 16, 48),
    "pine": ("TilesetNature.png", 32, 0, 32, 32),
    "round-tree": ("TilesetNature.png", 0, 0, 32, 32),
    "bonsai": ("TilesetNature.png", 96, 0, 32, 32),
    "pink-bush": ("TilesetNature.png", 224, 0, 32, 32),
    "boulder": ("TilesetNature.png", 256, 128, 32, 32),
    "cherry": ("TilesetNature.png", 0, 288, 48, 48),
    "maple": ("TilesetNature.png", 144, 288, 48, 48),
    "stump": ("TilesetNature.png", 0, 128, 32, 32),
    "torii": ("TilesetHouse.png", 0, 80, 48, 32),
    "dojo": ("TilesetHouse.png", 192, 0, 64, 48),
    "dojo-sign": ("TilesetHouse.png", 64, 64, 32, 16),
    "hut": ("TilesetHouse.png", 48, 128, 48, 32),
    "tent": ("TilesetHouse.png", 0, 112, 48, 48),
    "statue": ("TilesetHouse.png", 48, 240, 32, 32),
    "pond": ("TilesetWater.png", 0, 96, 48, 48),
    "fire-pit": ("tileset_camp.png", 161, 50, 30, 28),
    "training-post": ("TilesetElement.png", 1, 81, 14, 30),
    "potted-plant": ("TilesetElement.png", 0, 120, 15, 24),
    "bridge": ("TilesetHouse.png", 144, 240, 48, 48),
}

# The Monk's headband pixels (dark, light). Recoloured per belt so the headband shows your rank.
HEADBAND = ((52, 90, 82), (86, 134, 76))

# Belt colours for palette-swapping the character's belt pixels.
BELTS = {
    "white": (236, 236, 236), "yellow": (242, 208, 36), "orange": (240, 138, 36), "green": (43, 168, 74),
    "blue": (46, 125, 225), "purple": (142, 68, 173), "brown": (138, 90, 43), "black": (30, 30, 34),
}


def crop(sheet: str, x: int, y: int, w: int, h: int) -> Image.Image:
    img = Image.open(TILES / sheet).convert("RGBA")
    return img.crop((x, y, x + w, y + h))


def knock_out_edges(img: Image.Image, tolerance: int = 40) -> Image.Image:
    """Make the tile's own ground transparent: flood-fill from the corners over similar colours.
    Some pack tiles (the pond) carry a square of grass that clashes with our ground."""
    out = img.copy()
    px = out.load()
    w, h = out.size
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    ref = px[0, 0]
    close = lambda c: c[3] > 0 and sum(abs(c[i] - ref[i]) for i in range(3)) <= tolerance
    stack = [s for s in seeds if close(px[s])]
    seen = set(stack)
    while stack:
        x, y = stack.pop()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and close(px[nx, ny]):
                seen.add((nx, ny))
                stack.append((nx, ny))
    return out


def character() -> Image.Image:
    """First frame (facing down) of the pack's Monk sprite sheet: 16x16 cells, 4 columns."""
    return monk_sheet().crop((0, 0, 16, 16))


def monk_sheet() -> Image.Image:
    return Image.open(PACK / "Actor" / "Character" / "Monk" / "SpriteSheet.png").convert("RGBA")


def shade(rgb: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(c * factor))) for c in rgb)


def belt_sheet(colour: tuple[int, int, int]) -> Image.Image:
    """Palette swap: the headband's dark/light greens become the belt colour's dark/light shades."""
    sheet = monk_sheet()
    swap = {HEADBAND[0]: shade(colour, 0.7), HEADBAND[1]: colour}
    px = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in swap:
                px[x, y] = (*swap[(r, g, b)], a)
    return sheet


def grass_ground(cols: int, rows: int) -> Image.Image:
    """Flat two-tone grass so the mock reads without autotiling."""
    ground = Image.new("RGBA", (cols * 16, rows * 16))
    for cx in range(cols):
        for cy in range(rows):
            colour = (110, 158, 92, 255) if (cx + cy) % 2 else (100, 148, 84, 255)
            ground.paste(colour, (cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16))
    return ground


def scene(items: list[tuple[str, int, int]], sprites: dict[str, Image.Image], cols: int = 10, rows: int = 8) -> Image.Image:
    canvas = grass_ground(cols, rows)
    # Draw back to front by bottom edge; things that live inside water (koi) always draw last.
    for key, x, y in sorted(items, key=lambda t: (t[0] == "koi", t[2] + sprites[t[0]].height)):
        canvas.alpha_composite(sprites[key], (x, y))
    return canvas


def main() -> int:
    if not TILES.exists():
        print(f"Pack not found at {PACK}", file=sys.stderr)
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    sprites = {key: crop(*spec) for key, spec in SPRITES.items()}
    sprites["pond"] = knock_out_edges(sprites["pond"])
    for key, img in sprites.items():
        img.save(OUT / f"{key}.png")
    koi = Image.open(PACK / "Actor" / "Animal" / "Fish" / "SpriteSheetRed.png").convert("RGBA").crop((0, 0, 16, 16))
    sprites["koi"] = koi
    koi.save(OUT / "koi.png")
    hero = character()
    sprites["hero"] = hero
    hero.save(OUT / "hero.png")
    belts = []
    for name, colour in BELTS.items():
        sheet = belt_sheet(colour)
        sheet.save(OUT / f"belt-{name}.png")  # full animation sheet per belt
        belts.append(sheet.crop((0, 0, 16, 16)))
    row = Image.new("RGBA", (len(belts) * 20, 16), (24, 28, 44, 255))
    for i, frame in enumerate(belts):
        row.alpha_composite(frame, (i * 20 + 2, 0))
    row.resize((row.width * 6, row.height * 6), Image.NEAREST).save(PREVIEW / "belts.png")

    bare = [("grass-tuft", 40, 60), ("hero", 72, 64), ("stump", 100, 72), ("fire-pit", 56, 80)]
    growing = bare + [("bamboo", 8, 16), ("pine", 120, 8), ("sunflower", 30, 100), ("boulder", 116, 88), ("tent", 20, 50)]
    thriving = [("dojo", 48, 0), ("dojo-sign", 64, 40), ("torii", 112, 70), ("cherry", 0, 4), ("maple", 116, 0),
                ("bamboo", 8, 64), ("bonsai", 40, 84), ("pink-bush", 132, 92), ("statue", 2, 96), ("hero", 76, 74),
                ("sunflower", 96, 104), ("red-flower", 60, 108), ("grass-tuft", 140, 60), ("pond", 100, 44), ("koi", 116, 60),
                ("fire-pit", 62, 96), ("training-post", 30, 56)]
    frames = [scene(s, sprites) for s in (bare, growing, thriving)]
    gap = 8
    strip = Image.new("RGBA", (sum(f.width for f in frames) + gap * 2, frames[0].height), (24, 28, 44, 255))
    x = 0
    for frame in frames:
        strip.alpha_composite(frame, (x, 0))
        x += frame.width + gap
    strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST).save(PREVIEW / "garden-mock.png")
    print(f"{len(sprites)} sprites -> {OUT}; preview -> {PREVIEW / 'garden-mock.png'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
