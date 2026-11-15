# Plan: painting in the 3D view, and the Clutter brush

Claude (Fable), 2026-11-15, from the owner's notes of that morning: "100% of users are going to
want to paint in the 3D scene, it's the first thing I tried even though I KNEW it wasn't in the
design. Let's make a plan for that", and "A Clutter brush should be included in that plan".
Estimates are AI working time. **Built so far (2026-11-15, after the owner's answers): 1a, 1b
and 1c.** Everything else is still a plan. Open questions are at the end.

## What is already there to build on (done 2026-11-15)
- **The stroke engine** (`Ed.StrokeBegin / StrokeTick / StrokeEnd` in `editor_stack`): one press
  of the mouse is followed every 15 ms; every cell on the way is painted; the slow redraws wait.
  It does not care where the cell came from: the 2D map and the board use it now, the 3D view
  only has to answer "which cell is under the mouse".
- **The change history**: every cell change is a numbered, timed line; a stroke is one undo.
  That is also a recorded path, which is what the Clutter brush stores.
- **The yellow cursor** in the 3D preview already marks one cell and stands a pin on it.

## Part 1. Painting in the 3D view

### 1a. Which cell is under the mouse (picking) - DONE
The preview is drawn by `edProject` (turn, tilt, distance). Picking is the same sum backwards:
the mouse gives a ray from the eye; walk that ray across the grid cell by cell (the way a
raycaster does) and stop at the first cell whose top is above the ray: its ground, its roof
top, or its slab. That gives the cell AND the level (floor, roof or cloud) the user pointed at.
Pure maths, no screen needed, so it gets a Python twin and a test like the rest of cellmap:
As built: `CellMap.Pick(map, ex, ey, ez, dx, dy, dz, max)` -> "col,row,what" (what: ground, roof,
slab, or void = empty space inside the map, so it can be painted). It looks along the ray every
eighth of a cell rather than cell by cell; the face (which side) is not given yet (needed for 1e).

### 1b. Painting - DONE (the ghost in 3D is not: the yellow cursor marks the cell)
`Ed.MapCell()` gets a sibling `Ed.ViewCell()`; the stroke engine takes whichever the mouse is
over. Same brush, same three things painted (glyph, property, height), same undo. The 2D map
and the 3D view update together, as now. The glyph ghost is drawn on the cell's top in 3D.

### 1c. The mouse in the 3D view - DONE (the owner's answer, 2026-11-15)
"Left paints, right camera mode (should enable WASD RF (forward, strafe left, strafe right,
back and Up Down) while right key is held)."
As built: left = paint (Alt + click picks up); while the RIGHT button is held: drag turns,
W / S forward / back, A / D left / right, R / F up / down, Shift + drag zooms; the wheel zooms.
The camera turns around the point it looks at, and the keys move that point (0.8 of the
viewing distance a second). Scene > Reset View puts it back.

### 1d. Heights by hand - about 1.5 hours
In the Heights tab, press on a cell in 3D and drag up or down: its floor (or ceiling, by the
tool) follows the mouse in steps of 10, shown as a number by the pin. Shift = the whole
connected area of the same height (a room's floor, a pool). This is the gesture people expect
from a 3D editor, and it is one stroke, so one undo.

### 1e. Sides - later, only if wanted
A click on a wall's side could paint the neighbouring cell (build outward, as in block
games). The pick already knows the face, so this is small, but it changes what a click means:
leave it off until asked for.

**Order:** 1a, 1b, 1c are built; the owner tries them; then 1d.

## Part 2. The Clutter brush

### The idea in one line
A clutter stroke stores **the path and the recipe, never the objects**. The objects are made
again from them every time, the same every time. So everything stays editable after placing,
and the game can make fewer of them when it is slow.

