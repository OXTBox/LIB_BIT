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

## A cell: one byte, a tag, a height
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

## The editor stack
Open `BitEditor.livecode` (keep it in this folder: it finds the libraries and data next to it).
It opens `maps/amazing_couple.cellmap`.
- **Left:** the 256 codes in their tag colours; type in Filter to narrow (e.g. `hazard`, `door`).
- **Middle:** the selected code's 16 x 16 glyph: click or drag to flip bits; the quick functions
  under it (flip, rotate, invert, shift) work on the whole glyph. The panel shows the tag and its
  **effect** (what the cell does). File > Save Font keeps glyph changes.
- **Right:** the 1bit tab is the map: click or drag paints the selected code (design, tag and
  height at once; Tiles > Paint ... Only for one layer); right-click (or Option-click) picks a
  cell's code. Tiles > View Tags / Design / Heights. Mesh > Height sets the extrusion painted.
  Vibe and xt3D tabs: not connected yet, on purpose.
- Rebuild after editing `livecode/editor_stack.livecodescript`:
  `start using stack ".../editor/livecode/build_editor.livecodescript"` then `Build.Editor ".../editor"`.
- Test without a window: `~/projects/LIB_MCP/tools/lcmcp --standalone run - < tests/lc_editor_test.txt`
