script "lib_cellmap"
######################################################################################
## lib_cellmap (LIB_BIT/editor, 11 14 2026): the 1-bit to 3D editor's map data.
## A cellmap is a keyed array that reads and writes the same plain text file as
## editor/python/cellmap.py (format: editor/README.md). Every handler is pure: arrays
## and text in, arrays and text out; no globals, no screen.
##
##   tMap["meta"][name|cols|rows|cell|wallH|unitPx|font|tags|version]
##   tMap["design"][row][col]    0-255: which glyph of the map's font builds the cell
##   tMap["tags"][row][col]      one character: what the cell is (# wall, + door, ^ trap ...)
##   tMap["heights"][row][col]   0-35: extrusion, 9 = a full wall (wallH)
##   tMap["tagdefs"][char][name|colour|solid|height|effect]   this map's own tags (optional)
##   effect = what the cell does when an actor touches or enters it (block, open, damage, heal ...)
##   rows and columns count from 1.
## VERSION 2 (CELLMAP_V2.md): instead of heights, five numbers a cell in height units (hu,
## 100 = a full hallway = wallH engine units), each 0-255:
##   tMap["floor"|"ceiling"|"red"|"green"|"blue"][row][col]
##   tMap["links"][n][from|type|to|note]   tMap["objects"][n][id|kind|at|facing|above|props]
##   tMap["stack"][n][file|base|at]
## A version 1 file reads as version 1 (and writes back the same); CellMap.Upgrade makes it 2.
## CellMap.Get / Set with "heights" work on both (version 2: the floor, converted).
## Level: CellMap.Levels, StandAt, Walk, LevelSegments (the same numbers as cellmap.py, tested).
## Tag table (data/tags_default.txt): CellMap.TagsFromText -> [code][char|name|colour|solid|height|group|effect]
## Font (fonts/*.font.txt): CellMap.FontFromText -> [code] = 16 row numbers; CellMap.Glyph -> 0/1 rows
######################################################################################

constant kB36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
constant kLayers2 = "floor,ceiling,red,green,blue"
constant kNoRoof = 9999

-------------------------------------------------------------------- new, get, set

function CellMap.New pCols, pRows, pName
   local tMap, r, c
   if pName is empty then put "untitled" into pName
   put pName into tMap["meta"]["name"]
   put pCols into tMap["meta"]["cols"]
   put pRows into tMap["meta"]["rows"]
   put 76 into tMap["meta"]["cell"]          -- Amazing Couple's kCell
   put 58 into tMap["meta"]["wallH"]         -- Amazing Couple's kWallH
   put 16 into tMap["meta"]["unitPx"]
   put "Base_001" into tMap["meta"]["font"]
   put "tags_default" into tMap["meta"]["tags"]
   put 1 into tMap["meta"]["version"]
   put 1 into r
   repeat while r <= pRows
      put 1 into c
      repeat while c <= pCols
         put 46 into tMap["design"][r][c]
         put "." into tMap["tags"][r][c]
         put 0 into tMap["heights"][r][c]
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   return tMap
end CellMap.New

-- pWhich: design, tags or heights
function CellMap.Get pMap, pWhich, pCol, pRow
   if pWhich is "heights" and pMap["meta"]["version"] >= 2 then return CellMap.FloorToH1(pMap["floor"][pRow][pCol])
   return pMap[pWhich][pRow][pCol]
end CellMap.Get

command CellMap.Set @pMap, pWhich, pCol, pRow, pValue
   if pCol < 1 or pRow < 1 or pCol > pMap["meta"]["cols"] or pRow > pMap["meta"]["rows"] then exit CellMap.Set
   if pWhich is "heights" and pMap["meta"]["version"] >= 2 then
      put CellMap.H1ToFloor(pValue, pMap["tags"][pRow][pCol]) into pMap["floor"][pRow][pCol]
      exit CellMap.Set
   end if
   put pValue into pMap[pWhich][pRow][pCol]
end CellMap.Set

-- a layer as text rows (design as characters, heights as 0-9 A-Z), for lists and tests
function CellMap.LayerText pMap, pWhich
   local tOut, tLine, r, c, v
   put 1 into r
   repeat while r <= pMap["meta"]["rows"]
      put empty into tLine
      put 1 into c
      repeat while c <= pMap["meta"]["cols"]
         put pMap[pWhich][r][c] into v
         if pWhich is "design" then
            put numToCodepoint(v) after tLine
         else if pWhich is "heights" then
            if pMap["meta"]["version"] >= 2 then put CellMap.FloorToH1(pMap["floor"][r][c]) into v
            put char (v + 1) of kB36 after tLine
         else if pWhich is among the items of kLayers2 then
            put format("%3d", v) & space after tLine
         else
            put v after tLine
         end if
         add 1 to c
      end repeat
      if pWhich is among the items of kLayers2 then delete the last char of tLine
      put tLine & return after tOut
      add 1 to r
   end repeat
   delete the last char of tOut
   return tOut
end CellMap.LayerText

-------------------------------------------------------------------- text <-> array

