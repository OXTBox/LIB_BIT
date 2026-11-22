# LIB_BIT

1-bit grids for sprites, fonts and maps, as plain text: one line per row, `1` filled,
`0` empty, any size. Every handler is pure (grids in, grids out), so it works the same
in a stack, a standalone or a server, and an AI model can read and write the data.

```
start using stack "<path>/LIB_BIT/livecode/lib_bit.livecodescript"
put Bit.Blank(16, 16) into tGrid
set the text of image "sprite" to Bit.ToPBM(tGrid)      -- LiveCode displays PBM text
```

| Handler | Does |
|---|---|
| `Bit.Blank(w [, h])` | empty grid |
| `Bit.Width`, `Bit.Height`, `Bit.Count` | size, filled pixels |
| `Bit.Invert` | swap filled and empty |
| `Bit.Shift(grid, "left"/"right"/"up"/"down")` | move one pixel, wrapping around |
| `Bit.FlipHorizontal`, `Bit.FlipVertical` | mirror |
| `Bit.Rotate(grid, 90 / -90)` | quarter turn |
| `Bit.Pad(grid, w [, h])` | centre in a bigger grid (8x8 Aquarius character in a 16x16 cell) |
| `Bit.FromLongString(text, width)` | one long string of bits -> rows |
| `Bit.ToPBM`, `Bit.FromPBM` | PBM text (P1), which LiveCode images show directly |
| `Bit.ToRows`, `Bit.FromRows(rows [, width])` | BitFontMaker2 rows: one number per row, column 1 = 1, column 2 = 2, column 3 = 4 ... |
| `Bit.Maze(cols [, rows [, seed]])` | a perfect maze of cols x rows rooms as a (2c+1) x (2r+1) grid, `1` wall. Seeded with its own Park-Miller numbers, so a seed gives the same maze in every engine (and in Python) |

## The Lean style: lib_lean (21 Nov 2026)

`livecode/lib_lean.livecodescript` turns a rough level built of cubes into a clean line drawing,
the way DotMazeLean's maze was made (`LIB_GAMES/Vibecode3D_Games/DotMaze/PERF.md`): only the
edges you can see (solid meets open), straight runs joined, uprights only where the outline turns,
all of it one drawing. On the BitEditor's maps it leaves 4 lines of 10 (amazing_couple 480 -> 182,
wizard_pool 814 -> 310) in 10-17 ms.

| Handler | Does |
|---|---|
| `Lean.Segments(segs, style)` | any level's segments (`CellMap.LevelSegments` format) made lean |
| `Lean.GridSegments(grid, style)` | a text grid (lines of characters, `#` solid) as lean segments |
| `Lean.Walls(grid, cell, style)` | the same as ONE engine mesh (needs the engine's Mesh calls) |
| `Lean.Style("posts=none\|layers=-20,20\|view=front")` | a style from text |

Style keys: `drop` (classes whose flat lines go, default `floor`), `posts` (`corners` default /
`all` / `none`), `solid` (default `#`), `layers` (outline heights in hu, default `0,100`), `view`
(`plan` default / `front` as DotMazeLean). A map saved with meta `style lean` (BitEditor: Scene >
Lean Style) asks to be drawn this way; E13 Walk The Map does (L switches it).
Tests: `python3 -I tests/lean_tests.py` (16 checks, LIB_MCP standalone) and
`editor/tests/lc_lean_test.txt` (the editor's menu, 11 checks, headless; run it in a copy).

## Tests

`python3 tests/run_tests.py` runs 28 checks inside real LiveCode 9.6.3 through
LIB_MCP's standalone (needs `~/projects/LIB_MCP`). All pass.

## Where it came from, and what is next

Made pure from the owner's GridDraw animator (`~/projects/xtalk_py/corpus/originals/GridDraw_Animation_Stack_10272026.txt`) and bitmap
tracer (`~/projects/xtalk_py/corpus/originals/BITMAPVECTORTRACER_Livecode_Stack_Script.txt`), which keep these operations on globals and
redraw the screen as they go. Still to bring over: BitFontMaker2 JSON import/export of a
whole font, actors > animations > frames, undo, and drawing a grid into an xt3d texture.
Outline tracing is a separate library, LIB_TRACE.

Part of the family of separate libraries listed in `~/projects/LIB_MCP/README.md`.

## Licence

GPL-3.0 (see `LICENSE`), because the xTalk work here is built on the GPL-licensed LiveCode Community 9 engine. Copyright (c) 2026 xAction.

The Python files (`.py`) and other material that is not xTalk are also offered under the MIT licence, Copyright (c) 2026 xAction: you may use them under either licence.
