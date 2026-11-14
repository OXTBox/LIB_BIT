# 1-bit to 3D utility (the owner's prototype, 2026-11-14)

Source: `1bit_to_3D_utility_Prototype.livecode` (one card, 9 controls, no scripts yet), harvested
to `~/projects/XTJSON/batch/1bit_to_3D_utility_Prototype/`, original moved to
`LIB_LLMOUT/Read/LIB_XTJSON/`. Everything below comes from the text in its fields, its tab menus
and its `About_` custom properties (the images were not opened).

## What it is meant to do
Paint a 1-bit map on a grid, using characters from a font (or chosen characters) as brushes,
and see it as 3D blocks ("cells") in the Vibecode3D and xt3d viewports. Cells can carry tags
(door, window, trap...). It is a level/tile editor built on 1-bit data.

## The layout (stack 969 x 486)
| Area | Control | Owner's words |
|---|---|---|
| Left column | tabbed button `Font_Char_Tab_Menu` (Font / Char) + scrolling field `Fonts_or_Chars_List` | "Choose from a font that will provide the character set to be turned into 3D cells, or choose the characters." Characters can show as images inside the field, scaled with textSize: "We can build an easy toolbox like that from PBM data." |
| Middle top | image `Bitmap_Drawing_Gird` (287 x 287) | the drawing board: "drawing the current selected character into the 1-bit map, like a grid based paint tool" |
| Middle bottom | tabbed button `Focus_Menu`: Bit / Grid / Files / Mesh / Scene / Tiles; `Filter:` field; scrolling field of quick functions | "Changes the focus of what the user is editing" (below) |
| Right | tabbed button `Tab Menu`: 1bit / Vibe / xt3D, around image `3D_Viewport` (472 x 442) | "1-bit tab shows the one bit map...; Vibe tab will show the Vibecode3D viewport and its representation of the map; xt3D will show the xt3d viewport" |

## The focus tabs
- **Bit**: change the bitmap data on the drawing board.
- **Grid**: the drawing area's parameters (size).
- **Files**: file access (open/save maps, fonts, PBM).
- **Mesh**: what a placed block does to the mesh: extrude 1 unit or 3 units? merge with
  neighbours, or keep every block's own edges?
- **Scene**: the whole scene matrix: total width and height, culling on or off.
- **Tiles**: tags for tiles, "Door", "Window", "Trap", "Text", "Health", shown by colour on the
  drawing grid, the list and the viewports.
- Owner: "Running out of room in the UI, let's do better than this, more menus than tabs."

## Quick functions (the scrolling field)
Flip Horizontal, Flip Vertical, Rotate 90 ccw, Rotate 90 cw. "Bit tab targets the bits, Map tab
targets the 3D viewport." **UNIT**: a list of map units; picking one shows its bits on the
drawing board and centres the 3D camera on it, keeping the camera's height.

## What already exists
| Need | Have |
|---|---|
| the 1-bit map as text, flips, rotations | LIB_BIT: `Bit.FlipHorizontal`, `Bit.FlipVertical`, `Bit.Rotate(g, 90/-90)`, `Bit.Shift`, `Bit.Invert`, `Bit.Pad` |
| show a grid in a LiveCode image / in a list field | `Bit.ToPBM` (images show PBM text directly) |
| font characters as bits | `Bit.FromRows` (BitFontMaker2 rows); BitFontMaker harvest in `XTJSON/batch/BitFontMaker_02_20_2026`; bitfont JSONs in LIB_LLMIN/LIB_DEE (Sigils, 24 Seniors) |
| grid -> 3D walls | LIB_MAP `Map.BlockEdges(grid, cell, height, floor)` -> segments; Amazing Couple's `Couple.SegmentsToMesh` turns them into an engine wire mesh (merged edges, so "merge with adjacent" is the default) |
| the same scene in both engines | every Vibecode3D card script runs in the xt3d bench |

## Open questions for the owner (with my defaults)
1. One map = one big 1-bit grid, and a "unit" = one character-sized cell of it (8x8 or 16x16)?
   Default: yes; UNIT list = the cells that have anything in them.
2. "Extrude 1 unit or 3 units": the block height in cells? Default: a Mesh setting, 1 or 3.
3. Tags: kept beside the bits as a second grid of letters (D door, W window, T trap...)?
   Default: yes, a same-size text grid, so the 1-bit map stays pure 1-bit.
4. "More menus than tabs": a menu bar (File / Edit=Bit / Grid / Mesh / Scene / Tiles) and keep
   tabs only for the viewport (1bit / Vibe / xt3D)? Default: yes.
5. Where does it live: a stack in LIB_BIT, or a Vibecode3D editor card like the iGame3D UI
   remake (`Play.Ig3dEditor`)? Default: an editor card in Vibecode3D, LIB_BIT doing the data.