function CellMap.FromText pText
   local tMap, tSec, tLine, tRow, c, n, tCode, tKey, tVal, tItems
   set the itemDel to tab
   repeat for each line tLine in pText
      if char 1 of tLine is "[" and char -1 of tLine is "]" and \
            char 2 to -2 of tLine is among the items of ("map" & tab & "design" & tab & "design hex" & tab & "tags" & tab & "heights" & tab & "tagdefs" & tab & \
            "floor" & tab & "ceiling" & tab & "red" & tab & "green" & tab & "blue" & tab & "links" & tab & "objects" & tab & "stack") then
         put char 2 to -2 of tLine into tSec
         put 0 into tRow
         next repeat
      end if
      if char 1 of tLine is "#" and (tSec is empty or tSec is "map") then next repeat
      switch tSec
         case "map"
            if tab is not in tLine then break
            put item 1 of tLine into tKey
            put item 2 to -1 of tLine into tVal
            put tVal into tMap["meta"][tKey]
            break
         case "design"
            add 1 to tRow
            put 1 into c
            repeat while c <= the number of chars of tLine
               put codepointToNum(char c of tLine) into tMap["design"][tRow][c]
               add 1 to c
            end repeat
            break
         case "design hex"
            add 1 to tRow
            put 1 into c
            repeat for each word tCode in tLine
               put baseConvert(tCode, 16, 10) into tMap["design"][tRow][c]
               add 1 to c
            end repeat
            break
         case "tags"
            add 1 to tRow
            put 1 into c
            repeat while c <= the number of chars of tLine
               put char c of tLine into tMap["tags"][tRow][c]
               add 1 to c
            end repeat
            break
         case "heights"
            add 1 to tRow
            put 1 into c
            repeat while c <= the number of chars of tLine
               put offset(char c of tLine, kB36) - 1 into tMap["heights"][tRow][c]
               add 1 to c
            end repeat
            break
         case "floor"
         case "ceiling"
         case "red"
         case "green"
         case "blue"
            add 1 to tRow
            put 1 into c
            repeat for each word tCode in tLine
               put tCode + 0 into tMap[tSec][tRow][c]
               add 1 to c
            end repeat
            break
         case "links"
            if tLine is empty then break
            add 1 to tRow
            put item 1 of tLine into tMap["links"][tRow]["from"]
            put item 2 of tLine into tMap["links"][tRow]["type"]
            put item 3 of tLine into tMap["links"][tRow]["to"]
            put item 4 of tLine into tMap["links"][tRow]["note"]
            break
         case "objects"
            if tLine is empty then break
            add 1 to tRow
            put item 1 of tLine into tMap["objects"][tRow]["id"]
            put item 2 of tLine into tMap["objects"][tRow]["kind"]
            put item 3 of tLine into tMap["objects"][tRow]["at"]
            put item 4 of tLine into tMap["objects"][tRow]["facing"]
            put item 5 of tLine into tMap["objects"][tRow]["above"]
            put item 6 of tLine into tMap["objects"][tRow]["props"]
            break
         case "stack"
            if tLine is empty then break
            add 1 to tRow
            put item 1 of tLine into tMap["stack"][tRow]["file"]
            put item 2 of tLine into tMap["stack"][tRow]["base"]
            put item 3 of tLine into tMap["stack"][tRow]["at"]
            break
         case "tagdefs"
            if tLine is empty then break
            put item 1 of tLine into tKey
            put item 2 of tLine into tMap["tagdefs"][tKey]["name"]
            put item 3 of tLine into tMap["tagdefs"][tKey]["colour"]
            put item 4 of tLine into tMap["tagdefs"][tKey]["solid"]
            put item 5 of tLine into tMap["tagdefs"][tKey]["height"]
            put item 6 of tLine into tMap["tagdefs"][tKey]["effect"]
            if tMap["tagdefs"][tKey]["effect"] is empty then put "none" into tMap["tagdefs"][tKey]["effect"]
            break
      end switch
   end repeat
   -- rows that lost their trailing spaces: fill them out (void)
   set the itemDel to comma
   put 1 into tRow
   repeat while tRow <= tMap["meta"]["rows"]
      put 1 into c
      repeat while c <= tMap["meta"]["cols"]
         if tMap["design"][tRow][c] is empty then put 32 into tMap["design"][tRow][c]
         if tMap["tags"][tRow][c] is empty then put space into tMap["tags"][tRow][c]
         if tMap["meta"]["version"] >= 2 then
            repeat for each item tKey in "floor,ceiling,red,green,blue"
               if tMap[tKey][tRow][c] is empty then put 0 into tMap[tKey][tRow][c]
            end repeat
         else if tMap["heights"][tRow][c] is empty then
            put 0 into tMap["heights"][tRow][c]
         end if
         add 1 to c
      end repeat
      add 1 to tRow
   end repeat
   return tMap
end CellMap.FromText

-- meta keys are written in this order first, then any others (sorted)
function CellMap.ToText pMap
   local tOut, tKey, tKeys, tHex, r, c, v, tLine, tChars, tV2, n, tAny
   put (pMap["meta"]["version"] >= 2) into tV2
   if tV2 then
      put "# cellmap " & pMap["meta"]["version"] & " - LIB_BIT/editor (format: editor/CELLMAP_V2.md)" & return & "[map]" & return into tOut
   else
      put "# cellmap 1 - LIB_BIT/editor (format: editor/README.md)" & return & "[map]" & return into tOut
   end if
   put "name,cols,rows,cell,wallH,unitPx,font,tags,version" into tKeys
   repeat for each item tKey in tKeys
      if tKey is among the keys of pMap["meta"] then put tKey & tab & pMap["meta"][tKey] & return after tOut
   end repeat
   put the keys of pMap["meta"] into tChars
   sort lines of tChars
   repeat for each line tKey in tChars
      if tKey is not among the items of tKeys then put tKey & tab & pMap["meta"][tKey] & return after tOut
   end repeat
   -- design: characters when every code prints, else hex
   put false into tHex
   repeat for each key r in pMap["design"]
      repeat for each key c in pMap["design"][r]
         put pMap["design"][r][c] into v
         if not ((v >= 32 and v <= 126) or (v >= 161 and v <= 255)) then put true into tHex
      end repeat
   end repeat
   if tHex then
      put "[design hex]" & return after tOut
      put 1 into r
      repeat while r <= pMap["meta"]["rows"]
         put empty into tLine
         put 1 into c
         repeat while c <= pMap["meta"]["cols"]
            put format("%02X", pMap["design"][r][c]) & space after tLine
            add 1 to c
         end repeat
         put char 1 to -2 of tLine & return after tOut
         add 1 to r
      end repeat
   else
      put "[design]" & return & CellMap.LayerText(pMap, "design") & return after tOut
   end if
   put "[tags]" & return & CellMap.LayerText(pMap, "tags") & return after tOut
   if not tV2 then
      put "[heights]" & return & CellMap.LayerText(pMap, "heights") & return after tOut
   else
      repeat for each item tKey in kLayers2
         put (tKey is "floor" or tKey is "ceiling") into tAny       -- red, green, blue: left out when all zeros
         if not tAny then
            repeat for each key r in pMap[tKey]
               repeat for each key c in pMap[tKey][r]
                  if pMap[tKey][r][c] > 0 then put true into tAny
               end repeat
               if tAny then exit repeat
            end repeat
         end if
         if tAny then put "[" & tKey & "]" & return & CellMap.LayerText(pMap, tKey) & return after tOut
      end repeat
      put CellMap.Count(pMap["links"]) into n
      if n > 0 then
         put "[links]" & return after tOut
         put 1 into r
         repeat while r <= n
            put pMap["links"][r]["from"] & tab & pMap["links"][r]["type"] & tab & pMap["links"][r]["to"] & tab & pMap["links"][r]["note"] & return after tOut
            add 1 to r
         end repeat
      end if
      put CellMap.Count(pMap["objects"]) into n
      if n > 0 then
         put "[objects]" & return after tOut
         put 1 into r
         repeat while r <= n
            put pMap["objects"][r]["id"] & tab & pMap["objects"][r]["kind"] & tab & pMap["objects"][r]["at"] & tab & \
                  pMap["objects"][r]["facing"] & tab & pMap["objects"][r]["above"] & tab & pMap["objects"][r]["props"] & return after tOut
            add 1 to r
         end repeat
      end if
      put CellMap.Count(pMap["stack"]) into n
      if n > 0 then
         put "[stack]" & return after tOut
         put 1 into r
         repeat while r <= n
            put pMap["stack"][r]["file"] & tab & pMap["stack"][r]["base"] & tab & pMap["stack"][r]["at"] & return after tOut
            add 1 to r
         end repeat
      end if
   end if
   if the keys of pMap["tagdefs"] is not empty then
      put "[tagdefs]" & return after tOut
      put the keys of pMap["tagdefs"] into tChars
      sort lines of tChars
      repeat for each line tKey in tChars
         put tKey & tab & pMap["tagdefs"][tKey]["name"] & tab & pMap["tagdefs"][tKey]["colour"] & tab & \
               pMap["tagdefs"][tKey]["solid"] & tab & pMap["tagdefs"][tKey]["height"] & tab & \
               pMap["tagdefs"][tKey]["effect"] & return after tOut
      end repeat
   end if
   return tOut
