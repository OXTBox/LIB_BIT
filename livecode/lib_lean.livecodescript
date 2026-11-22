script "lib_lean"
######################################################################################
## lib_lean (LIB_BIT, 11 21 2026): the LEAN STYLE. A rough level built of cubes becomes a clean
## line drawing, the way DotMazeLean's maze was made (LIB_GAMES/Vibecode3D_Games/DotMaze/PERF.md):
##   1. only the edges you can see: a line only where solid meets open (or the map's edge);
##      the lines between two cubes side by side, and the floor's grid lines, are dropped
##   2. straight runs joined: a wall eight cells long is one line, not eight
##   3. uprights only where the outline turns (a corner, an end, a T), not along a straight wall
##   4. one drawing for all of it (Lean.Walls): one object for the engine, not one a cube
##
## Segments are the cellmap's own format (CellMap.LevelSegments, editor/CELLMAP_V2.md 6), one a line:
##   "x1,y1,z1,x2,y2,z2,class"  x and z in sixteenths of a cell from the map's north-west corner
##   (x east = along a row, z south = down the rows), y in height units (hu, 100 = one cell high).
##
##   Lean.Segments(pSegs, pStyle)        any level's segments made lean (the BitEditor's Lean Style)
##   Lean.GridSegments(pGrid, pStyle)    a text grid (lines of characters, "#" solid) as lean segments
##   Lean.Walls(pGrid, pCell, pStyle)    the same as ONE engine mesh, ready for Mesh.Define
##   Lean.Style(pText)                   a style from text: "posts=none|layers=-20,20|view=front"
##
## pStyle (an array; empty or missing keys take the defaults):
##   drop    classes whose flat lines go (default "floor": the grid between equal cells)
##   posts   corners (default): uprights where the outline turns | all: every upright | none
##   solid   the characters that are solid in a text grid (default "#")
##   layers  the outline's heights in hu, comma separated (default 0,100: foot and top of the wall)
##   view    Lean.Walls only: plan (default: rows run along z, layers are height, up is -y as in the
##           engine) | front (rows run down the screen, layers are depth z: DotMazeLean)
##
## Every handler is pure (text and arrays in and out) except Lean.Walls, which calls the engine's
## Mesh.New / Mesh.AddVertex / Mesh.AddLine (the engine contract) and so needs the engine loaded.
######################################################################################

-------------------------------------------------------------------- styles

function Lean.Style pText
   local tStyle, tPart
   set the itemDel to "|"
   repeat for each item tPart in pText
      set the itemDel to "="
      if the number of items of tPart >= 2 then put item 2 to -1 of tPart into tStyle[word 1 of item 1 of tPart]
      set the itemDel to "|"
   end repeat
   set the itemDel to comma
   return tStyle
end Lean.Style

private function lnOpt pStyle, pKey
   if pStyle is an array then
      if pStyle[pKey] is not empty then return pStyle[pKey]
   end if
   switch pKey
      case "drop"
         return "floor"
      case "posts"
         return "corners"
      case "solid"
         return "#"
      case "layers"
         return "0,100"
      case "view"
         return "plan"
   end switch
   return empty
end lnOpt

-------------------------------------------------------------------- any level's segments

