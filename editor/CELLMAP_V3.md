# cellmap v3: slopes, stacked maps, map packs

Monday, November 16, 2026. Written by Claude (Fable) on the owner's last Fable day, from Opus's
brief (`Next_Steps_With_Claude/FABLE_1_MAP_FORMAT_11_16_2026.md`). It adds to `CELLMAP_V2.md`;
nothing in version 2 changes meaning. What is built and what is only decided is in section 8.

## 1. The short of it

| Question | Decision |
|---|---|
| Slopes | A sloped cell lists **four corner rises** (north-west, north-east, south-east, south-west), in hu above the cell's ground. Only sloped cells are listed, in a new `[slope]` section. |
| Stacked maps | Two maps in the same **place**, one with a higher `base`. They are joined by **plain geometry**: stairs are cells that step up, a hole is cells with floor 0 in the upper map. No links needed to walk between them. |
| Ladders, doors, far-away maps | **Doors**: a line saying "this cell of map A leads to that cell of map B". The game moves the actor. |
| Map packs | A level is a **folder**: ordinary `.cellmap` files and one small text file, `<level>.cellpack`, that names them, orders them, places them and lists the doors. |
| Old maps | Every version 1 and 2 file reads and writes back unchanged (all 19 maps in `maps/` tested, both libraries). No conversion step. A map becomes version 3 only on the day a slope is painted on it. |

## 2. Slopes

### The file
```
[slope]                      col,row <tab> nw ne se sw        (hu each corner rises; 0-255)
6,2	0 60 60 0            the east edge is 60 higher than the west edge: a ramp going up east
4,7	0 0 0 30             only the south-west corner is lifted: a corner slope
```
- The cell's five heights stay as they are. Its ground (`floor - red`, or `floor + green` for a
  tower) is the LOW side; the four rises are added on top of it. Code that knows nothing about
  slopes still sees a sensible flat cell at the low side.
- By custom at least one corner is 0 (if all four are lifted, raise the floor instead; the
  editor does this for you). The reader takes whatever is written.
- A third column is kept for later (`ceiling`, for sloped roofs). Today only the ground slopes;
  lines with another word there are skipped, so a later file does not break today's reader.
- In xTalk: `tMap["slope"][row][col]` = `"nw,ne,se,sw"`. In Python: `m['slope'][(r, c)]` = a list
  of four (0-based, like the layers). `CellMap.Slope / SetSlope / Steep / RiseAt`;
  `slope() / set_slope() / steep() / rise_at()`.

### The shape
The height at a point inside the cell is blended between its four corners (half way along an
edge you are half way between its two corners). An edge slope (two corners equal, the other two
0) is a flat ramp. A twisted cell (one corner up) is a gentle saddle; a solid engine draws it as
two triangles, split on the diagonal that touches the highest corner.

A sloped cell has no raised glyph and no glyph shape (`extrude glyph` leaves it alone).

### Walking and collision
- `CellMap.Walk` already moves in small steps, so a slope is walked like a very fine stair:
  the height under the actor's feet is the ground plus the rise at that point.
- **Steep.** A cell whose corners differ by more than `steep` hu (60 unless the map says
  otherwise: about 26 degrees in a standard map, between TRLE's two-click slope you can walk
  and its three-click slope you slide on) **cannot be walked up**. You can still drop onto
  it and walk down it. Where the tag's effect is `path` or `none`, Walk answers `slide`, so the
  game can push the actor downhill if it wants to. The walker itself never forces a slide, so
  nothing can lock it up.
- Where two neighbours' corners do not meet, there is a ledge like any other: the `step` (30) rule
  decides whether you get up it.

### Illegal slopes (TRLE's word)
In the Tomb Raider editor a slope is illegal when it traps Lara: two slides facing each other, or
a slide into a wall. **We forbid nothing in the file.** The reader never refuses a map. Instead
the checker (E12, to build) warns, with the cell, about:
1. a steep cell whose low edge meets a wall or another steep cell's low edge (a trap);
2. all four corners lifted (not tidy: raise the floor);
3. a slope on an empty cell (floor 0: it does nothing);
4. a rise that pokes through the cell's own roof.

### LevelSegments (built 17 Nov: section 8)
A sloped cell's four ground edges run corner to corner at their own heights. An edge is class
`floor` when the neighbour's matching edge has the same two heights, otherwise the wall class.
The upright at each grid corner runs from the lowest to the highest corner height meeting there.
A twisted cell gets its diagonal (drawn as class `floor`).

## 3. Stacked maps: a room above a room

"A room above a room is two small maps, not one tall one" (version 2 said it; this is how).

- Each map has a **base**: how many hu its zero sits above the place's zero. The pack gives it
  (section 4); a map file's own `base` line is used when it is opened alone.