end CellMap.ToText

-- files are UTF-8 (codes 161-255 are written as their own characters)
function CellMap.Read pPath
   return CellMap.FromText(CellMap.ReadText(pPath))
end CellMap.Read

command CellMap.Write pMap, pPath
   put textEncode(CellMap.ToText(pMap), "UTF-8") into URL ("binfile:" & pPath)
   return the result
end CellMap.Write

function CellMap.ReadText pPath
   local tText
   put textDecode(URL ("binfile:" & pPath), "UTF-8") into tText
   replace numToChar(13) & numToChar(10) with return in tText
   return tText
end CellMap.ReadText

-------------------------------------------------------------------- tags and fonts

-- tags_default.txt: code, char, name, colour, solid, height, group, effect (tab separated)
function CellMap.TagsFromText pText
   local tTags, tLine, tCode
   set the itemDel to tab
   repeat for each line tLine in pText
      if tLine is empty or char 1 of tLine is "#" then next repeat
      put item 1 of tLine into tCode
      if tCode is not an integer then next repeat
      put item 2 of tLine into tTags[tCode]["char"]
      put item 3 of tLine into tTags[tCode]["name"]
      put item 4 of tLine into tTags[tCode]["colour"]
      put item 5 of tLine into tTags[tCode]["solid"]
      put item 6 of tLine into tTags[tCode]["height"]
      put item 7 of tLine into tTags[tCode]["group"]
      put item 8 of tLine into tTags[tCode]["effect"]
   end repeat
   return tTags
end CellMap.TagsFromText

-- a map's own tag definitions win over the table's
function CellMap.TagInfo pMap, pTags, pChar, pKey
   if pMap["tagdefs"][pChar][pKey] is not empty then return pMap["tagdefs"][pChar][pKey]
   return pTags[codepointToNum(pChar)][pKey]
end CellMap.TagInfo

-- *.font.txt: "code<tab>r1,r2,...,r16" (BitFontMaker2 rows) plus name / size lines
function CellMap.FontFromText pText
   local tFont, tLine
   set the itemDel to tab
   repeat for each line tLine in pText
      if tLine is empty or char 1 of tLine is "#" then next repeat
      if item 1 of tLine is an integer then
         put item 2 of tLine into tFont[item 1 of tLine]
      else
         put item 2 of tLine into tFont["meta"][item 1 of tLine]
      end if
   end repeat
   return tFont
end CellMap.FontFromText

