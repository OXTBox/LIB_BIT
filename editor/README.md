# LIB_BIT/editor: the 1-bit to 3D editor

A sub-project of LIB_BIT (owner, 2026-11-14): draw 1-bit glyphs, paint them into a map grid,
tag the cells, set their heights, and (later) see the result in Vibecode3D and xt3d. It does not
touch the Vibecode3D or xt3d main stacks yet, so it can change freely. The owner's prototype
and his notes: `../docs/1BIT_TO_3D_UTILITY.md`.

| Folder | What |
|---|---|
| `data/tags_default.txt` | the 256 tags: code, char, name, colour, solid, height, group |
| `fonts/` | 1-bit fonts: BitFontMaker2 `.json` (originals) and `.font.txt` (what the editor reads) |
| `maps/` | cellmaps; `amazing_couple.cellmap` = Amazing Couple's maze with its defaults |
| `python/cellmap.py` | read, write, check, show cellmaps outside LiveCode; makes the tag table and the example |
| `livecode/lib_cellmap.livecodescript` | the same in LiveCode: a cellmap as a keyed array (pure handlers) |
| `tests/lc_roundtrip.txt` | LiveCode test: `~/projects/LIB_MCP/tools/lcmcp --standalone run - < tests/lc_roundtrip.txt` |

## Version 2 (2026-11-14): read `CELLMAP_V2.md`
Heights are now five numbers a cell (floor, ceiling, red, green, blue; 100 = a full hallway), with
links, objects and stacked maps, and one rule set that turns a map into a level for both engines.
Version 1 files (below) still read; the BitEditor opens them as version 2 and saves version 2.
- Sample: `maps/wizard_pool.cellmap` (pool, dais, wizard's tower, clouds, a maze corner, a screen
  of glyphs to walk on); made by `python3 -I python/cellmap.py sample`.
- **Heights tab** in the BitEditor: Floor / Ceiling tools flip which colour the glyphs take; swatch
  rows grey, red, green, blue in steps of 10; right-click picks a cell's value; Blocks shows
  squares instead of glyphs (a floor dot is small: Blocks reads better on open floors).
- Tests: `python3 -I tests/py_v2_test.py` first (it writes what LiveCode is compared with), then
  `lcmcp --standalone run - < tests/lc_v2_test.txt` and `... < tests/lc_editor_test.txt`.
- Walk it in 3D: `LIB_EDITOR/examples/E13_WalkTheMap`.

## The owner's notes of 2026-11-15 (layout 2)
- **Brush strokes.** Press and drag on the drawing board or the 2D map paints like a brush: the
  mouse is followed every 15 ms and every cell on the line since the last look is painted, so a
  fast drag leaves no gaps. The 2D map follows at once; the glyph list and the 3D preview catch
  up in a pause or at release.
- **Mirrors.** Bit > Mirror H While Drawing (left and right) and Mirror V While Drawing (top and
  bottom), both can be on, each shows a guide line on the board; Mirror H Now / Mirror V Now copy
  one half onto the other once.
- **Undo.** Edit > Undo (Ctrl+Z), Redo (Ctrl+Y or Ctrl+Shift+Z). Every changed bit or cell is its
  own numbered line of the change history, with its time; one press of the mouse, or one menu
  command (Clear, Auto Walls, Resize ...), is one undo. Edit > Export Change History writes
  `maps/<name>_history.txt` (a recorded path: for path and animation systems later). The history
  starts again when a map is opened.
- **Drawn tabs.** The native tab control is light grey on white whatever its colours, so the
  tabs are drawn: `Theme.TabStrip` in LIB_THEME (one locked field a tab).
- **From Floor / From Ceiling** (Heights tab, two boxes right of the Blocks button; the owner's
  note of 18 Nov 2026). How we read the note: a blue height puts a block up in the air. With
  both boxes off it floats, as before (you can walk under it). **From Floor** fills everything
  under it down to the floor, so it becomes a solid pillar you cannot walk under. **From
  Ceiling** stretches it up to the top of the map (the highest thing on the map, unless the map
  names its own `top`). Both on: the cell is solid from the floor to the top. The choice is for
  the whole map and is saved with it; an old map opens with both off and looks as it always did.
  Green does not float yet, so the boxes only change blue for now. `CELLMAP_V2.md` section 3b.
- **Extrude: Glyph Shape** (Mesh menu; saved with the map as `extrude glyph`): a height raises
  the cell's glyph, not the whole cell. `CELLMAP_V2.md` section 4b.
- **Painting in the 3D preview.** The left button paints there with the same brush as on the
  2D map (same undo); Alt + click picks up. While the RIGHT button is held it is camera mode:
  drag turns, W A S D move forward / left / back / right, R F up / down, Shift + drag zooms.
  `CellMap.Pick` (and `cellmap.pick`) finds the cell under a ray.