### 2a. What a stroke stores (a `[clutter]` section in the cellmap, one line a stroke)
| Field | Meaning |
|---|---|
| id | c1, c2 ... |
| list | which clutter list: `trees`, `barrels`, `buildings` ... |
| path | the recorded brush path: points in cells with decimals (x,z, and y for the level), or a **shape** (2d) |
| width | how far from the path objects may fall |
| density | objects per cell of path length |
| seed | the number all the randomness comes from |
| size | smallest and largest scale |
| turn | random facing, or facing along the path |
| keep | the least share that is always drawn (0 = all of it may go when slow) |

### 2b. Clutter lists (`editor/data/clutter/<name>.txt`, one kind a line)
kind (a procedural entity recipe from `LIB_SPARK/entities`, a glb, or a plain box / cone /
cylinder as a placeholder), weight (how often), size range, whether it blocks walking.
Lists are data: the owner or Spark writes them.

### 2c. Making the objects (pure function, Python and LiveCode twins, tested equal)
`CellMap.Clutter(map, budget)` -> one line an object: kind, x, y, z, turn, scale, rank.
- Walk each path; at every step roll the seeded dice: place or not, which kind, how far to the
  side, what size. y comes from `CellMap.GroundAt`, so clutter sits on pools' edges, daises, roofs.
- Each object gets a **rank** between 0 and 1 from its own dice. `budget` 1 gives all of them,
  0.5 the half with the lowest ranks, and always the same half. Nothing pops in and out at random.
- An object that would stand in a wall or in empty space is skipped.

### 2d. Shapes as paths (procedural paths)
A path can be a formula instead of a recording: line, rectangle, circle, spiral, grid, and
curves that leave the ground such as a Moebius strip. A shape is sampled into the same list of
points (with an "up" direction for the ones in the air), so 2c does not know the difference.
Stored as `shape circle 12,9 r 4` in the path field. Editing its numbers moves the clutter.

### 2e. In the editor - about 3 hours
- A third left tab, **Clutter**: the lists on top, this map's strokes under them.
- Brush: pick a list, drag on the 2D map or (after part 1) in 3D. The stroke engine records
  the path; release stores one `[clutter]` line; one undo removes it.
- Select a stroke (click it in the list or on the map): its path lights up; fields for width,
  density, seed, size; every change redraws at once. "Reroll" = a new seed.
- Shapes: Clutter > Add Shape, then the same fields plus the shape's numbers.
- The 3D preview draws clutter as small upright marks in the kind's colour (the preview stays
  a line drawing); the engines draw the real things.

### 2f. In the game (Vibecode3D first) - about 2 hours
- The level loader calls `CellMap.Clutter(map, 1)` once and spawns in rank order.
- **The frame rate rule (the owner's):** below 20 frames a second for a second, hide the top
  10% of ranks still showing; repeat until it holds or `keep` is reached. Above 30 for five
  seconds, bring 10% back. **The static mesh (the level itself) is never touched.**
- Hidden, not destroyed, so coming back costs nothing.

### 2g. Two recordings, as the owner said
"Each cell or pixel change is its own index ... each mouseDown is its own undo. One could be
for animation or path systems for entities and the other strictly editor requirement."
- The editor's history (built today) stays the editor's: it is cleared when a map opens.
- A path worth keeping is **saved into the map** as a `[clutter]` path or, for entities, a
  `[paths]` section (id, points with times): a patrol route, a camera rail, a drawing that
  replays itself. Edit > Export Change History already writes today's strokes as text in that
  shape, to try the idea before the format is fixed.

**Order:** 2a-2c (format, lists, the generator with tests: about 2 hours, no screen needed),
2e (editor), 2d (shapes), 2f (game). About 9 hours in all; 2a-2c can start at once.

## Questions (the default I take if you say nothing)
1. ANSWERED: left paints, right button held = camera mode with W A S D R F. Built.
2. ANSWERED: new maps start with Whole Cell. (As it already was.)
3. **Clutter kinds first:** boxes, cones and cylinders as placeholders, then Spark's entity
   recipes? Default: yes, placeholders first.
4. **Clutter and walking:** does clutter block? Default: no, unless its list line says so.
5. **Undo across maps:** should the history survive opening another map? Default: no.
