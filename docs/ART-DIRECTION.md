# Art direction: pixel dojo garden

Owner, 2026-10-16: "our pixels and graphics need more work, they can't just be emojis." Agreed. The garden
is the main reward (Monke's island proves it), so it has to look earned.

## Direction: 16×16 top-down pixel art, Japanese mountain dojo

- **Why pixel art**: it reads as "a game" instantly, scales crisply on iPhone at 3x, 4x and 5x, and one
  person can extend it consistently. Monke's hand-drawn style needs a dedicated illustrator.
- **Base asset pack**: **Ninja Adventure** by pixel-boy, **CC0 1.0** (public domain, commercial use OK, no
  attribution required, but we credit it anyway). It has 50+ animated characters, Japanese village tilesets (floor
  autotiles, trees, houses, fences, water), 60+ items, UI, 30+ effects, 100+ sounds and 37 music tracks, all at
  16×16. https://pixel-boy.itch.io/ninja-adventure-asset-pack (updated 2026-03-29).
  - Scripted download fails (itch.io key check). **Owner action**: click "Download Now", choose "No thanks, just
    take me to the downloads", download `Ninja Adventure - Asset Pack.zip`, and save it to
    `D:/projects/conor-mastery/art/vendor/`.
  - The GitHub repo pixel-boy/NinjaAdventure is only the Godot demo (98 PNGs), not the full pack.
- **Rejected**: Habitica's sprites (CC-BY-SA, and they would look like Habitica). Monke's art (copyrighted).
  Emoji (owner veto).

## How it renders

- SwiftUI `Canvas` (or SpriteKit) with `.interpolation(.none)` so pixels stay sharp. Draw at an integer scale
  (16 px × 4 = 64 pt tiles on most iPhones).
- Switch from isometric to **top-down 3/4 view**, which is the pack's perspective, on a 9×9 to 13×13 garden grid.
- Sprite sheets live in an asset catalog. The item id maps to a sheet rect in one table (`ItemArt`), replacing the emoji.

## Game-feel the art must carry

| State | Visual |
|---|---|
| Habit strength (Habitica value drift) | Each habit has a plant in the garden that is wilted (red-brown), healthy (green) or blooming (with flowers). |
| Energy low (missed habits) | Colour grade shifts desaturated and grey and leaves fall. The garden recovers on a Perfect Day. |
| Perfect Day | Lanterns light up at night and fireflies appear. |
| Level-up / belt | The character's belt colour changes and a short particle burst plays from the pack's FX. |
| Focus session | The character sits and meditates by the fire, with an animated flame. |
| Drops (seeds, koi eggs) | A small pop-up sprite and a sound from the pack. |

## Our own additions (original, made to match the pack's palette)

Belt-coloured gi variants of the main character, a dojo building if the pack lacks one, a koi pond, a torii gate
and bonsai. These are drawn at 16×16 in Aseprite or Piskel, limited to the pack's palette.

## Not in v0.1

No hand-painted illustration and no 3D. Commissioning a custom character sheet stays an option for later
(an itch.io artist commission is roughly $100–300).