-- 1 drop the classes' flat lines, 2 join straight runs, 3 keep uprights only where the outline turns.
-- Sloped and diagonal lines pass through unchanged. The answer is sorted (the same input, the same text).
function Lean.Segments pSegs, pStyle
   local tDrop, tPosts, tSeg, x1, y1, z1, x2, y2, z2, tClass, tRuns, tUps, tOther, tKey, tOut, tParts
   local tRunList, tRun, a, b, tAt, tDirs, tUp, tLo, tHi, tWant
   put lnOpt(pStyle, "drop") into tDrop
   put lnOpt(pStyle, "posts") into tPosts
   set the itemDel to comma
   repeat for each line tSeg in pSegs
      if tSeg is empty then next repeat
      put item 1 of tSeg + 0 into x1
      put item 2 of tSeg + 0 into y1
      put item 3 of tSeg + 0 into z1
      put item 4 of tSeg + 0 into x2
      put item 5 of tSeg + 0 into y2
      put item 6 of tSeg + 0 into z2
      put item 7 of tSeg into tClass
      if y1 = y2 and z1 = z2 and x1 is not x2 then
         if tClass is among the items of tDrop then next repeat
         put min(x1, x2) & comma & max(x1, x2) & return after tRuns[tClass & "|" & y1 & "|x|" & z1]
      else if y1 = y2 and x1 = x2 and z1 is not z2 then
         if tClass is among the items of tDrop then next repeat
         put min(z1, z2) & comma & max(z1, z2) & return after tRuns[tClass & "|" & y1 & "|z|" & x1]
      else if x1 = x2 and z1 = z2 and y1 is not y2 then
         put x1 & comma & min(y1, y2) & comma & z1 & comma & x1 & comma & max(y1, y2) & comma & z1 & comma & tClass into tUp
         put true into tUps[tUp]
         -- where its foot and top stand, for lnMark: x along a z line (y|z), z along an x line (y|x)
         put x1 & return after tWant["x|" & min(y1, y2) & "|" & z1]
         put x1 & return after tWant["x|" & max(y1, y2) & "|" & z1]
         put z1 & return after tWant["z|" & min(y1, y2) & "|" & x1]
         put z1 & return after tWant["z|" & max(y1, y2) & "|" & x1]
      else
         put tSeg & return after tOther
      end if
   end repeat
   -- join the runs: a key is class|y|axis|fixed, its lines "from,to"
   repeat for each key tKey in tRuns
      put tRuns[tKey] into tRunList
      delete the last char of tRunList
      sort lines of tRunList ascending numeric by item 1 of each
      put empty into a
      repeat for each line tRun in tRunList
         if a is empty then
            put item 1 of tRun into a
            put item 2 of tRun into b
         else if item 1 of tRun <= b then
            put max(b, item 2 of tRun) into b
         else
            put lnRun(tKey, a, b) & return after tOut
            lnMark tAt, tWant, tKey, a, b
            put item 1 of tRun into a
            put item 2 of tRun into b
         end if
      end repeat
      put lnRun(tKey, a, b) & return after tOut
      lnMark tAt, tWant, tKey, a, b
   end repeat
   -- the uprights: along a straight wall (only east+west, or only north+south, at its foot and top) they go
   repeat for each key tUp in tUps
      if tPosts is "none" then exit repeat
      if tPosts is "corners" then
         put item 1 of tUp into x1
         put item 3 of tUp into z1
         put item 2 of tUp into tLo
         put item 5 of tUp into tHi
         put tAt[tLo & "|" & x1 & "|" & z1] & tAt[tHi & "|" & x1 & "|" & z1] into tDirs
         if lnStraight(tDirs) then next repeat
      end if
      put tUp & return after tOut
   end repeat
   put tOther after tOut
   if the last char of tOut is return then delete the last char of tOut
   sort lines of tOut
   return tOut
end Lean.Segments

private function lnRun pKey, pA, pB
   set the itemDel to "|"
   if item 3 of pKey is "x" then return pA & comma & item 2 of pKey & comma & item 4 of pKey & comma & pB & comma & item 2 of pKey & comma & item 4 of pKey & comma & item 1 of pKey
   return item 4 of pKey & comma & item 2 of pKey & comma & pA & comma & item 4 of pKey & comma & item 2 of pKey & comma & pB & comma & item 1 of pKey
end lnRun

-- which ways the flat lines leave the points where uprights stand: tAt["y|x|z"] holds letters
-- E W (along x) and N S (along z). A point inside a run gets both of its letters. pWant lists the
-- upright points that lie on each line (so a long run costs only its uprights).
private command lnMark @pAt, @pWant, pKey, pA, pB
   local tY, tAxis, tFixed, tP, tStep, tBack, tOn
   set the itemDel to "|"
   put item 2 of pKey into tY
   put item 3 of pKey into tAxis
   put item 4 of pKey into tFixed
   set the itemDel to comma
   repeat for each line tP in pWant[tAxis & "|" & tY & "|" & tFixed]
      if tP < pA or tP > pB then next repeat
      if tAxis is "x" then
         put tY & "|" & tP & "|" & tFixed into tStep
         put "W" into tBack
         put "E" into tOn
      else
         put tY & "|" & tFixed & "|" & tP into tStep
         put "N" into tBack
         put "S" into tOn
      end if
      if tP > pA then put tBack after pAt[tStep]
      if tP < pB then put tOn after pAt[tStep]
   end repeat
end lnMark

-- only one straight line passes here: east and west only, or north and south only
private function lnStraight pDirs
   local tEW, tNS
   if pDirs is empty then return false
   put ("E" is in pDirs or "W" is in pDirs) into tEW
   put ("N" is in pDirs or "S" is in pDirs) into tNS
   if tEW and tNS then return false
   if tEW then return ("E" is in pDirs and "W" is in pDirs)
   return ("N" is in pDirs and "S" is in pDirs)
end lnStraight

-------------------------------------------------------------------- a text grid

