# cellmap v2: the hub between the editor and the engines

**Next step: `CELLMAP_V3.md` (slopes, stacked maps, map packs; 16 Nov 2026). Nothing below changes.**

Saturday, November 14, 2026. Written by Claude (Fable) from the owner's two notes of this morning
(11:40 on the example map, 11:57 on the BitEditor) and Opus's brief. Status of each part is in
section 9. Version 1 is described in `README.md`; every v1 file still reads.

## 1. The words

| Word | Meaning |
|---|---|
| cell | one square of the grid |
| design | a byte 0-255: which glyph of the map's 1-bit font is drawn on the cell |
| tag | one character: what the cell is; its **effect** is what it does to an actor |
| height unit (**hu**) | one hundredth of a standard hallway: 100 hu = `wallH` engine units |
| floor (grey) | 0-255 hu: where the ground is. 0 = empty space, 1 = a flat plane, 100 = a full wall |
| ceiling (grey) | 0-255 hu: where the roof's underside is. 0 = no roof (open sky) |
| red | 0-255 hu dug DOWN under the floor (a pit, a pool) |
| green | 0-255: a block whose top is 255 + green hu (the green band, above the white). Since 18 Nov 2026, section 3b |
| blue | 0-255: a block whose top is 510 + blue hu (the blue band, above the green) |
| from | per cell: 1 From Floor (solid under its block), 2 From Ceiling (solid from the map's top down), 3 both. Section 3b |
| link | a trigger cell pointing at target cells |
| object | a thing standing in the map with a position and a facing |
| stack | another map laid over this one at a base height |

## 2. The decision: five numbers a cell, not one colour

**Confirmed by the owner, 2026-11-14:** "your five numbers in cell sounds fine".

The owner's note describes heights as colours: grey for the base floor and ceiling, red going
down under the floor, green above the ceiling, blue above that. One colour cannot hold all of
it: a grey IS red = green = blue, so a pixel that is "grey 100 with red 40" is no longer a grey,
and floor and ceiling need a grey each. **So a cell stores five separate numbers (floor,
ceiling, red, green, blue) and the editor MIXES them into two colours to show them**: the floor
colour (floor grey, tinted red where a pit is dug) and the ceiling colour (ceiling grey, tinted
green and blue where something is built above). Nothing is lost going to the screen and back,
because the screen is never read back: the numbers are the map, the colours are a view of them.

What the owner sees is exactly his description: the Floor tool shows each glyph in the floor
colour on a background of the ceiling colour; the Ceiling tool flips the two.

The file keeps any value 0-255; the editor's swatches go in **steps of 10** (0, 1, 10, 20 ... 250,
255), the owner's "steps of 10% of a standard cell height".

## 3. The height model: one column a cell

Heights are in hu, measured up from the map's zero (`base`). `wallH` engine units = 100 hu.
The heroes are about 83 hu tall, so a standard hallway (100) is 20% taller than they are.

```
            ......  slab top      = slab bottom + slab (10)      a cloud, a bridge: you can stand on it
            ::::::  slab bottom   = top of the column + BLUE     (only when blue > 0)
               ^    blue hu of open air
            ######  roof top      = ceiling + GREEN              (green 0: the roof is a thin sheet)
            ------  roof bottom   = CEILING                      (ceiling 0: no roof at all)
               ^    air you walk in: needs head (83) hu
   ~~~~~~~  ______  ground        = FLOOR                        (water tags fill a pit up to here)
            |    |  pit           RED hu deep
            |____|  pit bottom    = FLOOR - RED                  <- what you walk on
```

- **floor 0**: nothing. No geometry, no walking (the owner: "empty space").
- **floor 1**: a flat plane at the map's zero. Floor n: the ground stands n hu high. 100 with
  no ceiling is a full wall block; 20 is a dais you step onto; 255 is a tall block.
- **red** digs down from the floor: the walking surface is `floor - red`. With a water tag
  (`w` shallow, `}` deep) the water's surface is drawn at the floor level and the actor wades
  or swims on the bottom; with no water tag it is a dry pit.
- **ceiling** is the underside of a roof. A cell with ceiling at or below its ground is solid
  to the roof (a wall inside a building).
- **green** builds up: on top of the roof when there is one (a thick roof, a second storey's
  mass), otherwise on top of the floor (a wall or tower taller than the greys reach:
  floor 255 + green 255 = 510 hu, five hallways high).
- **blue** is a gap of open air above everything else, then a floating slab `slab` hu thick.
  The slab is solid: clouds over a courtyard, a bridge over a pool. You walk under it and, if
  you can get up there, on it.