-- a glyph as 0/1 rows, column 1 = bit value 1 (LIB_BIT's grids)
function CellMap.Glyph pFont, pCode
   local tRows, tOut, tN, tLine, c, tSize
   put pFont["meta"]["size"] into tSize
   if tSize is not an integer then put 16 into tSize
   put pFont[pCode] into tRows
   if tRows is empty then
      put 0 into tN
      repeat while tN < tSize
         put "0," after tRows
         add 1 to tN
      end repeat
   end if
   set the itemDel to comma
   repeat for each item tN in tRows
      put empty into tLine
      put 0 into c
      repeat while c < tSize
         if (tN bitAnd (2 ^ c)) is not 0 then
            put "1" after tLine
         else
            put "0" after tLine
         end if
         add 1 to c
      end repeat
      put tLine & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end CellMap.Glyph

-- 0/1 rows back to the font's numbers (after editing a glyph on the drawing board)
function CellMap.GlyphToRows pGrid
   local tOut, tLine, tN, c
   repeat for each line tLine in pGrid
      put 0 into tN
      put 1 into c
      repeat while c <= the number of chars of tLine
         if char c of tLine is "1" then add 2 ^ (c - 1) to tN
         add 1 to c
      end repeat
      put tN & comma after tOut
   end repeat
   delete the last char of tOut
   return tOut
end CellMap.GlyphToRows

function CellMap.FontToText pFont
   local tOut, tCodes, tCode
   put "# 1-bit font for cellmap: code <tab> 16 rows (BitFontMaker2: column 1 = 1, column 2 = 2 ...)" & return into tOut
   put "name" & tab & pFont["meta"]["name"] & return & "size" & tab & pFont["meta"]["size"] & return after tOut
   put the keys of pFont into tCodes
   filter tCodes without "meta"
   sort lines of tCodes numeric
   repeat for each line tCode in tCodes
      put tCode & tab & pFont[tCode] & return after tOut
   end repeat
   return tOut
end CellMap.FontToText

-------------------------------------------------------------------- auto walls, the 1-bit picture

-- Aquarius (AquaDouble) line pieces by full-height neighbours, N=1 E=2 S=4 W=8 (mask + 1 = item)
constant kAutoWall = "198,214,172,207,214,214,222,205,172,223,172,204,206,221,220,200"

-- every wall cell (tag #) whose design is plain # or an earlier line piece gets the piece that
-- joins its full-height neighbours; hand-made designs (letters) are kept. Same as cellmap.py.
command CellMap.AutoWalls @pMap
   local r, c, tRows, tCols, tMask, tCode
   put pMap["meta"]["rows"] into tRows
   put pMap["meta"]["cols"] into tCols
   put 1 into r
   repeat while r <= tRows
      put 1 into c
      repeat while c <= tCols
         put pMap["design"][r][c] into tCode
         if pMap["tags"][r][c] is "#" and (tCode is 35 or tCode is among the items of kAutoWall) then
            put 0 into tMask
            if r > 1 and CellMap.Get(pMap, "heights", c, r - 1) >= 9 then add 1 to tMask
            if c < tCols and CellMap.Get(pMap, "heights", c + 1, r) >= 9 then add 2 to tMask
            if r < tRows and CellMap.Get(pMap, "heights", c, r + 1) >= 9 then add 4 to tMask
            if c > 1 and CellMap.Get(pMap, "heights", c - 1, r) >= 9 then add 8 to tMask
            put item (tMask + 1) of kAutoWall into pMap["design"][r][c]
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
end CellMap.AutoWalls

-- the whole map as one 1-bit picture: each cell's design glyph (16 x 16), every pixel pScale
-- times, 0/1 rows (LIB_BIT's grids; Bit.ToPBM shows it). pInvert: 1 becomes 0 (light on dark)
function CellMap.OneBitGrid pMap, pFont, pScale, pInvert
   local tGlyph, tLines, r, c, g, tCode, tRow, tOut, tBits, tScaled, i, tCh, k
   if pScale is not an integer or pScale < 1 then put 1 into pScale
   -- each code's 16 rows once, already scaled sideways (and inverted)
   put 1 into r
   repeat while r <= pMap["meta"]["rows"]
      put 1 into c
      repeat while c <= pMap["meta"]["cols"]
         put pMap["design"][r][c] into tCode
         if tGlyph[tCode] is empty then
            put empty into tScaled
            repeat for each line tBits in CellMap.Glyph(pFont, tCode)
               if pInvert then
                  replace "0" with "x" in tBits
                  replace "1" with "0" in tBits
                  replace "x" with "1" in tBits
               end if
               if pScale > 1 then
                  put empty into tLines
                  repeat for each char tCh in tBits
                     put 1 into k
                     repeat while k <= pScale
                        put tCh after tLines
                        add 1 to k
                     end repeat
                  end repeat
                  put tLines into tBits
               end if
               put tBits & return after tScaled
            end repeat
            put tScaled into tGlyph[tCode]
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   -- assemble row by row
   put empty into tOut
   put 1 into r
   repeat while r <= pMap["meta"]["rows"]
      put 1 into g
      repeat while g <= 16
         put empty into tRow
         put 1 into c
         repeat while c <= pMap["meta"]["cols"]
            put line g of tGlyph[pMap["design"][r][c]] after tRow
            add 1 to c
         end repeat
         put 1 into i
         repeat while i <= pScale
            put tRow & return after tOut
            add 1 to i
         end repeat
         add 1 to g
      end repeat
      add 1 to r
   end repeat
   delete the last char of tOut
   return tOut
end CellMap.OneBitGrid

-- which cell is at pixel pX,pY of the 1-bit picture -> "col,row" (empty outside)
function CellMap.CellAtPixel pMap, pScale, pX, pY
   local tC, tR
   put pX div (16 * pScale) + 1 into tC
   put pY div (16 * pScale) + 1 into tR
   if pX < 0 or pY < 0 or tC > pMap["meta"]["cols"] or tR > pMap["meta"]["rows"] then return empty
   return tC & comma & tR
end CellMap.CellAtPixel


-------------------------------------------------------------------- version 2: heights (CELLMAP_V2.md)

function CellMap.Count pArray
   if pArray is not an array then return 0
   return the number of lines of the keys of pArray
end CellMap.Count

-- a version 1 height (0-35, 9 = a full wall) as a version 2 floor (hu, 100 = a full wall)
function CellMap.H1ToFloor pH, pTag
   if pH <= 0 then
      if pTag is space then return 0
      return 1
   end if
   return min(255, trunc(pH * 100 / 9 + 0.5))
end CellMap.H1ToFloor

function CellMap.FloorToH1 pF
   if pF <= 1 then return 0
   return min(35, max(1, trunc(pF * 9 / 100 + 0.5)))
end CellMap.FloorToH1

-- a version 1 map as version 2: heights become floors; nothing else is built
command CellMap.Upgrade @pMap
   local r, c, tKey
   if pMap["meta"]["version"] >= 2 then exit CellMap.Upgrade
   put 1 into r
   repeat while r <= pMap["meta"]["rows"]
      put 1 into c
      repeat while c <= pMap["meta"]["cols"]
         put CellMap.H1ToFloor(pMap["heights"][r][c], pMap["tags"][r][c]) into pMap["floor"][r][c]
         repeat for each item tKey in "ceiling,red,green,blue"
            put 0 into pMap[tKey][r][c]
         end repeat
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   delete variable pMap["heights"]
   put 2 into pMap["meta"]["version"]
end CellMap.Upgrade

-- base, step, head, relief, slab: the map's own value or the default
function CellMap.Opt pMap, pKey
   if pMap["meta"][pKey] is a number then return pMap["meta"][pKey]
   switch pKey
      case "step"
         return 30
      case "head"
         return 83
      case "relief"
         return 6
      case "slab"
         return 10
   end switch
   return 0
end CellMap.Opt

-- engine units a height unit
function CellMap.HU pMap
   return pMap["meta"]["wallH"] / 100
end CellMap.HU

function CellMap.IsWater pMap, pTags, pCol, pRow
   if pMap["red"][pRow][pCol] <= 0 then return false
   return CellMap.TagInfo(pMap, pTags, pMap["tags"][pRow][pCol], "name") begins with "water"
end CellMap.IsWater

-- a cell's column in hu: "ground,roof bottom,roof top,slab bottom,slab top" (empty items: no roof,
-- no slab); empty for empty space or outside the map
function CellMap.Column pMap, pCol, pRow
   local f, cl, rd, g, b, tGround, tTop, tOut
   if pCol < 1 or pRow < 1 or pCol > pMap["meta"]["cols"] or pRow > pMap["meta"]["rows"] then return empty
   put pMap["floor"][pRow][pCol] into f
   if f <= 0 then return empty
   put pMap["ceiling"][pRow][pCol] into cl
   put pMap["red"][pRow][pCol] into rd
   put pMap["green"][pRow][pCol] into g
   put pMap["blue"][pRow][pCol] into b
   put f - rd into tGround
   if cl is 0 then add g to tGround
   put tGround into tTop
   put tGround & comma into tOut
   if cl > 0 then
      put cl & comma & (cl + g) & comma after tOut
      put cl + g into tTop
   else
      put comma & comma after tOut
   end if
   if b > 0 then
      put (tTop + b) & comma & (tTop + b + CellMap.Opt(pMap, "slab")) after tOut
   else
      put comma after tOut
   end if
   return tOut
end CellMap.Column

-- where an actor can stand in a cell: lines "top,air above" in hu, lowest first
function CellMap.Levels pMap, pCol, pRow
   return cmLevels(CellMap.Column(pMap, pCol, pRow))
end CellMap.Levels

-- the same from a column ("ground,roof bottom,roof top,slab bottom,slab top")
private function cmLevels pColumn
   local tC, tGround, tRB, tRT, tSB, tST, tOut
   put pColumn into tC
   if tC is empty then return empty
   put item 1 of tC into tGround
   put item 2 of tC into tRB
   put item 3 of tC into tRT
   put item 4 of tC into tSB
   put item 5 of tC into tST
   if tRB is empty then
      if tSB is empty then
         put tGround & comma & kNoRoof & return after tOut
      else
         put tGround & comma & (tSB - tGround) & return after tOut
      end if
   else
      if tRB > tGround then put tGround & comma & (tRB - tGround) & return after tOut
      if tSB is empty then
         put tRT & comma & kNoRoof & return after tOut
      else
         put tRT & comma & (tSB - tRT) & return after tOut
      end if
   end if
   if tSB is not empty then put tST & comma & kNoRoof & return after tOut
   delete the last char of tOut
   return tOut
end cmLevels

-- the cell's glyph is raised: not a wall, not dug, not blank
function CellMap.HasRelief pMap, pCol, pRow
   local tC
   put CellMap.Column(pMap, pCol, pRow) into tC
   if tC is empty or CellMap.Opt(pMap, "relief") <= 0 then return false
   if pMap["design"][pRow][pCol] is 32 or pMap["design"][pRow][pCol] is 46 then return false
   if pMap["red"][pRow][pCol] is not 0 or item 1 of tC >= 100 then return false
   return (item 2 of tC is empty or item 2 of tC > item 1 of tC)
end CellMap.HasRelief

-- the map says `extrude glyph` and this cell's glyph can stand as the solid: the lit bits rise
-- from the flat floor (1) to the cell's ground, the rest of the cell is flat floor
-- (CELLMAP_V2.md section 4b). Not for blank glyphs, pits, or cells no higher than the floor.
function CellMap.Shaped pMap, pFont, pCol, pRow
   local tC, tBits
   if pMap["meta"]["extrude"] is not "glyph" or pFont is not an array then return false
   if pMap["design"][pRow][pCol] is 32 or pMap["design"][pRow][pCol] is 46 then return false
   if pMap["red"][pRow][pCol] > 0 then return false
   put CellMap.Column(pMap, pCol, pRow) into tC
   if tC is empty then return false
   if item 1 of tC <= 1 then return false
   put pFont[pMap["design"][pRow][pCol]] into tBits
   replace "0" with empty in tBits
   replace comma with empty in tBits
   return (tBits is not empty)
end CellMap.Shaped

-- the bit of the cell's glyph under engine point pX,pZ is lit
private function cmLit pMap, pFont, pCol, pRow, pX, pZ
   local tPX, tPZ
   put min(15, trunc((pX / pMap["meta"]["cell"] + pMap["meta"]["cols"] / 2 - (pCol - 1)) * 16)) into tPX
   put min(15, trunc((pZ / pMap["meta"]["cell"] + pMap["meta"]["rows"] / 2 - (pRow - 1)) * 16)) into tPZ
   return ((item (tPZ + 1) of pFont[pMap["design"][pRow][pCol]] bitAnd (2 ^ tPX)) is not 0)
end cmLit

-- engine x / z of the centre of a column / row (decimals allowed); the map is centred on 0,0
function CellMap.CellX pMap, pCol
   return (pCol - 0.5 - pMap["meta"]["cols"] / 2) * pMap["meta"]["cell"]
end CellMap.CellX

function CellMap.CellZ pMap, pRow
   return (pRow - 0.5 - pMap["meta"]["rows"] / 2) * pMap["meta"]["cell"]
end CellMap.CellZ

private function cmFloor pN
   if pN < 0 and trunc(pN) is not pN then return trunc(pN) - 1
   return trunc(pN)
end cmFloor

-- "col,row" of an engine point (may be outside the map)
function CellMap.CellAt pMap, pX, pZ
   return (cmFloor(pX / pMap["meta"]["cell"] + pMap["meta"]["cols"] / 2) + 1) & comma & \
         (cmFloor(pZ / pMap["meta"]["cell"] + pMap["meta"]["rows"] / 2) + 1)
end CellMap.CellAt

-- the cell a ray meets first (painting in a 3D view): "col,row,what", what = ground, roof, slab
-- or void (empty space inside the map, met at the flat floor's height); empty = nothing.
-- The ray starts at pEX,pEY,pEZ (engine units, y up) and goes along pDX,pDY,pDZ for pMax units,
-- looked at every eighth of a cell. Whole cells only (a glyph shape counts as its cell).
function CellMap.Pick pMap, pEX, pEY, pEZ, pDX, pDY, pDZ, pMax
   local tLen, tStep, tN, i, x, y, z, tCell, c, r, tC, tHU, tBase, yh, tInside
   put sqrt(pDX * pDX + pDY * pDY + pDZ * pDZ) into tLen
   if tLen is 0 then return empty
   put pMap["meta"]["cell"] / 8 into tStep
   put trunc(pMax / tStep) into tN
   put CellMap.HU(pMap) into tHU
   put CellMap.Opt(pMap, "base") into tBase
   put 0 into i
   repeat while i <= tN
      put pEX + pDX * (i * tStep / tLen) into x
      put pEY + pDY * (i * tStep / tLen) into y
      put pEZ + pDZ * (i * tStep / tLen) into z
      add 1 to i
      put y / tHU - tBase into yh
      put CellMap.CellAt(pMap, x, z) into tCell
      put item 1 of tCell into c
      put item 2 of tCell into r
      put (c >= 1 and r >= 1 and c <= pMap["meta"]["cols"] and r <= pMap["meta"]["rows"]) into tInside
      put empty into tC
      if tInside then put CellMap.Column(pMap, c, r) into tC
      if tC is empty then
         if yh <= 1 then
            if tInside then return c & comma & r & ",void"
            return empty
         end if
         next repeat
      end if
      if yh <= item 1 of tC then return c & comma & r & ",ground"
      if item 2 of tC is not empty then
         if yh >= item 2 of tC and yh <= max(item 3 of tC, item 2 of tC + 4) then return c & comma & r & ",roof"
      end if
      if item 4 of tC is not empty then
         if yh >= item 4 of tC and yh <= item 5 of tC then return c & comma & r & ",slab"
      end if
   end repeat
   return empty
end CellMap.Pick

-- the height (engine units, up) an actor now at height pY would stand at on point pX,pZ; empty =
-- it cannot: outside, empty space, a tag whose effect is block or locked, a rise over `step`,
-- less than `head` of air. pFont (may be empty) adds the raised glyphs.
function CellMap.StandAt pMap, pTags, pFont, pX, pZ, pY
   local tCell, tCol, tRow, tLevels, tEffect, tYH, tBest, tLine, tTop, tAir, i, tRel, tHU, tShaped, tOpen, tC
   put CellMap.CellAt(pMap, pX, pZ) into tCell
   put item 1 of tCell into tCol
   put item 2 of tCell into tRow
   put CellMap.Column(pMap, tCol, tRow) into tC
   if tC is empty then return empty
   -- extrude glyph: off the glyph's lit bits the cell is flat floor, and a "block" tag blocks only the glyph
   put false into tOpen
   put CellMap.Shaped(pMap, pFont, tCol, tRow) into tShaped
   if tShaped then
      if not cmLit(pMap, pFont, tCol, tRow, pX, pZ) then
         put true into tOpen
         put 1 into item 1 of tC
      end if
   end if
   put cmLevels(tC) into tLevels
   if tLevels is empty then return empty
   put CellMap.TagInfo(pMap, pTags, pMap["tags"][tRow][tCol], "effect") into tEffect
   if tEffect is "locked" or (tEffect is "block" and not tOpen) then return empty
   put CellMap.HU(pMap) into tHU
   put pY / tHU - CellMap.Opt(pMap, "base") into tYH
   put empty into tBest
   put 0 into i
   repeat for each line tLine in tLevels
      add 1 to i
      put item 1 of tLine into tTop
      put item 2 of tLine into tAir
      if i is 1 and pFont is an array and not tShaped then
         if CellMap.HasRelief(pMap, tCol, tRow) then
            if cmLit(pMap, pFont, tCol, tRow, pX, pZ) then
               put CellMap.Opt(pMap, "relief") into tRel
               add tRel to tTop
               subtract tRel from tAir
            end if
         end if
      end if
      if tTop <= tYH + CellMap.Opt(pMap, "step") + 0.000001 and tAir >= CellMap.Opt(pMap, "head") then put tTop into tBest
   end repeat
   if tBest is empty then return empty
   return (tBest + CellMap.Opt(pMap, "base")) * tHU
end CellMap.StandAt

-- the highest standing height at pX,pZ (engine units); empty over empty space
function CellMap.GroundAt pMap, pTags, pFont, pX, pZ
   return CellMap.StandAt(pMap, pTags, pFont, pX, pZ, 1000000000)
end CellMap.GroundAt

-- a circle of pRadius fits at pX,pZ for an actor at height pY: its new height, else empty
function CellMap.Fits pMap, pTags, pFont, pX, pZ, pY, pRadius
   local ax, az
   repeat for each item ax in (-pRadius) & comma & pRadius
      repeat for each item az in (-pRadius) & comma & pRadius
         if CellMap.StandAt(pMap, pTags, pFont, pX + ax, pZ + az, pY) is empty then return empty
      end repeat
   end repeat
   return CellMap.StandAt(pMap, pTags, pFont, pX, pZ, pY)
end CellMap.Fits

-- move an actor (a circle, radius 12 unless given) by pDX,pDZ, sliding along what blocks it:
-- "x,z,y,effect" (the effect of the tag of the cell it ends in)
function CellMap.Walk pMap, pTags, pFont, pX, pZ, pY, pDX, pDZ, pRadius
   local tTry, tNY, tCell
   if pRadius is empty then put 12 into pRadius
   repeat for each line tTry in (pDX & comma & pDZ) & return & (pDX & comma & 0) & return & (0 & comma & pDZ)
      if item 1 of tTry is 0 and item 2 of tTry is 0 then next repeat
      put CellMap.Fits(pMap, pTags, pFont, pX + item 1 of tTry, pZ + item 2 of tTry, pY, pRadius) into tNY
      if tNY is not empty then
         add item 1 of tTry to pX
         add item 2 of tTry to pZ
         put tNY into pY
         exit repeat
      end if
   end repeat
   put CellMap.CellAt(pMap, pX, pZ) into tCell
   return pX & comma & pZ & comma & pY & comma & CellMap.TagInfo(pMap, pTags, pMap["tags"][item 2 of tCell][item 1 of tCell], "effect")
end CellMap.Walk

-------------------------------------------------------------------- version 2: the level as line segments

-- the outline of a glyph's lit bits as merged runs: lines "x1,z1,x2,z2" in pixels 0-16.
-- pRows: the font's 16 row numbers (column 1 = bit value 1)
function CellMap.GlyphEdges pRows
   local tLit, z, x, k, tStart, tOn, tOut, tN, a, b
   put 0 into z
   repeat for each item tN in pRows
      put 0 into x
      repeat while x < 16
         put ((tN bitAnd (2 ^ x)) is not 0) into tLit[z][x]
         add 1 to x
      end repeat
      add 1 to z
   end repeat
   put 0 into k
   repeat while k <= 16
      put empty into tStart
      put 0 into x
      repeat while x <= 16
         put false into tOn
         if x < 16 then
            put (tLit[k - 1][x] is true) into a
            put (tLit[k][x] is true) into b
            put (a is not b) into tOn
         end if
         if tOn and tStart is empty then put x into tStart
         if not tOn and tStart is not empty then
            put tStart & comma & k & comma & x & comma & k & return after tOut
            put empty into tStart
         end if
         add 1 to x
      end repeat
      add 1 to k
   end repeat
   put 0 into k
   repeat while k <= 16
      put empty into tStart
      put 0 into z
      repeat while z <= 16
         put false into tOn
         if z < 16 then
            put (tLit[z][k - 1] is true) into a
            put (tLit[z][k] is true) into b
            put (a is not b) into tOn
         end if
         if tOn and tStart is empty then put z into tStart
         if not tOn and tStart is not empty then
            put k & comma & tStart & comma & k & comma & z & return after tOut
            put empty into tStart
         end if
         add 1 to z
      end repeat
      add 1 to k
   end repeat
   delete the last char of tOut
   return tOut
end CellMap.GlyphEdges

private command cmEdge @pFlat, pClass, pY, pCol, pRow, pSide
   -- one side of cell pCol,pRow (counted from 0 here) at height pY
   switch pSide
      case "n"
         put (pCol * 16) & comma & (pCol * 16 + 16) & return after pFlat[pClass & "|" & pY & "|x|" & (pRow * 16)]
         break
      case "s"
         put (pCol * 16) & comma & (pCol * 16 + 16) & return after pFlat[pClass & "|" & pY & "|x|" & (pRow * 16 + 16)]
         break
      case "w"
         put (pRow * 16) & comma & (pRow * 16 + 16) & return after pFlat[pClass & "|" & pY & "|z|" & (pCol * 16)]
         break
      case "e"
         put (pRow * 16) & comma & (pRow * 16 + 16) & return after pFlat[pClass & "|" & pY & "|z|" & (pCol * 16 + 16)]
         break
   end switch
end cmEdge

-- the map as line segments, one a line: "x1,y1,z1,x2,y2,z2,class". x and z in sixteenths of a
-- cell from the map's north-west corner (x east, z south), y in hu (up). Classes: floor, wall,
-- pit, water, ceiling, green, sky, relief. Rules: CELLMAP_V2.md section 6. Runs along a row or
-- column are merged. pFont empty: no relief. CellMap.SegToEngine scales one for an engine.
function CellMap.LevelSegments pMap, pTags, pFont
   local tRows, tCols, tSlab, tRelief, tFlat, tUps, tCol, r, c, tC, tN, tGround, tRB, tRT, tSB, tST
   local tSide, dr, dc, tWater, tBase, tClass, f, tEdge, y, i, j, tAround, tCells, tCell, k, tLo, tHi
   local tShape, tX, tZ
   local tAnyLive, tAnyRed, tAnyGreen, tRoofLo, tRoofHi, tRoofThick, tSBs, tDistinct, tKey, tRuns, tRun, a, b, tOut, tParts, tNC, tNR, tG
   put pMap["meta"]["rows"] into tRows
   put pMap["meta"]["cols"] into tCols
   put CellMap.Opt(pMap, "slab") into tSlab
   put CellMap.Opt(pMap, "relief") into tRelief
   put 1 into r
   repeat while r <= tRows
      put 1 into c
      repeat while c <= tCols
         put CellMap.Column(pMap, c, r) into tCol[r][c]
         if CellMap.Shaped(pMap, pFont, c, r) then
            -- extrude glyph: the cell itself is flat floor; its glyph is drawn as a prism below
            put item 1 of tCol[r][c] into tShape[r][c]
            put 1 into item 1 of tCol[r][c]
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   put 1 into r
   repeat while r <= tRows
      put 1 into c
      repeat while c <= tCols
         put tCol[r][c] into tC
         if tC is empty then
            add 1 to c
            next repeat
         end if
         put item 1 of tC into tGround
         put item 2 of tC into tRB
         put item 3 of tC into tRT
         put item 4 of tC into tSB
         put item 5 of tC into tST
         put CellMap.IsWater(pMap, pTags, c, r) into tWater
         put pMap["floor"][r][c] into f
         if pMap["red"][r][c] > 0 then
            put "pit" into tBase
         else if pMap["green"][r][c] > 0 and pMap["ceiling"][r][c] is 0 then
            put "green" into tBase
         else
            put "wall" into tBase
         end if
         repeat for each word tSide in "n,-1,0 e,0,1 s,1,0 w,0,-1"
            put item 2 of tSide into dr
            put item 3 of tSide into dc
            put item 1 of tSide into tSide
            put r + dr into tNR
            put c + dc into tNC
            put tCol[tNR][tNC] into tN          -- empty outside the map too
            if tN is not empty and item 1 of tN is tGround then
               cmEdge tFlat, "floor", tGround, c - 1, r - 1, tSide
            else
               cmEdge tFlat, tBase, tGround, c - 1, r - 1, tSide
            end if
            if tRB is not empty then
               cmEdge tFlat, "ceiling", tRB, c - 1, r - 1, tSide
               if tRT is not tRB then cmEdge tFlat, "green", tRT, c - 1, r - 1, tSide
            end if
            if tSB is not empty and not (tN is not empty and item 4 of tN is tSB) then
               cmEdge tFlat, "sky", tSB, c - 1, r - 1, tSide
               cmEdge tFlat, "sky", tST, c - 1, r - 1, tSide
            end if
            if tWater then
               put false into tG
               if tN is not empty then
                  if CellMap.IsWater(pMap, pTags, tNC, tNR) and pMap["floor"][tNR][tNC] is f then put true into tG
               end if
               if not tG then cmEdge tFlat, "water", f, c - 1, r - 1, tSide
            end if
         end repeat
         if tWater then
            put true into tUps[((c - 1) * 16) & comma & f & comma & ((r - 1) * 16) & comma & (c * 16) & comma & f & comma & (r * 16) & ",water"]
         end if
         if tShape[r][c] is not empty then
            -- the glyph's outline at the cell's height, an upright under each of its corners
            put tShape[r][c] into y
            repeat for each line tEdge in CellMap.GlyphEdges(pFont[pMap["design"][r][c]])
               if item 2 of tEdge is item 4 of tEdge then
                  put ((c - 1) * 16 + item 1 of tEdge) & comma & ((c - 1) * 16 + item 3 of tEdge) & return after tFlat[tBase & "|" & y & "|x|" & ((r - 1) * 16 + item 2 of tEdge)]
               else
                  put ((r - 1) * 16 + item 2 of tEdge) & comma & ((r - 1) * 16 + item 4 of tEdge) & return after tFlat[tBase & "|" & y & "|z|" & ((c - 1) * 16 + item 1 of tEdge)]
               end if
               put (c - 1) * 16 + item 1 of tEdge into tX
               put (r - 1) * 16 + item 2 of tEdge into tZ
               put true into tUps[tX & comma & 1 & comma & tZ & comma & tX & comma & y & comma & tZ & comma & tBase]
               put (c - 1) * 16 + item 3 of tEdge into tX
               put (r - 1) * 16 + item 4 of tEdge into tZ
               put true into tUps[tX & comma & 1 & comma & tZ & comma & tX & comma & y & comma & tZ & comma & tBase]
            end repeat
         else if pFont is an array then
            if CellMap.HasRelief(pMap, c, r) then
               put tGround + tRelief into y
               put pFont[pMap["design"][r][c]] into tG
               if tG is not empty then
                  repeat for each line tEdge in CellMap.GlyphEdges(tG)
                     if item 2 of tEdge is item 4 of tEdge then
                        put ((c - 1) * 16 + item 1 of tEdge) & comma & ((c - 1) * 16 + item 3 of tEdge) & return after tFlat["relief|" & y & "|x|" & ((r - 1) * 16 + item 2 of tEdge)]
                     else
                        put ((r - 1) * 16 + item 2 of tEdge) & comma & ((r - 1) * 16 + item 4 of tEdge) & return after tFlat["relief|" & y & "|z|" & ((c - 1) * 16 + item 1 of tEdge)]
                     end if
                  end repeat
               end if
            end if
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   -- uprights: one a corner (corner i,j is the north-west corner of cell i+1,j+1)
   put 0 into j
   repeat while j <= tRows
      put 0 into i
      repeat while i <= tCols
         put false into tAnyLive
         put false into tAnyRed
         put false into tAnyGreen
         put empty into tLo
         put empty into tHi
         put empty into tRoofLo
         put empty into tRoofHi
         put false into tRoofThick
         put empty into tSBs
         repeat for each word tCell in (j & comma & i) && (j & comma & (i + 1)) && ((j + 1) & comma & i) && ((j + 1) & comma & (i + 1))
            put item 1 of tCell into r
            put item 2 of tCell into c
            put tCol[r][c] into tC
            if tC is empty then
               put 0 into tG
               put "none" & return after tSBs
            else
               put true into tAnyLive
               put item 1 of tC into tG
               if pMap["red"][r][c] > 0 then put true into tAnyRed
               if pMap["green"][r][c] > 0 and pMap["ceiling"][r][c] is 0 then put true into tAnyGreen
               if item 2 of tC is not empty then
                  if tRoofLo is empty or item 2 of tC < tRoofLo then put item 2 of tC into tRoofLo
                  if tRoofHi is empty or item 3 of tC > tRoofHi then put item 3 of tC into tRoofHi
                  if item 3 of tC > item 2 of tC then put true into tRoofThick
               end if
               if item 4 of tC is empty then
                  put "none" & return after tSBs
               else
                  put item 4 of tC & return after tSBs
               end if
            end if
            if tLo is empty or tG < tLo then put tG into tLo
            if tHi is empty or tG > tHi then put tG into tHi
         end repeat
         if tAnyLive then
            if tHi - tLo > 1 then
               if tAnyRed then
                  put "pit" into tClass
               else if tAnyGreen then
                  put "green" into tClass
               else
                  put "wall" into tClass
               end if
               put true into tUps[(i * 16) & comma & tLo & comma & (j * 16) & comma & (i * 16) & comma & tHi & comma & (j * 16) & comma & tClass]
            end if
            if tRoofLo is not empty then
               if tRoofHi > tRoofLo then
                  if tRoofThick then
                     put "green" into tClass
                  else
                     put "ceiling" into tClass
                  end if
                  put true into tUps[(i * 16) & comma & tRoofLo & comma & (j * 16) & comma & (i * 16) & comma & tRoofHi & comma & (j * 16) & comma & tClass]
               end if
            end if
            put empty into tDistinct
            repeat for each line k in tSBs
               put true into tDistinct[k]
            end repeat
            if the number of lines of the keys of tDistinct > 1 then
               repeat for each key k in tDistinct
                  if k is "none" then next repeat
                  put true into tUps[(i * 16) & comma & k & comma & (j * 16) & comma & (i * 16) & comma & (k + tSlab) & comma & (j * 16) & ",sky"]
               end repeat
            end if
         end if
         add 1 to i
      end repeat
      add 1 to j
   end repeat
   -- merge the runs, write everything out
   put the keys of tUps into tOut
   set the itemDel to "|"
   repeat for each key tKey in tFlat
      put tFlat[tKey] into tRuns
      delete the last char of tRuns
      put tKey into tParts
      set the itemDel to comma
      sort lines of tRuns ascending numeric by item 1 of each
      put empty into a
      repeat for each line tRun in tRuns
         if a is empty then
            put item 1 of tRun into a
            put item 2 of tRun into b
         else if item 1 of tRun <= b then
            put max(b, item 2 of tRun) into b
         else
            put return & cmRun(tParts, a, b) after tOut
            put item 1 of tRun into a
            put item 2 of tRun into b
         end if
      end repeat
      put return & cmRun(tParts, a, b) after tOut
      set the itemDel to "|"
   end repeat
   set the itemDel to comma
   if char 1 of tOut is return then delete char 1 of tOut
   sort lines of tOut
   return tOut
end CellMap.LevelSegments

private function cmRun pKey, pA, pB
   local tClass, tY, tAxis, tFixed
   set the itemDel to "|"
   put item 1 of pKey into tClass
   put item 2 of pKey into tY
   put item 3 of pKey into tAxis
   put item 4 of pKey into tFixed
   if tAxis is "x" then return pA & "," & tY & "," & tFixed & "," & pB & "," & tY & "," & tFixed & "," & tClass
   return tFixed & "," & tY & "," & pA & "," & tFixed & "," & tY & "," & pB & "," & tClass
end cmRun

-- a level segment in engine units, the map centred on 0,0, y up: "x1,y1,z1,x2,y2,z2,class"
function CellMap.SegToEngine pMap, pSeg
   local tCell, tHU, tHalfC, tHalfR, tBase
   put pMap["meta"]["cell"] into tCell
   put CellMap.HU(pMap) into tHU
   put pMap["meta"]["cols"] / 2 into tHalfC
   put pMap["meta"]["rows"] / 2 into tHalfR
   put CellMap.Opt(pMap, "base") into tBase
   return ((item 1 of pSeg / 16 - tHalfC) * tCell) & comma & ((item 2 of pSeg + tBase) * tHU) & comma & ((item 3 of pSeg / 16 - tHalfR) * tCell) & comma & \
         ((item 4 of pSeg / 16 - tHalfC) * tCell) & comma & ((item 5 of pSeg + tBase) * tHU) & comma & ((item 6 of pSeg / 16 - tHalfR) * tCell) & comma & item 7 of pSeg
end CellMap.SegToEngine