- An upper map is a **deck**: every cell with a floor is solid from the map's zero up to its
  ground. Under it is the lower map's air; the deck is the lower room's roof. A lower room needs
  no ceiling of its own.
- **A hole** is a cell with floor 0 in the upper map. Nothing more.
- **Stairs** are cells of the lower map that step up by no more than `step` (30) each, under a
  hole, until the top stair is level with the upper deck. A ramp of slopes does the same.
- **Walking between them** (`CellMap.PackWalk`): at every point each map of the place offers the
  heights it has there; another map's solid above a height is its roof. The actor takes the
  highest one it can reach: no more than `step` up, at least `head` (83) of air, and **a drop
  goes through air only, never through a floor**. It answers which map the actor now stands on.
- **Ladders and lifts** are doors (section 4), because the actor does not walk them: the game
  plays the climb and puts the actor at the far end.

The example, `maps/two_rooms/`: a cellar (walls 120 high, four stairs of 30, 60, 90, 120 along
its south wall) and a loft at base 120 (holes over the stairs, a two-cell ramp up to a dais 60
higher with the goal on it). Side view of the stairs, looking north:

```
 hu                                       loft floor (base 120 + floor 1 = 121)
121  ________          hole in the loft        ___________
120  loft deck |                          ____|  top stair 120
 90            |                     ____|
 60            |                ____|          the loft's deck is the cellar's roof:
 30            |           ____|               119 hu of air under it
  1  __cellar floor_______|
     col 2      3           4    5    6          7    8
```

## 4. Map packs: a level's maps in one folder

### The file (`<level>.cellpack`, UTF-8 text, beside its maps)
```
# cellpack 1 - LIB_BIT/editor (format: editor/CELLMAP_V3.md)
[pack]
name	two_rooms
start	cellar                          the map the player starts in (on its @ cell)
[maps]                                  id <tab> file <tab> place <tab> base <tab> col,row
cellar	two_rooms_cellar.cellmap	main	0	1,1
loft	two_rooms_loft.cellmap	main	120	1,1
[doors]                                 from <tab> type <tab> to <tab> note
cellar:2,2	ladder	loft:2,2	the ladder in the corner: up
loft:2,2	ladder	cellar:2,2	and down again
```
- **id**: the map's short name inside the pack. **Order** is the order of the lines.
- **file**: named from the pack's own folder. Never a full path, never `..`: a pack that tries is
  reported and that map is not loaded (an installed game must not reach outside its folder).
- **place**: maps with the same place word share one space and are drawn and walked together
  (stacked rooms, wings of one building). A different word is somewhere else (the next level, a
  cave): only doors lead there. Left empty it is `main`.
- **base**: hu above the place's zero. **col,row**: where this map's cell 1,1 sits on the grid
  of the place's FIRST map. That first map stays centred on 0,0, exactly as when it was alone,
  so a game's coordinates do not move when a second map is stacked on it.