Walking (the same rule in both engines, `CellMap.Walk`): every cell offers up to three **levels**
(the ground; the roof's top; the slab's top). An actor at height y can move onto a level whose top is no more
than `step` (30 hu: a 20 step with a raised glyph on it still passes) above y, with at least `head` (83 hu) of air above it; it may drop any
distance. Then the tag speaks: effects `block` and `locked` stop it whatever the heights say; the
others (`swim`, `damage`, `goal` ...) are handed to the game.

### 3b. Colour bands and From Floor / From Ceiling, cell by cell (the owner, 2026-11-18)
**This replaces the green and blue rules of the drawing above** (green is no longer a thick roof
or a tower on the grey; blue is no longer measured from the column's top).

The owner: "Green height should start at the height of White's highest. If White16 = 10 feet,
then Green1 would be 10 feet, and Green16 would be 20 feet, and Blue would start at 20 feet and
Blue16 would be 30 feet." And: "The height settings should have a From Floor toggle and From
Ceiling toggle (both can be on or off) ... floating platforms, which may be desired, or not."
And: "The extrusions should be cell by cell, that's what the whole height painting is for."

**Bands.** White (the greys) is 0-255 hu. A **green** value g puts a block whose top is
`255 + g` hu, `slab` (10) thick; a **blue** value b a block whose top is `510 + b`. One cell may
hold both (green under blue). The grey ceiling is a thin roof at `ceiling` hu.

**From, per cell** (the `[from]` layer, 0-3; left out of the file when every cell is 0):

| from | What the cell does | Column (`CellMap.Column` / `column`) |
|---|---|---|
| 0 | both off: its blocks float, open air under them (every old map) | `ground,rb,rt,b1,t1[,b2,t2]` |
| 1 From Floor | fills the cell solid under its block: one pillar from the ground up to its highest block's top | `top,,,,` |
| 2 From Ceiling | solid from the **map's top** down to its roof (when it has a grey ceiling), else down to its lowest block | `ground,rb,top,,` or `ground,,,b1,top` |
| 3 both | solid from the floor to the map's top | `top,,,,` |

- A cell with no block (and, for From Ceiling, no roof) is not changed by its flags.
- A block that touches what is under it (the ground, the roof, the green block) joins it.
- **The map's top** is the map's own `top` (hu) when it names one, else **765**, the top of the
  blue band (`CellMap.Top` / `map_top`, `kTop` / `TOP`). The BitEditor shows it in the Heights
  tool row ("top 765"); a click there changes it (one undo).
- Walking, levels, picks, drawn lines (`LevelSegments`: every block's edges and uprights, class
  `sky`; a green pillar's sides class `green`), xt3d boxes and the checker all read the column.
- The sample `wizard_pool` now builds its tower this way: walls green 200 From Floor (455),
  rooms and the door roofed From Ceiling under `top 455`; the clouds are green 10 (top 265).
- Maps with green or blue made before 18 Nov change their look (green no longer stands on the
  grey). Only test maps had any; `16x16_Cropped_wizard_pool` is one.
- Tests: `tests/py_fill_test.py`, `tests/lc_fill_test.txt` (same columns, lines and walks in both
  libraries), `tests/lc_heights_from_test.txt` (the editor: painting, undo, top, Extrude Glyphs,
  save and open; run it in a copy, ISSUES 0007).

### Version 1 heights
v1 had one number 0-35 where 9 was a full wall. Read as: 0 -> floor 1 (0 for the void tag
`space`), n -> n x 100 / 9 rounded (9 -> 100, 1 -> 11, 3 -> 33), at most 255. Old code that
asks for `heights` gets the floor converted back (`CellMap.Get(map, "heights", col, row)`).

## 4. The glyphs: low relief you can step on

The owner (11:40): "maybe make them shorter than the walls, something they can step on, they
can be walking around a big computer screen laying flat instead of a maze."

Every cell's design glyph is 16 x 16 bits. On a cell that is not a full wall or a pit, the lit bits are
raised `relief` hu (default 6: well under a step) above the cell's ground. So the whole map,
seen from above, is its 1-bit picture: a screen laid flat, its characters embossed, walked on.
Walls keep their glyph as the editor's picture of them and stand as plain blocks. Codes 32
(space) and 46 (the floor dot) are never raised. `relief 0` turns it off.

### 4b. `extrude glyph`: the glyph stands as the solid (the owner, 2026-11-15)
"Setting the height of the object creates a height preview cube, but doesn't extrude the shape."
A map whose `[map]` section says `extrude	glyph` raises the **glyph**, not the whole cell: in a
cell higher than the flat floor (ground over 1), not dug, whose glyph has lit bits (never 32 or
46), the lit bits stand as a prism from the floor (1) up to the cell's ground, and the rest of
the cell is flat floor at 1. Walls drawn with the Aquarius line pieces become thin walls with
real corners; a letter with a height is a letter-shaped pillar.
- Segments: the cell is drawn as a floor cell; the glyph's outline at the cell's height and one
  upright under each outline corner, in the cell's class (`wall`, `green`).
- Standing: on a lit bit you stand at the cell's height (or are stopped by it); beside it, on
  the floor. A tag whose effect is `block` blocks only the lit bits; `locked` still locks the cell.
- No low relief in such a cell (the prism replaces it). Without a font nothing is shaped.
- A map that says nothing (every map before today) is `extrude cell`: unchanged.
- `CellMap.Shaped(map, font, col, row)` / `cellmap.shaped(m, font, r, c)`; BitEditor: Mesh >
  Extrude: Whole Cell / Glyph Shape. Tested equal in Python and LiveCode (segments and walks).

## 5. The file (`.cellmap`, UTF-8 text, version 2)

```
# cellmap 2 - LIB_BIT/editor (format: editor/CELLMAP_V2.md)
[map]
name    wizard_pool          cols 24      rows 18       (tab between key and value, one a line)
cell    76                   engine units a cell
wallH   62                   engine units for 100 hu (a hero of 52 units x 1.2)
unitPx  16      font Aquarius      tags tags_default      version 2
base    0                    this map's zero, hu above the world's
step 30   head 83   relief 6   slab 10        (all optional; these are the defaults)
[design]  or  [design hex]   as version 1
[tags]                       as version 1
[floor]                      one row a line, one number 0-255 a cell, right-aligned in 3, a space between
  1   1 100 100 ...
[ceiling]                    the same
[red] [green] [blue]         the same; each is left out when it is all zeros
[links]                      from <tab> type <tab> to <tab> note
5,9	pad	12,3 12,4	the pad opens both door cells
[objects]                    id <tab> kind <tab> col,row <tab> facing <tab> above <tab> props
orb1	ball	6.5,7	90	0	sides=16
[stack]                      file <tab> base <tab> col,row
tower_top.cellmap	200	15,3
[tagdefs]                    as version 1
```

- **links**: `from` and each `to` are `col,row`; a target may also be `@id` (an object). Types
  follow the Tomb Raider editor and Forge: `pad` (stepping on it), `heavy` (anything but the
  player), `switch`, `key`, `pickup`, `anti` (turns its targets off), `teleport` (to = where).
- **objects**: `col,row` may have decimals (6.5 = on the line between columns 6 and 7; whole
  numbers are cell centres). `facing` in degrees, 0 = north (up the map), 90 = east. `above` =
  hu above the cell's walking surface. `props` = `key=value` pairs separated by `;`.
- **stack**: another cellmap laid over this one: its zero is `base` hu above this map's zero, its
  cell 1,1 sits on this map's `col,row`. A room above a room is two small maps, not one tall one.
- The reader takes version 1 files as they are (and writes them back the same); `CellMap.Upgrade`
  (LiveCode) / `upgrade()` (Python) turns one into version 2. The BitEditor upgrades on open.

In LiveCode: `tMap["floor"|"ceiling"|"red"|"green"|"blue"][row][col]`,
`tMap["links"][n]["from"|"type"|"to"|"note"]`,
`tMap["objects"][n]["id"|"kind"|"at"|"facing"|"above"|"props"]`,
`tMap["stack"][n]["file"|"base"|"at"]`. In Python the same names (lists of rows; lists of dicts).

## 6. How a cellmap becomes a level

One pure function on each side (`CellMap.LevelSegments` / `level_segments`) turns the five
layers into **line segments with a class**, in map space: x east, y up, z south, engine units,
the map centred on 0,0:

    x1,y1,z1,x2,y2,z2,class

| Class | What it draws | Suggested colour |
|---|---|---|
| `floor` | the grid of every ground cell at its own height | dim teal |
| `wall` | edges where neighbours' grounds differ, and one upright at each corner between them | blue |
| `pit` | the same, for cells dug with red | red |
| `water` | the water sheet at floor level over a pit with a water tag (outline + one diagonal) | cyan |
| `ceiling` | roof undersides: outlines where neighbours differ, uprights for thick roofs | grey |
| `green` | everything built above 100 hu by green (tower tops, thick roofs) | green |
| `sky` | the floating slabs (blue): top and bottom outlines, uprights | light blue |
| `relief` | the glyph outlines, raised | white |

How it is built (the rules are the format; any engine can follow them):
1. **Grounds.** Each cell with floor > 0 has ground `g = floor - red` (or `floor + green` when it
   has green and no ceiling). For each cell edge: a line at this cell's `g`; if the neighbour's
   ground differs or is empty, the edge is class `wall` (or `pit` / `green`), otherwise `floor`,
   drawn once.
2. **Uprights.** At each grid corner, one vertical line from the lowest to the highest ground of
   the (up to four) cells that meet there, when they differ. That is the wall between heights.
3. **Roofs.** The same two rules for ceiling bottoms (`ceiling`) and roof tops (`ceiling + green`).
4. **Slabs.** A box outline `slab` hu thick at `top + blue`, edges shared by equal slabs left out.
5. **Water.** For a dug cell with a water tag: its outline at floor level where the neighbour is
   not the same water, and one diagonal so the sheet reads as a surface.
6. **Relief.** For each cell under 100 hu, not dug (red 0), whose glyph is not blank: the outline of the lit bits
   (LIB_MAP's block edges on the 16 x 16 grid) at `g + relief`.

### In Vibecode3D (vector wireframes)
The engine draws lines, so the segments ARE the level: one wire mesh per class
(`Mesh.New`, `Mesh.AddVertex x, -y, z` because up is -Y there, `Mesh.AddLine`), each spawned once
at 0,0,0 in its colour. Collision does not use the engine at all: the game calls
`CellMap.Walk(map, x, z, y, dx, dz, radius)` each step and gets back where the actor stands
(sliding along walls), its new height and the tag effect under its feet. Example card:
`LIB_EDITOR/examples/E13_WalkTheMap`.

### In xt3d (raylib)
Same data, two ways, both from the same library:
- **Wire look** (matches Vibecode3D): draw each segment with the bridge's 3D line call, a colour
  per class. `y` is already up in raylib, so no flip.
- **Solid look**: `CellMap.LevelBoxes` / `level_boxes` gives one box a column part instead
  (`x,y,z,width,height,depth,class`: ground block, roof block, slab, water sheet); draw each as a
  cube, textured later with the cell's glyph (the 1-bit picture is already the texture atlas:
  16 x 16 a code). Collision is the same `CellMap.Walk`: one rule, two engines.

## 7. What a game reads from a cell
`CellMap.Levels(map, col, row)`: the heights an actor can stand on there and the air above each.
`CellMap.GroundAt(map, x, z)`: the ground under a point, glyph relief included.
`CellMap.Walk(...)`: movement as above. `CellMap.TagInfo(..., "effect")`: what the cell does.
`CellMap.CellX / CellZ / CellAt`: between cells and engine units.

## 8. The editor (BitEditor)
A **Heights** tab beside 1bit and Cells: the map's glyphs in two colours a cell.
- Tool **Floor**: glyph = the floor colour, background = the ceiling colour. Tool **Ceiling**:
  flipped. One click on the tool flips the whole map: where the floors are, then where the roofs
  are, at a glance.
- Swatches: a grey row (0, 1, 10 ... 250, 255), a red row, a green row, a blue row. Pick one,
  paint cells. A grey paints the floor or the ceiling (whichever tool is on); red, green and blue
  paint their own layer whatever the tool.
- Colours shown: grey n is drawn as brightness 40 + n x 215 / 255 (so 1 is visibly not 0, which
  is black); a cell with red shows its floor in red (deeper = brighter); with green or blue its
  ceiling colour takes those channels.
- Right-click picks up a cell's value for the layer being painted.
- The view always opens showing the glyphs (the owner, 2026-11-14: "so the user doesn't get lost
  between general design and detail design"). Blocks (squares instead of glyphs) is an optional
  button, never the default.
- The tool row: Floor, Ceiling, Blocks, then **From Floor** and **From Ceiling** (section 3b),
  the map's **top**, and **Extrude Glyphs**. A click on a From box turns it on or off and makes
  the two boxes the brush: a click on a cell gives it what they say (one undo a stroke); a
  swatch is the brush again. On the map a From Floor cell has an orange bar along its bottom, a
  From Ceiling cell a sky-blue bar along its top; the hover line says FROM FLOOR / FROM CEILING.
- **Extrude Glyphs** (Extrude Glyphs to Heights) is a second step, off while heights are
  painted: on, a raised cell lifts its glyph's shape instead of the whole cell (the same as Mesh >
  Extrude: Glyph Shape, section 4b; saved with the map).

## 9. Status (2026-11-14)
| Part | State |
|---|---|
| Format, Python and LiveCode readers/writers, v1 -> v2, round trips both ways | done, tested (`tests/`) |
| Level segments, levels, ground, walk: Python and LiveCode, same numbers | done, tested |
| BitEditor Heights tab | done, tested headless with pixel checks; the owner has not seen it yet |
| Sample map `maps/wizard_pool.cellmap` (pool, dais, tower, clouds, maze corner, screen of glyphs) | done |
| Vibecode3D card `LIB_EDITOR/examples/E13_WalkTheMap` | done: headless test of 11 scenes passes; ran in the real engine at 30 frames a second with all 1562 lines, drawn pixels counted per colour from six viewpoints |
| The same card in the xt3d bench | not started |
| Boxes for xt3d, links and objects acting in a game | format only: read and written, not yet used |
| Stacked maps in the walker | done in version 3 (`CELLMAP_V3.md`, 2026-11-16) |