-- a cell is solid when its character is in the style's `solid`; outside the grid is open.
-- Each layer gets the outline of the solid blocks, uprights join the lowest layer to the highest.
function Lean.GridSegments pGrid, pStyle
   local tSolid, tLayers, tRows, tCols, r, c, tY, tOut, tLo, tHi, tCorner, tKey, tLine
   put lnOpt(pStyle, "solid") into tSolid
   put lnOpt(pStyle, "layers") into tLayers
   put the number of lines of pGrid into tRows
   put 0 into tCols
   repeat for each line tLine in pGrid
      put max(tCols, the number of chars of tLine) into tCols
   end repeat
   put item 1 of tLayers into tLo
   put item 1 of tLayers into tHi
   repeat for each item tY in tLayers
      put min(tLo, tY) into tLo
      put max(tHi, tY) into tHi
   end repeat
   -- across: line r lies between row r and row r+1 (0 = the top edge); down: line c between column c and c+1
   put 0 into r
   repeat while r <= tRows
      put 1 into c
      repeat while c <= tCols
         if lnSolid(pGrid, tSolid, c, r) is not lnSolid(pGrid, tSolid, c, r + 1) then
            repeat for each item tY in tLayers
               put ((c - 1) * 16) & comma & tY & comma & (r * 16) & comma & (c * 16) & comma & tY & comma & (r * 16) & ",wall" & return after tOut
            end repeat
            put true into tCorner[(c - 1) & comma & r]
            put true into tCorner[c & comma & r]
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   put 0 into c
   repeat while c <= tCols
      put 1 into r
      repeat while r <= tRows
         if lnSolid(pGrid, tSolid, c, r) is not lnSolid(pGrid, tSolid, c + 1, r) then
            repeat for each item tY in tLayers
               put (c * 16) & comma & tY & comma & ((r - 1) * 16) & comma & (c * 16) & comma & tY & comma & (r * 16) & ",wall" & return after tOut
            end repeat
            put true into tCorner[c & comma & (r - 1)]
            put true into tCorner[c & comma & r]
         end if
         add 1 to r
      end repeat
      add 1 to c
   end repeat
   if tLo is not tHi then
      repeat for each key tKey in tCorner
         put (item 1 of tKey * 16) & comma & tLo & comma & (item 2 of tKey * 16) & comma & (item 1 of tKey * 16) & comma & tHi & comma & (item 2 of tKey * 16) & ",wall" & return after tOut
      end repeat
   end if
   return Lean.Segments(tOut, pStyle)
end Lean.GridSegments

private function lnSolid pGrid, pSolid, pC, pR
   local tChar
   if pR < 1 or pC < 1 then return false
   put char pC of line pR of pGrid into tChar
   if tChar is empty then return false
   return (tChar is in pSolid)
end lnSolid

-------------------------------------------------------------------- one engine mesh

-- the text grid's lean segments as ONE mesh (engine units, the grid centred on 0,0; pCell units a
-- cell, 100 hu = one cell). view plan: x east, z south, height up (-y); view front: x right, rows
-- down the screen (+y), layers as depth (+z away). Points shared by two lines are made once.
-- Needs the engine: Mesh.New / AddVertex / AddLine.
function Lean.Walls pGrid, pCell, pStyle
   local tSegs, tSeg, tMesh, tCols, tRows, tLine, tFront, tIdx, tA, tB, tK, tHalfC, tHalfR
   put Lean.GridSegments(pGrid, pStyle) into tSegs
   put the number of lines of pGrid into tRows
   put 0 into tCols
   repeat for each line tLine in pGrid
      put max(tCols, the number of chars of tLine) into tCols
   end repeat
   put tCols / 2 into tHalfC
   put tRows / 2 into tHalfR
   put (lnOpt(pStyle, "view") is "front") into tFront
   put Mesh.New() into tMesh
   set the itemDel to comma
   repeat for each line tSeg in tSegs
      put lnPoint(item 1 to 3 of tSeg, pCell, tHalfC, tHalfR, tFront) into tK
      if tIdx[tK] is empty then
         Mesh.AddVertex tMesh, item 1 of tK, item 2 of tK, item 3 of tK
         put the result into tIdx[tK]
      end if
      put tIdx[tK] into tA
      put lnPoint(item 4 to 6 of tSeg, pCell, tHalfC, tHalfR, tFront) into tK
      if tIdx[tK] is empty then
         Mesh.AddVertex tMesh, item 1 of tK, item 2 of tK, item 3 of tK
         put the result into tIdx[tK]
      end if
      put tIdx[tK] into tB
      Mesh.AddLine tMesh, tA, tB
   end repeat
   return tMesh
end Lean.Walls

-- one segment end "x,y,z" (sixteenths, hu, sixteenths) as engine "x,y,z"
private function lnPoint pP, pCell, pHalfC, pHalfR, pFront
   local tX, tAcross, tH
   put (item 1 of pP / 16 - pHalfC) * pCell into tX
   put (item 3 of pP / 16 - pHalfR) * pCell into tAcross
   put item 2 of pP * pCell / 100 into tH
   if pFront then return tX & comma & tAcross & comma & tH
   return tX & comma & (0 - tH) & comma & tAcross
end lnPoint