- Maps in one place must share `cell` and `wallH` (reported when they don't).
- **doors**: the same four columns as a map's `[links]`, with the map's id and a colon in front
  of each cell. One line is one way; write two for a door that goes both ways. Types are free
  words for the game (`door`, `ladder`, `stairs`, `lift`, `teleport`, `hole`); the library only
  finds them.
- Whatever is wrong is listed in the pack's `problems`, in plain words; the rest still loads.
- A plain `.cellmap` handed to `CellMap.ReadPack` reads as a pack of one map (and its version 2
  `[stack]` lines as the maps over it), so a game can always load "a pack".

### How a game loads one
A game's levels live in its own folder, one folder a level:
`<game folder>/Maps/<level>/<level>.cellpack` (in the project:
`LIB_GAMES/Vibecode3D_Games/<Game>/Maps/<level>/`). `Game.FindFile` finds the pack
(`LIB_PUBLIC/install/LAYOUT.md` 5.1: the game's folder first, then Common, then the walk up);
the pack finds its maps beside itself, so only ONE path is ever looked for.

```
put Game.FindFile("LIB_GAMES/Vibecode3D_Games/MyGame/Maps/two_rooms/two_rooms.cellpack") into tFile
put CellMap.ReadPack(tFile) into sPack
if sPack["problems"] is not empty then ... say so ...
put CellMap.PackEnter(sPack, sTags, empty, empty) into tAt       -- "place,x,z,y" on the start map's @
-- every step:
put CellMap.PackWalk(sPack, sPlace, sTags, empty, sX, sZ, sY, tDX, tDZ) into tR
-- tR = x,z,y,effect,map id,col,row
put CellMap.PackDoors(sPack, item 5 of tR, item 6 of tR, item 7 of tR) into tDoors   -- lines: type, to, note
-- on the player's key, or at once for a teleport:
put CellMap.PackEnter(sPack, sTags, empty, "loft:2,2") into tAt
```
Python has the same under the same names: `read_pack`, `pack_enter`, `pack_walk`, `pack_doors`,
`pack_stand_at`, `pack_text`.

In xTalk: `tPack["meta"][name|start]`, `tPack["count"]`, `tPack["problems"]`,
`tPack["maps"][n][id|file|place|base|at|map|ox|oz]` (`map` is the loaded cellmap; `ox`, `oz` its
shift in engine units), `tPack["doors"][n][from|type|to|note]`.

## 5. Two fixes to walking that every map gets

Found while proving the stairs; both are in `CellMap.Walk` for single maps too. The version 2
tests give the same numbers as before (segments, walks and picks, both engines).
1. **A drop goes through air only.** Before, an actor on a roof could "drop" through that roof
   onto the floor below when the next cell's roof was too high to step on.
2. **After a drop off a ledge the actor can walk away.** Its rim was left inside the ledge it
   had just fallen from and every move was refused. Now a part of the rim that is already in a
   wall may stay in it; it still cannot ENTER one.

## 6. What the BitEditor needs (built 19 Nov except "Line rooms up": section 8)

| Need | How |
|---|---|
| Paint a slope | Heights tab, a **Slope** tool: pick a rise from the grey swatches, click near an EDGE of a cell to lift that edge, near a CORNER to lift that corner. Swatch 0 flattens. Right-click picks a cell's rises up. (`CellMap.SetSlope`) |
| See a slope | A small arrow in the cell pointing uphill, brighter for higher; red when the cell is steep. |
| Keep it tidy | If all four corners end up lifted, lower them and raise the floor by the same amount. |
| Open a pack | File > Open Pack: a list of the pack's maps (id, place, base, position), up / down to order them, a click opens that map for painting. |
| Line rooms up | Draw the map below (and above) dimly under the one being painted, so holes sit over stairs. |
| Doors | Pick a cell, "Door to...", choose map and cell; the door list beside the map list. |
| Check | The E12 checker: slope traps (section 2), a stair higher than `step`, a hole with nothing under it, a door onto a blocked cell, maps of one place with different `cell` or `wallH`. |
| Save | Nothing new: a map with no slope is still written as version 2. |

## 7. What we did NOT choose (so nobody reopens it)

| Rejected | Why |
|---|---|
| Four more full layers for corner heights (`[nw] [ne] [se] [sw]`) | Nearly every cell is flat: four grids of zeros a map, and every old file would have to grow. |
| One number for a slope (a direction and a rise) | Cannot say a corner slope; TRLE needed both kinds. Four rises say every case and an edge slope is still one click to paint. |
| Corner heights owned by the grid's corners (shared by four cells) | Neighbours could never differ; a ledge beside a ramp would be impossible, and painting one cell would move three others. |
| Sloped roofs now | Nothing needs them yet. The third column of `[slope]` is kept for them. |
| Refusing illegal slopes in the reader | A map that will not open is worse than a map with a warning. The checker warns; the walker cannot be trapped by a slope. |
| Forcing the slide inside the library | How fast and how far is a game's taste. The library says `slide`; the game decides. |
| One tall map with many storeys in a cell | Five heights a cell already carry a pit, a floor, a roof, a tower and a bridge. More storeys a cell means more colours than a person can paint. Two small maps are two pictures. |
| Stairs and holes as links | Geometry already says it; a link could disagree with the heights. Only what cannot be walked (ladder, lift, teleport, far door) is a door. |
| A ladder as a walking rule ("`climb` ignores the step") | `<`, `R` and `_` are `climb` tags too: old maps would start to behave differently. |
| The upper map listed inside the lower map (version 2's `[stack]`) | The lower map should not have to know what is built on it. Still read, as a pack of one; new work uses the pack. |
| One big file holding every map of a level | The BitEditor opens one `.cellmap`; one file a map keeps old maps usable in a pack untouched and lets two maps be worked on at once. |
| A zip as the pack | Not readable in a text editor, and the owner cannot fix a line by hand. |
| Doors written in each map's `[links]` | Only the pack knows the other maps' names; a map would stop working alone. |
| Full or `..` paths in a pack | An installed game must find everything inside its own folder. |

## 8. Status (2026-11-16, drawing and E13 added 2026-11-17)

| Part | State |
|---|---|
| `[slope]` read and written; old maps unchanged (19 files) | done, tested, Python and xTalk |
| Slopes in `StandAt` / `Walk`, the steep rule, `slide` | done, tested, same answers both sides |
| `.cellpack` read and written, problems list, a `.cellmap` as a pack of one | done, tested both sides |
| Stacked maps in the walker (`PackStandAt`, `PackWalk`), doors (`PackDoors`, `PackEnter`) | done, tested: a 12-leg walk up the stairs, up the ramp, off the dais and back down the hole gives the same line for line in Python and xTalk |
| Example `maps/two_rooms/` (cellar, loft, pack) | done, hand-made |
| Tests | `tests/py_v3_test.py` (38 checks), `tests/lc_v3_test.txt` (28 checks; passes on both headless engines) |
| Slopes in `LevelSegments` (drawing) | done 17 Nov (Opus): sloped edges run corner to corner, `floor` when the neighbour's edge matches, uprights from the corner heights, a twisted cell's diagonal; same lines in Python and xTalk (`tests/_py_v3_segments.txt`) |
| `CellMap.PackSegments` / `pack_segments` (a place drawn as one) | done 17 Nov: each map's segments moved by `ox`, `oz` and the pack's base, engine units, the map id as an 8th item |
| BitEditor 3D preview: Scene > Hiding / Show | done 19 Nov: Hiding: Hidden Lines leaves out lines behind walls, floors, roofs and blocks (each line in three pieces, a sight line marched from each to the eye; ~200 ms on wizard_pool, worked out when the view stops); Show: <class> switches one kind of line off (Relief for extruded glyphs). Engines have their own: Vibecode3D gCullMode (Settings HIDING tab) |
| Slopes and packs in `LevelBoxes` (the solid look) | not built: a slope is still a flat box |
| `Pick` (painting in 3D) on slopes and packs | not built: it sees the flat cell of one map |
| The checker (E12) | done 18 Nov (Opus): `CellMap.Check` / `CheckPack`, `check()` / `check_pack()`: one line a problem (kind, map, col,row, words): slope-trap, slope-all, slope-empty, slope-roof, step (only where it cuts an area off), hole, door, link, start, unreachable (one line an area), and the pack reader's problems. Reachability is the walker's rules cell by cell (ground only, not tower tops). Same lines in Python and xTalk on every map in `maps/` (`tests/py_check_test.py` 22 checks, `tests/lc_check_test.txt` 26, both headless engines). Real findings: Amazing Couple 1-3 have 36 cells behind the gate at 10,10 that no link opens; the cropped wizard pool keeps two links that point off the crop; the 12 mazes have no @ |
| BitEditor: Slope tab | done 19 Nov (Opus, branch `cellmap-v3-slope-tool`), its own map tab after the owner's first try ("how is the direction controlled", "slopes are not connected: /| /| /|"). A compass picks uphill (N NE E SE S SW W NW; Auto = the way you drag, or for a click the edge/corner nearest it). **Ramp** (default): drag a box, it becomes ONE plane: corner heights are worked out over the whole box, each cell gets floor = base + its lowest corner and rises = the rest, so neighbours always meet. **Join** (default on): from the floor just before the box to the floor just after it; else (or when that is not higher) by the rise swatch. A pit (red) under a ramp is cleared. **One Cell**: the first tool (lift an edge/corner by the swatch; right-click copies a cell's slope). **Flatten**. Arrows uphill (red = steep). One undo a ramp. `tests/lc_slope_tool_test.txt` (both headless engines) |
| BitEditor: pack window and the checker's list | done 19 Nov (Opus, same branch): File > Open Pack... / New Pack... (holds the open map, written beside it) / Pack Window / Check Map (E12). A floating window "BitEditor Pack": the maps (id, place, base, col,row, file; `*` = the one being painted), double-click opens one (asks to save unsaved changes), Up / Down order them, Place... sets place base col,row, Add... (a map of the pack's folder), Remove, Start; the doors, Door to... (from the last cell clicked) and Remove Door; Save Pack. Check runs `CellMap.CheckPack` on the pack with the open map as it is now (unsaved too), or `CellMap.Check` on a map outside the pack; a click on a line opens its map and frames the cell. `tests/lc_pack_panel_test.txt` (21 checks, both headless engines). Not built: the map below drawn dimly under the one being painted ("line rooms up"), choosing a door's far cell by clicking |
| A game using a pack | `E13_WalkTheMap` (LIB_EDITOR, branch cellmap-v3-followups): M cycles to `two_rooms`, drawn with PackSegments, walked with PackWalk, E climbs the ladder (PackDoors) |
| Speed of `PackWalk` in a real game | not measured (it asks each map of the place at up to nine points a step) |
| `LIB_EDITOR/tests/e13_test.sh` against this library | not run here (it starts the windowed standalone) |

For Opus, in order: ~~(1) segments for slopes, then `CellMap.PackSegments`; (2) E13 walking
`maps/two_rooms`~~ (17 Nov); (3) the BitEditor's Slope tool; (4) the pack panel; ~~(5) the checker~~
(18 Nov; the BitEditor still needs its list: click a line, jump to the cell); (3) the Slope tab and (4) the pack window done 19 Nov; left: rooms lined up dimly, slopes in `LevelBoxes` and `Pick`.
