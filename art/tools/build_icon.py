"""App icon: the hero under a torii on the garden grass, 64x64 pixel art scaled 16x to 1024 (opaque, as Apple requires)."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "App/Resources/Assets.xcassets/Sprites"
OUT = ROOT / "App/Resources/Assets.xcassets/AppIcon.appiconset"
NIGHT = (28, 36, 64)   # Theme night, as the widgets use


def sprite(name):
    return Image.open(SPRITES / f"{name}.imageset/{name}.png").convert("RGBA")


def build():
    canvas = Image.new("RGBA", (64, 64), NIGHT + (255,))
    for x in range(0, 64, 16):
        for y in (40, 56):
            canvas.alpha_composite(sprite(f"ground-grass-{(x // 16 + y) % 4}"), (x, y))
    canvas.alpha_composite(sprite("torii"), (8, 12))
    canvas.alpha_composite(sprite("lantern"), (2, 30))
    canvas.alpha_composite(sprite("lantern"), (46, 30))
    canvas.alpha_composite(sprite("hero-black"), (24, 34))
    icon = canvas.convert("RGB").resize((1024, 1024), Image.NEAREST)
    icon.save(OUT / "icon-1024.png")
    (OUT / "Contents.json").write_text(
        '{ "images" : [ { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],'
        ' "info" : { "author" : "xcode", "version" : 1 } }\n')
    return icon


if __name__ == "__main__":
    im = build()
    assert im.size == (1024, 1024) and im.mode == "RGB"
    print("icon written")
