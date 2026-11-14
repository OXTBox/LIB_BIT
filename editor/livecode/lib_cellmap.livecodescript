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
## Tag table (data/tags_default.txt): CellMap.TagsFromText -> [code][char|name|colour|solid|height|group|effect]
## Font (fonts/*.font.txt): CellMap.FontFromText -> [code] = 16 row numbers; CellMap.Glyph -> 0/1 rows
######################################################################################

constant kB36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

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
   return pMap[pWhich][pRow][pCol]
end CellMap.Get

command CellMap.Set @pMap, pWhich, pCol, pRow, pValue
   if pCol < 1 or pRow < 1 or pCol > pMap["meta"]["cols"] or pRow > pMap["meta"]["rows"] then exit CellMap.Set
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
            put char (v + 1) of kB36 after tLine
         else
            put v after tLine
         end if
         add 1 to c
      end repeat
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
            char 2 to -2 of tLine is among the items of ("map" & tab & "design" & tab & "design hex" & tab & "tags" & tab & "heights" & tab & "tagdefs") then
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
   put 1 into tRow
   repeat while tRow <= tMap["meta"]["rows"]
      put 1 into c
      repeat while c <= tMap["meta"]["cols"]
         if tMap["design"][tRow][c] is empty then put 32 into tMap["design"][tRow][c]
         if tMap["tags"][tRow][c] is empty then put space into tMap["tags"][tRow][c]
         if tMap["heights"][tRow][c] is empty then put 0 into tMap["heights"][tRow][c]
         add 1 to c
      end repeat
      add 1 to tRow
   end repeat
   return tMap
end CellMap.FromText

-- meta keys are written in this order first, then any others (sorted)
function CellMap.ToText pMap
   local tOut, tKey, tKeys, tHex, r, c, v, tLine, tChars
   put "# cellmap 1 - LIB_BIT/editor (format: editor/README.md)" & return & "[map]" & return into tOut
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
   put "[heights]" & return & CellMap.LayerText(pMap, "heights") & return after tOut
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
