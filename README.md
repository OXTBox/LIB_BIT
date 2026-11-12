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

## Tests

`python3 tests/run_tests.py` runs 23 checks inside real LiveCode 9.6.3 through
LIB_MCP's standalone (needs `~/projects/LIB_MCP`). All pass.

## Where it came from, and what is next

Made pure from the owner's GridDraw animator (`~/projects/GridDrawAnimation`) and bitmap
tracer (`~/projects/bitmap_trace_animate`), which keep these operations on globals and
redraw the screen as they go. Still to bring over: BitFontMaker2 JSON import/export of a
whole font, actors > animations > frames, undo, and drawing a grid into an xt3d texture.
Outline tracing is a separate library, LIB_TRACE.

Part of the family of separate libraries listed in `~/projects/LIB_MCP/README.md`.