- **Heights by dragging in 3D and the Clutter brush:** planned in `PLAN_3D_PAINT_AND_CLUTTER.md`.
- **Tests with no window:** `python3 -I tests/run_headless.py tests/lc_v2_test.txt`, and in a
  copy of the editor folder (they rebuild the stack) `--root COPY tests/lc_feedback_1115_test.txt
  tests/lc_layout2_test.txt`. The LiveCode server has no screen: what a real window draws (the
  tabs' look, the guide lines, the feel of a drag) is the owner's to see.
- **Trap:** a parameter named `pLayer` does not compile: LiveCode reads it as `player`.
- **Building while a script is mid-edit:** `Build.Editor` now refuses to save a stack whose
  script does not compile (before, such a stack threw an error at every mouse move).

## A cell: one byte, a tag, a height (version 1)
- **design** (0-255): which glyph of the map's 1-bit font builds this cell: its wall design. Six
  cells holding "CLAUDE" are built from the glyphs drawn for C, L, A, U, D and E in that font.
- **tags** (one character): what the cell is in the game, roguelike style (`#` wall, `+` door,
  `^` trap, `?` text, `!` health, `@` player start ...). 95 named tags; the other codes are
  `custom <n>`, free for our own. Each tag has a colour (data, not code: change it in the table
  or per map), cycling red, green, blue, yellow, magenta, cyan so neighbours never look alike.
- **heights** (0-35, written 0-9 then A-Z): how far the cell is extruded. 9 = a full wall
  (`wallH`); 1 = a step; 0 = floor.
- Later: ceilings and roofed hallways (`~` is already the tunnel tag), more layers as needed.

## The file (`.cellmap`, UTF-8 text)
```
# cellmap 1 - LIB_BIT/editor (format: editor/README.md)
[map]
name	amazing_couple
cols	13          rows	13
cell	76          wallH	58      unitPx	16    (Amazing Couple's kCell / kWallH; glyph size)
font	Base_001    tags	tags_default     version	1
[design]            one character a cell (codes 32-126 and 161-255);
#CLAUDE######       [design hex] instead (two hex digits a cell) when any code doesn't print
...
[tags]              one tag character a cell
[heights]           0-9 A-Z a cell
[tagdefs]           optional: this map's own tags: char, name, colour, solid, height
```
In LiveCode: `tMap["meta"][key]`, `tMap["design"|"tags"|"heights"][row][col]`, `tMap["tagdefs"][char][...]`.
In Python: the same names in a dict of lists. Both write the identical file (tested).

## View menu
Palette / Map / Ghost strength (100% to 35%, by blendLevel; the palette starts at 55%), Ghost: Off.
Colours later (LIB_THEME), e.g. glyphs in hot pink.

## Fonts
- **Aquarius** (default): the Mattel Aquarius character set at 16 x 16 (AquaDouble, from the
  owner's BitFontMaker stack). Codes 128-255 hold line pieces (corners, tees, crosses), quarter
  blocks and a solid block (255): walls draw as joined lines.
- Base_001 (256 pattern tiles), 24_Seniors_Sigils. Any BitFontMaker2 .json in fonts/ converts with
  `python3 -I python/cellmap.py fonts`.
- **Auto walls** (Tiles menu, `CellMap.AutoWalls`, `cellmap.autowall`): every plain `#` wall takes
  the line piece that joins its full-height neighbours; hand-drawn designs (letters) stay.

## The editor stack
Open `BitEditor.livecode` (keep it in this folder: it finds the libraries and data next to it).
It opens `maps/amazing_couple.cellmap`.
- **Left:** the 256 codes in their tag colours; type in Filter to narrow (e.g. `hazard`, `door`).
- **Middle:** the selected code's 16 x 16 glyph: click or drag to flip bits; the quick functions
  under it (flip, rotate, invert, shift) work on the whole glyph. The panel shows the tag and its
  **effect** (what the cell does). File > Save Font keeps glyph changes.
- **Top left:** the glyph palette: all 256 glyphs of the map's font in one 1-bit picture; click one.
- **Right, 1bit tab:** the whole map as ONE 1-bit picture made of its glyphs, light on dark. A
  **ghost** of the selected glyph follows the mouse, snapped to the cell it would paint:
  click or drag paints the selected glyph into cells (design only); right-click picks a glyph.
  `python3 -I python/cellmap.py onebit maps/amazing_couple.cellmap` shows it in a terminal.
- **Right, Cells tab:** the coloured cell grid: click or drag paints the selected code (design, tag
  and height at once; Tiles > Paint ... Only for one layer); right-click (or Option-click) picks a
  cell's code. Tiles > View Tags / Design / Heights. Mesh > Height sets the extrusion painted.
  Vibe and xt3D tabs: not connected yet, on purpose.
- Rebuild after editing `livecode/editor_stack.livecodescript`:
  `start using stack ".../editor/livecode/build_editor.livecodescript"` then `Build.Editor ".../editor"`.
- Test without a window: `~/projects/LIB_MCP/tools/lcmcp --standalone run - < tests/lc_editor_test.txt`
