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
## VERSION 3 (CELLMAP_V3.md): slopes and map packs.
##   tMap["slope"][row][col] = "nw,ne,se,sw": hu each corner of the cell's ground rises (absent: flat)
##   CellMap.Slope, SetSlope, Steep, RiseAt
##   a pack (a .cellpack file naming a level's maps; a plain .cellmap reads as a pack of one):
##   tPack["meta"][name|start]   tPack["count"]   tPack["problems"]
##   tPack["maps"][n][id|file|place|base|at|map|ox|oz]   tPack["doors"][n][from|type|to|note]
##   CellMap.ReadPack, PackToText, PackStandAt, PackWalk, PackDoors, PackEnter
## Level: CellMap.Levels, StandAt, Walk, LevelSegments (the same numbers as cellmap.py, tested).
## Tag table (data/tags_default.txt): CellMap.TagsFromText -> [code][char|name|colour|solid|height|group|effect]
## Font (fonts/*.font.txt): CellMap.FontFromText -> [code] = 16 row numbers; CellMap.Glyph -> 0/1 rows
######################################################################################

constant kB36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
constant kLayers2 = "floor,ceiling,red,green,blue"
constant kNoRoof = 9999
constant kOpenSky = 5000      -- air above this much is open sky (a slope or a raised glyph takes a little off 9999)

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
            "floor" & tab & "ceiling" & tab & "red" & tab & "green" & tab & "blue" & tab & "links" & tab & "objects" & tab & "stack" & tab & "slope") then
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
         case "slope"
            -- col,row <tab> nw ne se sw <tab> what (only ground; other words are for later)
            if tLine is empty then break
            put item 3 of tLine into tKey
            if tKey is not empty and tKey is not "ground" then break
            put item 1 of tLine into tVal
            put item 2 of tLine into tItems
            replace comma with space in tVal
            if the number of words of tVal is 2 and the number of words of tItems is 4 then
               put (word 1 of tItems + 0) & comma & (word 2 of tItems + 0) & comma & (word 3 of tItems + 0) & comma & (word 4 of tItems + 0) into tCode
               put tCode into tMap["slope"][word 2 of tVal + 0][word 1 of tVal + 0]
            end if
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
   if pMap["meta"]["version"] >= 3 then
      put "# cellmap " & pMap["meta"]["version"] & " - LIB_BIT/editor (format: editor/CELLMAP_V3.md)" & return & "[map]" & return into tOut
   else if tV2 then
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
      if pMap["slope"] is an array then
         put the keys of pMap["slope"] into tChars
         sort lines of tChars numeric
         put false into tAny
         repeat for each line r in tChars
            put the keys of pMap["slope"][r] into tLine
            sort lines of tLine numeric
            repeat for each line c in tLine
               if not tAny then put "[slope]" & return after tOut
               put true into tAny
               put pMap["slope"][r][c] into v
               replace comma with space in v
               put c & comma & r & tab & v & return after tOut
            end repeat
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
      case "steep"
         return 60
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
   if pMap["slope"][pRow][pCol] is not empty then return false
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
   if pMap["slope"][pRow][pCol] is not empty then return false
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

-------------------------------------------------------------------- version 3: slopes (CELLMAP_V3.md section 2)

-- a cell's slope "nw,ne,se,sw" (hu each corner of its ground rises); empty = flat
function CellMap.Slope pMap, pCol, pRow
   return pMap["slope"][pRow][pCol]
end CellMap.Slope

-- slope a cell (four rises 0-255, commas or spaces) or flatten it (empty or all zeros); the map becomes version 3
command CellMap.SetSlope @pMap, pCol, pRow, pRises
   local tR
   put pRises into tR
   replace comma with space in tR
   if the number of words of tR is 4 then
      if (word 1 of tR + word 2 of tR + word 3 of tR + word 4 of tR) > 0 then
         CellMap.Upgrade pMap
         put (word 1 of tR + 0) & comma & (word 2 of tR + 0) & comma & (word 3 of tR + 0) & comma & (word 4 of tR + 0) into pMap["slope"][pRow][pCol]
         if pMap["meta"]["version"] < 3 then put 3 into pMap["meta"]["version"]
         exit CellMap.SetSlope
      end if
   end if
   if pMap["slope"][pRow] is an array then
      delete variable pMap["slope"][pRow][pCol]
      if the keys of pMap["slope"][pRow] is empty then delete variable pMap["slope"][pRow]
   end if
