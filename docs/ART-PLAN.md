# Art plan: replacing the emoji with Ninja Adventure pixel art

Status 2026-10-16: the pack is downloaded and extracted (`art/vendor/ninja-adventure/`, CC0 1.0, LICENSE.txt
included, 1,915 PNGs). 21 garden sprites are already cut out by `art/tools/build_sprites.py`, and a
3-state sample garden is rendered at `art/preview/garden-mock.png` (bare, then growing, then thriving).

## 1. Item map: every shop item gets a real sprite

| Catalog item (MasteryCore) | Pack sprite | Source | Status |
|---|---|---|---|
| Fire Pit (starter) | stone fire ring with logs | tileset_camp.png 161,50 | **done** (animated flame: FX later) |
| Raked Gravel / Moss | floor tiles | TilesetFloor / TilesetFloorDetail | to crop (ground layer) |
| Stepping Stone | small rocks | TilesetNature (rock row) | to crop |
| Boulder | grey boulder | TilesetNature 256,128 | **done** |
| Bamboo | bamboo stalk | TilesetNature 176,128 | **done** |
| Black Pine | pine | TilesetNature 32,0 | **done** |
| Bonsai | twisted tree | TilesetNature 96,0 | **done** |
| Red Maple | autumn tree | TilesetNature 144,288 | **done** |
| Cherry Blossom | pink tree | TilesetNature 0,288 | **done** |
| Stone Lantern | stone statue / column | TilesetHouse (stone set) | to crop or **draw** (no true tōrō in pack) |
| Koi Pond | grass-edged pond + red/white/yellow fish | TilesetWater 0,96 + Actor/Animal/Fish | **done** (pond edge needs autotile cleanup) |
| Arched Bridge | wooden planks | TilesetHouse 144,240 | cropped, needs a proper bridge shape |
| Training Post | wooden post figure | TilesetElement 1,81 | **done** |
| Tent | tent | TilesetHouse 0,112 | **done** |
| Torii Gate | red torii | TilesetHouse 0,80 | **done** |
| Dojo | red-roof hall + "DOJO" sign | TilesetHouse 192,0 + 64,64 | **done** |
| Pagoda | none | n/a | **draw** (stack 3 roofs from TilesetHouse) |
| Statue (new) | meditating stone figure | TilesetHouse 48,240 | **done** |
| Flowers / tufts (decor, drops) | sunflower, red flower, tufts | TilesetNature | **done** |

## 2. Game states the art has to show (approved v0.2 design)

| State | How (all procedural, no new art needed) |
|---|---|
| **Habit strength** (wilted / healthy / blooming) | Each habit owns a plant in the garden. Wilted = palette-shift toward brown + droop (1px down). Healthy = as drawn. Blooming = add the pack's animated flower overlay (`Backgrounds/Animated/Flower`). |
| **Energy low** | Already coded: the garden's saturation follows energy (`DojoView`). Add the pack's falling-leaf particle (`FX/Particle/Leaf.png`) under 40 energy. |
| **Perfect Day** | Fireflies = `FX/Particle/Spark.png` at night. Lanterns get a warm glow sprite. |
| **Focused Strike / level-up** | `FX/Magic/Boost` or `Spark` burst + `Audio/Jingles/LevelUp1.wav` / `Bonus/PowerUp1.wav`. |
| **Drops** | Seed pop = `Items/Resource/Grass.png` + `Bonus/Coin.wav`. Koi egg = fish sprite. |
| **Belt rank** | Palette-swap the hero's sash pixels into 8 belt colours (script). Base hero = `Actor/Character/Monk` (also `Master`, `NinjaGray` etc. if Conor prefers). |
| **Focus session** | Hero sitting by the animated fire (`FX/Elemental` fire / camp tiles). |

## 3. Build steps (in order)

1. ~~Cut the remaining sprites~~ fire pit, training post, potted plant and bridge planks are **done**. Still left: gravel/moss ground, stepping stone.
2. **Ground**: replace the flat two-tone grass with the pack's grass autotile (`TilesetFloor`), and fix the pond
   edge (render it with the water autotile instead of a single tile).
3. **Draw 2 missing pieces** (16 px grid, pack palette only): stone lantern and pagoda (stacked roofs).
4. ~~Belt hero~~ **Done**: `belt-<colour>.png` × 8 (full animation sheets); the headband and sash take the belt colour. Preview: `art/preview/belts.png`.
5. **Asset catalog**: export every sprite at 1x into `App/Resources/Assets.xcassets/Sprites/` and render it in
   SwiftUI with `.interpolation(.none)` at an integer scale (4x = 64 pt tiles).
6. **Swap the renderer**: `WorldView` moves from isometric emoji to a **top-down** sprite grid (the pack's view),
   and `ItemArt.glyph` becomes `ItemArt.sprite`.
7. **Juice**: sounds from `Audio/` (coin, power-up, level-up) behind the existing sound toggle, plus particles.
8. **Credit** pixel-boy in Settings → About (not required by CC0, but right).

## 4. Other pixel packs: should we grab more?

**Recommendation: not now.** Ninja Adventure already covers about 90% of the catalog. Mixing styles looks
worse than drawing 2 missing pieces ourselves. If we expand later:

| Pack | License | Fits? | Use for |
|---|---|---|---|
| [Free Pixel Plants 16×16 (Danaida)](https://danaida.itch.io/free-pixel-plants-16x16) | CC0 (author's reply on page) | Close style | Extra plant variety for habit plants |
| [16×16 Tiny Garden free pack (kathychow)](https://kathychow.itch.io/16x16-tiny-garden-free-pack) | Commercial use OK, no redistribution/AI | Close | Garden paths, bridges, flower beds |
| Kenney Tiny Town / Tiny Dungeon | CC0 | Different (flatter) style | Not recommended: style clash |

Before adding any of these, check its palette against Ninja Adventure. If the colours fight, don't use it.