end CellMap.SetSlope

-- the cell's slope is too steep to walk up: its corners differ by more than `steep` hu
function CellMap.Steep pMap, pCol, pRow
   local tS
   put pMap["slope"][pRow][pCol] into tS
   if tS is empty then return false
   return (max(tS) - min(tS) > CellMap.Opt(pMap, "steep"))
end CellMap.Steep

-- hu the sloped ground of a cell stands above the cell's ground under engine point pX,pZ
function CellMap.RiseAt pMap, pCol, pRow, pX, pZ
   local tS, u, v
   put pMap["slope"][pRow][pCol] into tS
   if tS is empty then return 0
   put min(1, max(0, pX / pMap["meta"]["cell"] + pMap["meta"]["cols"] / 2 - (pCol - 1))) into u
   put min(1, max(0, pZ / pMap["meta"]["cell"] + pMap["meta"]["rows"] / 2 - (pRow - 1))) into v
   return item 1 of tS * (1 - u) * (1 - v) + item 2 of tS * u * (1 - v) + item 3 of tS * u * v + item 4 of tS * (1 - u) * v
end CellMap.RiseAt

-- what stands under engine point pX,pZ of ONE map, in the map's own hu: empty over empty space, else
-- an array: levels (lines "top,air", lowest first; empty when a tag blocks), steep, under (the lowest
-- solid: a stacked map is a deck from here up to its ground), solid (the ground's top), col, row
private function cmPoint pMap, pTags, pFont, pX, pZ
   local tCell, tCol, tRow, tC, tShaped, tOpen, tP, tEffect, tLine, i, tTop, tAir, tUp
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
   put CellMap.Steep(pMap, tCol, tRow) into tP["steep"]
   put min(0, item 1 of tC) into tP["under"]
   put item 1 of tC into tP["solid"]
   put tCol into tP["col"]
   put tRow into tP["row"]
   put empty into tP["levels"]
   put CellMap.TagInfo(pMap, pTags, pMap["tags"][tRow][tCol], "effect") into tEffect
   if tEffect is "locked" or (tEffect is "block" and not tOpen) then return tP
   put 0 into i
   repeat for each line tLine in cmLevels(tC)
      add 1 to i
      put item 1 of tLine into tTop
      put item 2 of tLine into tAir
      if i is 1 then
         if pMap["slope"][tRow][tCol] is not empty then
            put CellMap.RiseAt(pMap, tCol, tRow, pX, pZ) into tUp
            add tUp to tTop
            subtract tUp from tAir
            put tTop into tP["solid"]
         else if pFont is an array and not tShaped then
            if CellMap.HasRelief(pMap, tCol, tRow) then
               if cmLit(pMap, pFont, tCol, tRow, pX, pZ) then
                  put CellMap.Opt(pMap, "relief") into tUp
                  add tUp to tTop
                  subtract tUp from tAir
               end if
            end if
         end if
      end if
      put tTop & comma & tAir & return after tP["levels"]
   end repeat
   delete the last char of tP["levels"]
   return tP
end cmPoint

-- the height (engine units, up) an actor now at height pY would stand at on point pX,pZ; empty =
-- it cannot: outside, empty space, a tag whose effect is block or locked, a rise over `step`,
-- less than `head` of air, or a roof between it and the level (a drop goes through air only).
-- pFont (may be empty) adds the raised glyphs. pCentre true (the actor's middle, not its rim):
-- no rise at all on a steep slope.
function CellMap.StandAt pMap, pTags, pFont, pX, pZ, pY, pCentre
   local tP, tYH, tBest, tLine, tTop, tAir, i, tRise, tStep, tHead
   put cmPoint(pMap, pTags, pFont, pX, pZ) into tP
   if tP is not an array then return empty
   if tP["levels"] is empty then return empty
   put pY / CellMap.HU(pMap) - CellMap.Opt(pMap, "base") into tYH
   put CellMap.Opt(pMap, "step") + 0.000001 into tStep
   put CellMap.Opt(pMap, "head") into tHead
   put empty into tBest
   put 0 into i
   repeat for each line tLine in tP["levels"]
      add 1 to i
      put item 1 of tLine into tTop
      put item 2 of tLine into tAir
      put tStep into tRise
      if pCentre is true and i is 1 and tP["steep"] then put 0.01 into tRise
      if tTop <= tYH + tRise and tAir >= tHead and (tAir >= kOpenSky or tYH <= tTop + tAir + 0.000001) then put tTop into tBest
   end repeat
   if tBest is empty then return empty
   return (tBest + CellMap.Opt(pMap, "base")) * CellMap.HU(pMap)
end CellMap.StandAt

-- the highest standing height at pX,pZ (engine units); empty over empty space
function CellMap.GroundAt pMap, pTags, pFont, pX, pZ
   return CellMap.StandAt(pMap, pTags, pFont, pX, pZ, 1000000000)
end CellMap.GroundAt

-- a circle of pRadius fits at pX,pZ for an actor at height pY: its new height, else empty.
-- With pFromX,pFromZ (where it stands now): a part of the rim already in a wall (after a drop
-- off a ledge) may stay in it, so the actor can walk away.
function CellMap.Fits pMap, pTags, pFont, pX, pZ, pY, pRadius, pFromX, pFromZ
   local ax, az
   repeat for each item ax in (-pRadius) & comma & pRadius
      repeat for each item az in (-pRadius) & comma & pRadius
         if CellMap.StandAt(pMap, pTags, pFont, pX + ax, pZ + az, pY) is empty then
            if pFromX is empty then return empty
            if CellMap.StandAt(pMap, pTags, pFont, pFromX + ax, pFromZ + az, pY) is not empty then return empty
         end if
      end repeat
   end repeat
   return CellMap.StandAt(pMap, pTags, pFont, pX, pZ, pY, true)
end CellMap.Fits

-- move an actor (a circle, radius 12 unless given) by pDX,pDZ, sliding along what blocks it:
-- "x,z,y,effect" (the effect of the tag of the cell it ends in; on a steep slope a `path` or
-- `none` cell answers `slide`)
function CellMap.Walk pMap, pTags, pFont, pX, pZ, pY, pDX, pDZ, pRadius
   local tTry, tNY, tCell, tEffect
   if pRadius is empty then put 12 into pRadius
   repeat for each line tTry in (pDX & comma & pDZ) & return & (pDX & comma & 0) & return & (0 & comma & pDZ)
      if item 1 of tTry is 0 and item 2 of tTry is 0 then next repeat
      put CellMap.Fits(pMap, pTags, pFont, pX + item 1 of tTry, pZ + item 2 of tTry, pY, pRadius, pX, pZ) into tNY
      if tNY is not empty then
         add item 1 of tTry to pX
         add item 2 of tTry to pZ
         put tNY into pY
         exit repeat
      end if
   end repeat
   put CellMap.CellAt(pMap, pX, pZ) into tCell
   put CellMap.TagInfo(pMap, pTags, pMap["tags"][item 2 of tCell][item 1 of tCell], "effect") into tEffect
   if tEffect is "path" or tEffect is "none" then
      if CellMap.Steep(pMap, item 1 of tCell, item 2 of tCell) then put "slide" into tEffect
   end if
   return pX & comma & pZ & comma & pY & comma & tEffect
end CellMap.Walk

-------------------------------------------------------------------- version 3: map packs (CELLMAP_V3.md section 4)

function CellMap.PackToText pPack
   local tOut, tKey, tKeys, i
   put "# cellpack 1 - LIB_BIT/editor (format: editor/CELLMAP_V3.md)" & return & "[pack]" & return into tOut
   repeat for each item tKey in "name,start"
      if tKey is among the keys of pPack["meta"] then put tKey & tab & pPack["meta"][tKey] & return after tOut
   end repeat
   put the keys of pPack["meta"] into tKeys
   sort lines of tKeys
   repeat for each line tKey in tKeys
      if tKey is not among the items of "name,start" then put tKey & tab & pPack["meta"][tKey] & return after tOut
   end repeat
   put "[maps]" & return after tOut
   put 1 into i
   repeat while i <= pPack["count"]
      put pPack["maps"][i]["id"] & tab & pPack["maps"][i]["file"] & tab & pPack["maps"][i]["place"] & tab & \
            pPack["maps"][i]["base"] & tab & pPack["maps"][i]["at"] & return after tOut
      add 1 to i
   end repeat
   if CellMap.Count(pPack["doors"]) > 0 then
      put "[doors]" & return after tOut
      put 1 into i
      repeat while i <= CellMap.Count(pPack["doors"])
         put pPack["doors"][i]["from"] & tab & pPack["doors"][i]["type"] & tab & pPack["doors"][i]["to"] & tab & pPack["doors"][i]["note"] & return after tOut
         add 1 to i
      end repeat
   end if
   return tOut
end CellMap.PackToText

-- a .cellpack file as an array (see the top of this script). Map files are named from the pack's
-- own folder (never a full path, never ..). A plain .cellmap reads as a pack of one map (id = its
-- name), its [stack] lines as the maps over it. What is wrong is listed in tPack["problems"].
function CellMap.ReadPack pPath
   local tPack, tFolder, tMap, n, d, i, tLine, tSec, tFile, tFirst, tG, tAt, tAC, tAR, tGC, tGR, tCell, tIds, tEnd, tKey
   put pPath into tPack["path"]
   put empty into tPack["problems"]
   set the itemDel to "/"
   put item 1 to -2 of pPath into tFolder
   put 0 into n
   put 0 into d
   if pPath ends with ".cellmap" then
      put CellMap.Read(pPath) into tMap
      put tMap["meta"]["name"] into tKey
      if tKey is empty then put "map" into tKey
      put tKey into tPack["meta"]["name"]
      put tKey into tPack["meta"]["start"]
      put 1 into n
      put tKey into tPack["maps"][1]["id"]
      put item -1 of pPath into tPack["maps"][1]["file"]
      put "main" into tPack["maps"][1]["place"]
      put CellMap.Opt(tMap, "base") into tPack["maps"][1]["base"]
      put "1,1" into tPack["maps"][1]["at"]
      put 1 into i
      repeat while i <= CellMap.Count(tMap["stack"])
         add 1 to n
         put "stack" & i into tPack["maps"][n]["id"]
         put tMap["stack"][i]["file"] into tPack["maps"][n]["file"]
         put "main" into tPack["maps"][n]["place"]
         put tMap["stack"][i]["base"] into tPack["maps"][n]["base"]
         put tMap["stack"][i]["at"] into tPack["maps"][n]["at"]
         add 1 to i
      end repeat
   else
      set the itemDel to tab
      repeat for each line tLine in CellMap.ReadText(pPath)
         if tLine is empty or char 1 of tLine is "#" then next repeat
         if tLine is "[pack]" or tLine is "[maps]" or tLine is "[doors]" then
            put char 2 to -2 of tLine into tSec
            next repeat
         end if
         switch tSec
            case "pack"
               if the number of items of tLine > 1 then
                  put item 1 of tLine into tKey
                  put item 2 of tLine into tPack["meta"][tKey]
               end if
               break
            case "maps"
               add 1 to n
               put item 1 of tLine into tPack["maps"][n]["id"]
               put item 2 of tLine into tPack["maps"][n]["file"]
               put item 3 of tLine into tPack["maps"][n]["place"]
               put item 4 of tLine into tPack["maps"][n]["base"]
               put item 5 of tLine into tPack["maps"][n]["at"]
               if tPack["maps"][n]["place"] is empty then put "main" into tPack["maps"][n]["place"]
               if tPack["maps"][n]["base"] is empty then put 0 into tPack["maps"][n]["base"]
               if tPack["maps"][n]["at"] is empty then put "1,1" into tPack["maps"][n]["at"]
               break
            case "doors"
               add 1 to d
               put item 1 of tLine into tPack["doors"][d]["from"]
               put item 2 of tLine into tPack["doors"][d]["type"]
               put item 3 of tLine into tPack["doors"][d]["to"]
               put item 4 of tLine into tPack["doors"][d]["note"]
               break
         end switch
      end repeat
   end if
   put n into tPack["count"]
   set the itemDel to comma
   put 1 into i
   repeat while i <= n
      put 0 into tPack["maps"][i]["ox"]
      put 0 into tPack["maps"][i]["oz"]
      put tPack["maps"][i]["id"] & return after tIds
      put tPack["maps"][i]["file"] into tFile
      replace "\" with "/" in tFile
      add 1 to i
      if char 1 of tFile is "/" or tFile contains ":" or ("/" & tFile & "/") contains "/../" then
         put tPack["maps"][i - 1]["id"] & ": the file must be inside the pack's folder: " & tFile & return after tPack["problems"]
         next repeat
      end if
      if there is not a file (tFolder & "/" & tFile) then
         put tPack["maps"][i - 1]["id"] & ": no file " & tFile & return after tPack["problems"]
         next repeat
      end if
      put CellMap.Read(tFolder & "/" & tFile) into tMap
      CellMap.Upgrade tMap
      put tPack["maps"][i - 1]["base"] into tMap["meta"]["base"]      -- the pack places the map
      put tMap into tPack["maps"][i - 1]["map"]
      put tPack["maps"][i - 1]["place"] into tKey
      if tFirst[tKey] is empty then put i - 1 into tFirst[tKey]       -- a place's first map is centred on 0,0
      put tFirst[tKey] into tG
      put tPack["maps"][i - 1]["at"] into tAt
      put item 1 of tAt into tAC
      put item 2 of tAt into tAR
      put tPack["maps"][tG]["at"] into tAt
      put item 1 of tAt into tGC
      put item 2 of tAt into tGR
      put tPack["maps"][tG]["map"]["meta"]["cell"] into tCell
      put (tAC - tGC + tMap["meta"]["cols"] / 2 - tPack["maps"][tG]["map"]["meta"]["cols"] / 2) * tCell into tPack["maps"][i - 1]["ox"]
      put (tAR - tGR + tMap["meta"]["rows"] / 2 - tPack["maps"][tG]["map"]["meta"]["rows"] / 2) * tCell into tPack["maps"][i - 1]["oz"]
      if tMap["meta"]["cell"] is not tCell or tMap["meta"]["wallH"] is not tPack["maps"][tG]["map"]["meta"]["wallH"] then
         put tPack["maps"][i - 1]["id"] & ": cell and wallH differ from " & tPack["maps"][tG]["id"] & " in the same place" & return after tPack["problems"]
      end if
   end repeat
   set the itemDel to ":"
   put 1 into i
   repeat while i <= d
      repeat for each word tKey in "from to"
         put tPack["doors"][i][tKey] into tEnd
         if item 1 of tEnd is not among the lines of tIds then
            put "door " & tPack["doors"][i]["from"] & " -> " & tPack["doors"][i]["to"] & ": no map " & item 1 of tEnd & return after tPack["problems"]
         end if
      end repeat
      add 1 to i
   end repeat
   return tPack
end CellMap.ReadPack

-- the number of a map in a pack by its id (0 = none)
function CellMap.PackIndex pPack, pId
   local i
   put 1 into i
   repeat while i <= pPack["count"]
      if pPack["maps"][i]["id"] is pId then return i
      add 1 to i
   end repeat
   return 0
end CellMap.PackIndex

-- CellMap.StandAt over every map stacked in a place: "height (engine units),map id", or empty.
-- Each map offers its levels; another map's solid above a level is its roof.
function CellMap.PackStandAt pPack, pPlace, pTags, pFont, pX, pZ, pY, pCentre
   local i, tG, tK, tStep, tHead, tCount, tPts, tP, tYH, tBest, tBestId, j, k, tLine, tTop, tAir, tLo, tHi, tRise, tLv
   put 0 into tCount
   put 1 into i
   repeat while i <= pPack["count"]
      if pPack["maps"][i]["place"] is pPlace and pPack["maps"][i]["map"] is an array then
         if tG is empty then put i into tG
         put cmPoint(pPack["maps"][i]["map"], pTags, pFont, pX - pPack["maps"][i]["ox"], pZ - pPack["maps"][i]["oz"]) into tP
         if tP is an array then
            add 1 to tCount
            put tP into tPts[tCount]
            put pPack["maps"][i]["id"] into tPts[tCount]["id"]
            put pPack["maps"][i]["base"] into tPts[tCount]["base"]
         end if
      end if
      add 1 to i
   end repeat
   if tG is empty then return empty
   put CellMap.HU(pPack["maps"][tG]["map"]) into tK
   put CellMap.Opt(pPack["maps"][tG]["map"], "step") + 0.000001 into tStep
   put CellMap.Opt(pPack["maps"][tG]["map"], "head") into tHead
   put pY / tK into tYH
   put empty into tBest
   put 1 into j
   repeat while j <= tCount
      put 0 into tLv
      repeat for each line tLine in tPts[j]["levels"]
         add 1 to tLv
         put item 1 of tLine + tPts[j]["base"] into tTop
         put item 2 of tLine into tAir
         put 1 into k
         repeat while k <= tCount
            if k is not j then
               put tPts[k]["base"] + tPts[k]["under"] into tLo
               put tPts[k]["base"] + tPts[k]["solid"] into tHi
               if tLo >= tTop - 0.000001 then
                  put min(tAir, tLo - tTop) into tAir
               else if tHi > tTop + 0.000001 then
                  put 0 into tAir          -- inside the other map's solid
               end if
            end if
            add 1 to k
         end repeat
         put tStep into tRise
         if pCentre is true and tLv is 1 and tPts[j]["steep"] then put 0.01 into tRise
         if tTop <= tYH + tRise and tAir >= tHead and (tAir >= kOpenSky or tYH <= tTop + tAir + 0.000001) then
            if tBest is empty or tTop > tBest then
               put tTop into tBest
               put tPts[j]["id"] into tBestId
            end if
         end if
      end repeat
      add 1 to j
   end repeat
   if tBest is empty then return empty
   return (tBest * tK) & comma & tBestId
end CellMap.PackStandAt

private function cmPackFits pPack, pPlace, pTags, pFont, pX, pZ, pY, pRadius, pFromX, pFromZ
   local ax, az
   repeat for each item ax in (-pRadius) & comma & pRadius
      repeat for each item az in (-pRadius) & comma & pRadius
         if CellMap.PackStandAt(pPack, pPlace, pTags, pFont, pX + ax, pZ + az, pY) is empty then
            if CellMap.PackStandAt(pPack, pPlace, pTags, pFont, pFromX + ax, pFromZ + az, pY) is not empty then return empty
         end if
      end repeat
   end repeat
   return CellMap.PackStandAt(pPack, pPlace, pTags, pFont, pX, pZ, pY, true)
end cmPackFits

-- CellMap.Walk over the maps stacked in a place: "x,z,y,effect,map id,col,row" (the cell stood on,
-- in its own map). Stairs, holes and ledges between the maps need nothing more than their heights.
function CellMap.PackWalk pPack, pPlace, pTags, pFont, pX, pZ, pY, pDX, pDZ, pRadius
   local tTry, tGot, tOn, i, tCell, tEffect
   if pRadius is empty then put 12 into pRadius
   put CellMap.PackStandAt(pPack, pPlace, pTags, pFont, pX, pZ, pY + 0.001, true) into tOn
   repeat for each line tTry in (pDX & comma & pDZ) & return & (pDX & comma & 0) & return & (0 & comma & pDZ)
      if item 1 of tTry is 0 and item 2 of tTry is 0 then next repeat
      put cmPackFits(pPack, pPlace, pTags, pFont, pX + item 1 of tTry, pZ + item 2 of tTry, pY, pRadius, pX, pZ) into tGot
      if tGot is not empty then
         add item 1 of tTry to pX
         add item 2 of tTry to pZ
         put item 1 of tGot into pY
         put tGot into tOn
         exit repeat
      end if
   end repeat
   if tOn is empty then return pX & comma & pZ & comma & pY & ",none,,0,0"
   put CellMap.PackIndex(pPack, item 2 of tOn) into i
   put CellMap.CellAt(pPack["maps"][i]["map"], pX - pPack["maps"][i]["ox"], pZ - pPack["maps"][i]["oz"]) into tCell
   put CellMap.TagInfo(pPack["maps"][i]["map"], pTags, pPack["maps"][i]["map"]["tags"][item 2 of tCell][item 1 of tCell], "effect") into tEffect
   if tEffect is "path" or tEffect is "none" then
      if CellMap.Steep(pPack["maps"][i]["map"], item 1 of tCell, item 2 of tCell) then put "slide" into tEffect
   end if
   return pX & comma & pZ & comma & pY & comma & tEffect & comma & item 2 of tOn & comma & tCell
end CellMap.PackWalk

-- the doors leaving a cell: lines "type <tab> to <tab> note" (to = "map:col,row")
function CellMap.PackDoors pPack, pMapId, pCol, pRow
   local i, tOut
   put 1 into i
   repeat while i <= CellMap.Count(pPack["doors"])
      if pPack["doors"][i]["from"] is (pMapId & ":" & pCol & comma & pRow) then
         put pPack["doors"][i]["type"] & tab & pPack["doors"][i]["to"] & tab & pPack["doors"][i]["note"] & return after tOut
      end if
      add 1 to i
   end repeat
   delete the last char of tOut
   return tOut
end CellMap.PackDoors

-- arrive at "map:col,row" (a door's `to`; empty = the pack's start map, on its @ cell):
-- "place,x,z,y" in engine units, in the middle of the cell; empty when nobody can stand there
function CellMap.PackEnter pPack, pTags, pFont, pWhere
   local i, tCol, tRow, r, c, tAt, tX, tZ, tP
   if pWhere is empty then
      put CellMap.PackIndex(pPack, pPack["meta"]["start"]) into i
      if i is 0 then put 1 into i
      if pPack["maps"][i]["map"] is not an array then return empty
      put 1 into tCol
      put 1 into tRow
      put 1 into r
      repeat while r <= pPack["maps"][i]["map"]["meta"]["rows"]
         put 1 into c
         repeat while c <= pPack["maps"][i]["map"]["meta"]["cols"]
            if pPack["maps"][i]["map"]["tags"][r][c] is "@" then
               put c into tCol
               put r into tRow
               put 1000000 into r
               exit repeat
            end if
            add 1 to c
         end repeat
         add 1 to r
      end repeat
   else
      set the itemDel to ":"
      put CellMap.PackIndex(pPack, item 1 of pWhere) into i
      if i is 0 then return empty
      if pPack["maps"][i]["map"] is not an array then return empty
      put item 2 of pWhere into tAt
      set the itemDel to comma
      put item 1 of tAt into tCol
      put item 2 of tAt into tRow
   end if
   set the itemDel to comma
   put CellMap.CellX(pPack["maps"][i]["map"], tCol) into tX
   put CellMap.CellZ(pPack["maps"][i]["map"], tRow) into tZ
   put cmPoint(pPack["maps"][i]["map"], pTags, pFont, tX, tZ) into tP
   if tP is not an array then return empty
   if tP["levels"] is empty then return empty
   put line 1 of tP["levels"] into tAt
   return pPack["maps"][i]["place"] & comma & (tX + pPack["maps"][i]["ox"]) & comma & (tZ + pPack["maps"][i]["oz"]) & comma & \
         ((item 1 of tAt + pPack["maps"][i]["base"]) * CellMap.HU(pPack["maps"][i]["map"]))
end CellMap.PackEnter

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

-- the ground's four corner heights "nw,ne,se,sw" of a cell whose column is pC (CELLMAP_V3.md 2);
-- a glyph-shaped cell (pShaped not empty) and a flat cell have all four at its ground
private function cmCorners pMap, pC, pShaped, pCol, pRow
   local tG, tS
   put item 1 of pC into tG
   put pMap["slope"][pRow][pCol] into tS
   if tS is empty or pShaped is not empty then return tG & comma & tG & comma & tG & comma & tG
   return (tG + item 1 of tS) & comma & (tG + item 2 of tS) & comma & (tG + item 3 of tS) & comma & (tG + item 4 of tS)
end cmCorners

-- the two corner heights of one side, in the order the side runs (west to east, north to south)
private function cmSideH pK4, pSide
   switch pSide
      case "n"
         return item 1 of pK4 & comma & item 2 of pK4
      case "e"
         return item 2 of pK4 & comma & item 3 of pK4
      case "s"
         return item 4 of pK4 & comma & item 3 of pK4
   end switch
   return item 1 of pK4 & comma & item 4 of pK4
end cmSideH

-- the map as line segments, one a line: "x1,y1,z1,x2,y2,z2,class". x and z in sixteenths of a
-- cell from the map's north-west corner (x east, z south), y in hu (up). Classes: floor, wall,
-- pit, water, ceiling, green, sky, relief. Rules: CELLMAP_V2.md section 6. Runs along a row or
-- column are merged. pFont empty: no relief. CellMap.SegToEngine scales one for an engine.
function CellMap.LevelSegments pMap, pTags, pFont
   local tRows, tCols, tSlab, tRelief, tFlat, tUps, tCol, r, c, tC, tN, tGround, tRB, tRT, tSB, tST
   local tSide, dr, dc, tWater, tBase, tClass, f, tEdge, y, i, j, tAround, tCells, tCell, k, tLo, tHi
   local tShape, tX, tZ, tK4, tSideH, tNextH, tFace, tX1, tZ1, tX2, tZ2, tHiK
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
         put cmCorners(pMap, tC, tShape[r][c], c, r) into tK4
         repeat for each word tSide in "n,-1,0,s e,0,1,w s,1,0,n w,0,-1,e"
            put item 2 of tSide into dr
            put item 3 of tSide into dc
            put item 4 of tSide into tFace
            put item 1 of tSide into tSide
            put r + dr into tNR
            put c + dc into tNC
            put tCol[tNR][tNC] into tN          -- empty outside the map too
            put cmSideH(tK4, tSide) into tSideH
            put tBase into tClass
            if tN is not empty then
               put cmSideH(cmCorners(pMap, tN, tShape[tNR][tNC], tNC, tNR), tFace) into tNextH
               if item 1 of tNextH is item 1 of tSideH and item 2 of tNextH is item 2 of tSideH then put "floor" into tClass
            end if
            if item 1 of tSideH is item 2 of tSideH then
               cmEdge tFlat, tClass, item 1 of tSideH, c - 1, r - 1, tSide
            else
               -- a sloped ground edge runs corner to corner
               put (c - 1) * 16 into tX1
               if tSide is "e" then add 16 to tX1
               put (r - 1) * 16 into tZ1
               if tSide is "s" then add 16 to tZ1
               if tSide is "n" or tSide is "s" then
                  put tX1 + 16 into tX2
                  put tZ1 into tZ2
               else
                  put tX1 into tX2
                  put tZ1 + 16 into tZ2
               end if
               put true into tUps[tX1 & comma & item 1 of tSideH & comma & tZ1 & comma & tX2 & comma & item 2 of tSideH & comma & tZ2 & comma & tClass]
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
         if item 1 of tK4 + item 3 of tK4 is not item 2 of tK4 + item 4 of tK4 then
            -- a twisted cell: its diagonal, through the highest corner
            put 1 into tHiK
            repeat with k = 2 to 4
               if item k of tK4 > item tHiK of tK4 then put k into tHiK
            end repeat
            if tHiK is 1 or tHiK is 3 then
               put true into tUps[((c - 1) * 16) & comma & item 1 of tK4 & comma & ((r - 1) * 16) & comma & (c * 16) & comma & item 3 of tK4 & comma & (r * 16) & ",floor"]
            else
               put true into tUps[((c - 1) * 16) & comma & item 4 of tK4 & comma & (r * 16) & comma & (c * 16) & comma & item 2 of tK4 & comma & ((r - 1) * 16) & ",floor"]
            end if
         end if
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
         repeat for each word tCell in (j & comma & i & ",3") && (j & comma & (i + 1) & ",4") && ((j + 1) & comma & i & ",2") && ((j + 1) & comma & (i + 1) & ",1")
            put item 1 of tCell into r
            put item 2 of tCell into c
            put tCol[r][c] into tC
            if tC is empty then
               put 0 into tG
               put "none" & return after tSBs
            else
               put true into tAnyLive
               -- the corner of this cell that touches grid corner i,j (se, sw, ne, nw)
               put item (item 3 of tCell) of cmCorners(pMap, tC, tShape[r][c], c, r) into tG
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

-- every map of one place drawn together (CELLMAP_V3.md 3, 4): CellMap.LevelSegments of each, moved by
-- its ox, oz and the pack's base. Engine units, y up, one a line: "x1,y1,z1,x2,y2,z2,class,map id",
-- in the pack's order, each map's lines sorted. Python: pack_segments()
function CellMap.PackSegments pPack, pPlace, pTags, pFont
   local i, tMap, tCell, tHU, tHalfC, tHalfR, tOX, tOZ, tBase, tSeg, tOut, tId
   put 1 into i
   repeat while i <= pPack["count"]
      if pPack["maps"][i]["place"] is pPlace and pPack["maps"][i]["map"] is an array then
         put pPack["maps"][i]["map"] into tMap
         put tMap["meta"]["cell"] into tCell
         put CellMap.HU(tMap) into tHU
         put tMap["meta"]["cols"] / 2 into tHalfC
         put tMap["meta"]["rows"] / 2 into tHalfR
         put pPack["maps"][i]["ox"] into tOX
         put pPack["maps"][i]["oz"] into tOZ
         put pPack["maps"][i]["base"] into tBase
         put pPack["maps"][i]["id"] into tId
         repeat for each line tSeg in CellMap.LevelSegments(tMap, pTags, pFont)
            put ((item 1 of tSeg / 16 - tHalfC) * tCell + tOX) & comma & ((item 2 of tSeg + tBase) * tHU) & comma & ((item 3 of tSeg / 16 - tHalfR) * tCell + tOZ) & comma & \
                  ((item 4 of tSeg / 16 - tHalfC) * tCell + tOX) & comma & ((item 5 of tSeg + tBase) * tHU) & comma & ((item 6 of tSeg / 16 - tHalfR) * tCell + tOZ) & comma & \
                  item 7 of tSeg & comma & tId & return after tOut
         end repeat
      end if
      add 1 to i
   end repeat
   delete the last char of tOut
   return tOut
end CellMap.PackSegments
