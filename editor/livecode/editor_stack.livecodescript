######################################################################################
## STACK SCRIPT: "BitEditor"  (LIB_BIT/editor, 11 14 2026)
## The 1-bit to 3D editor: draw a glyph (16 x 16 bits) for any of the 256 codes, paint
## codes into a map grid, tag the cells, set their heights. The map and the font are plain
## text files (cellmap format: editor/README.md); lib_cellmap and lib_bit do the data.
## Built by build_editor.livecodescript; this text is the stack script it sets.
## Not connected to Vibecode3D or xt3d yet, on purpose (owner, 11 14 2026).
##
## LEFT    the 256 codes in their tag colours; Filter narrows the list; click = select
## MIDDLE  the drawing board (click or drag to flip bits); quick functions under it
## LEFT    the glyph palette: all 256 glyphs of the map's font (Aquarius by default); click = select
## RIGHT   1bit / Cells / Vibe / xt3D tabs. 1bit = the whole map as ONE 1-bit picture of its
##         glyphs (owner, 11 14 2026): click or drag paints the selected glyph (design only),
##         right-click picks. Cells = the coloured cell grid (tags, design, heights views).
##         A ghost of the selected glyph follows the mouse over the map, snapped to the cell
##         it would paint, drawn exactly as it will look (owner, 11 14 2026).
## MENUS   File  Bit  Grid  Mesh  Scene  Tiles  View (palette, map and ghost strength)
######################################################################################

local sDir, sMap, sMapPath, sTags, sFont, sFontPath, sCode, sMode, sView, sExtrude
local sDirtyMap, sDirtyFont, sBoardPaint, sCellPx, sLastCell, sScale1, sOneBitLast, sTab, sGhostOn

constant kBG = "30,30,34"
constant kPanel = "42,42,48"
constant kText = "220,220,224"
constant kOff = "48,48,56"
constant kBoardPx = 18
constant kMapW = 560
constant kMapH = 520

-------------------------------------------------------------------- start

on openStack
   Ed.Init
end openStack

on Ed.Init
   local tPath
   put the effective filename of this stack into tPath
   set the itemDel to "/"
   put item 1 to -2 of tPath into sDir                 -- .../LIB_BIT/editor
   if there is not a file (sDir & "/livecode/lib_cellmap.livecodescript") then
      answer "BitEditor: keep this stack in LIB_BIT/editor (lib_cellmap not found next to it)."
      exit Ed.Init
   end if
   Ed.UseLib sDir & "/livecode/lib_cellmap.livecodescript"
   Ed.UseLib item 1 to -2 of sDir & "/livecode/lib_bit.livecodescript"
   put "all" into sMode
   put "tags" into sView
   put "tag" into sExtrude
   put true into sGhostOn
   -- the palette softer than full white (owner: "that harsh white is too intense"); View menu changes it
   set the blendLevel of image "Palette" to 45
   put CellMap.TagsFromText(CellMap.ReadText(sDir & "/data/tags_default.txt")) into sTags
   Ed.OpenMap sDir & "/maps/amazing_couple.cellmap"
   Ed.FillList
   Ed.SelectCode 35
   Ed.ShowTab "1bit"
end Ed.Init

on Ed.UseLib pPath
   if there is a file pPath then start using stack pPath
end Ed.UseLib

-------------------------------------------------------------------- files

on Ed.OpenMap pPath
   put CellMap.Read(pPath) into sMap
   put pPath into sMapPath
   Ed.LoadFont sMap["meta"]["font"]
   put false into sDirtyMap
   Ed.BuildMapView
   Ed.DrawPalette
   Ed.DrawOneBit
   Ed.Status "opened" && Ed.ShortName(pPath)
end Ed.OpenMap

on Ed.LoadFont pName
   put sDir & "/fonts/" & pName & ".font.txt" into sFontPath
   if there is a file sFontPath then
      put CellMap.FontFromText(CellMap.ReadText(sFontPath)) into sFont
   else
      put empty into sFont
      put pName into sFont["meta"]["name"]
      put 16 into sFont["meta"]["size"]
   end if
   put false into sDirtyFont
end Ed.LoadFont

on Ed.SaveMap pPath
   if pPath is empty then put sMapPath into pPath
   CellMap.Write sMap, pPath
   put pPath into sMapPath
   put false into sDirtyMap
   Ed.Status "saved" && Ed.ShortName(pPath)
end Ed.SaveMap

on Ed.SaveFont
   put textEncode(CellMap.FontToText(sFont), "UTF-8") into URL ("binfile:" & sFontPath)
   put false into sDirtyFont
   Ed.Status "saved font" && Ed.ShortName(sFontPath)
end Ed.SaveFont

function Ed.ShortName pPath
   set the itemDel to "/"
   return item -1 of pPath
end Ed.ShortName

-------------------------------------------------------------------- the code list (left)

on Ed.FillList
   local tOut, tCode, tLine, tFilter, tN, tCodes
   put field "Filter" into tFilter
   put 0 into tCode
   repeat while tCode <= 255
      put format("%03d", tCode) & "  " & Ed.CharShown(tCode) & "  " & sTags[tCode]["name"] into tLine
      if tFilter is empty or tFilter is in tLine then
         put tLine & return after tOut
         put tCode & return after tCodes
      end if
      add 1 to tCode
   end repeat
   delete the last char of tOut
   lock screen
   put tOut into field "Codes"
   put 1 into tN
   repeat for each line tCode in tCodes
      set the textColor of line tN of field "Codes" to Ed.RGB(sTags[tCode]["colour"])
      add 1 to tN
   end repeat
   unlock screen
end Ed.FillList

function Ed.CharShown pCode
   if (pCode >= 33 and pCode <= 126) or (pCode >= 161 and pCode <= 255) then return numToCodepoint(pCode)
   if pCode is 32 then return "_"
   return "."
end Ed.CharShown

on Ed.ListClicked
   local tLine
   put the value of the clickLine into tLine
   if word 1 of tLine is an integer then Ed.SelectCode word 1 of tLine + 0
end Ed.ListClicked

on Ed.SelectCode pCode
   put pCode into sCode
   Ed.DrawGlyph
   Ed.ShowInfo
   Ed.PalSelect
   Ed.MakeGhost
end Ed.SelectCode

-------------------------------------------------------------------- the ghost (preview before painting)

-- the selected glyph at the map's scale, light on dark, exactly as it would be painted
on Ed.MakeGhost
   local tOne
   if there is not an image "Ghost" or sScale1 is not an integer then exit Ed.MakeGhost
   put 1 into tOne["meta"]["cols"]
   put 1 into tOne["meta"]["rows"]
   put sCode into tOne["design"][1][1]
   set the text of image "Ghost" to Bit.ToPBM(CellMap.OneBitGrid(tOne, sFont, sScale1, true))
end Ed.MakeGhost

-- over the 1bit map: the ghost sits on the cell under the mouse; anywhere else it hides
on Ed.GhostMove
   local tCell, tL, tT, tPx
   put empty into tCell
   -- only while the mouse is over this window's map (leaving the window hides it too)
   if sGhostOn and sTab is "1bit" and the visible of image "OneBit" and the mouseStack is the short name of this stack then put Ed.OneBitCell() into tCell
   if tCell is empty then
      if the visible of image "Ghost" then
         set the visible of image "Ghost" to false
         set the visible of graphic "GhostBox" to false
      end if
      exit Ed.GhostMove
   end if
   put 16 * sScale1 into tPx
   put the left of image "OneBit" + (item 1 of tCell - 1) * tPx into tL
   put the top of image "OneBit" + (item 2 of tCell - 1) * tPx into tT
   lock screen
   set the rect of image "Ghost" to tL, tT, tL + tPx, tT + tPx
   set the rect of graphic "GhostBox" to tL - 1, tT - 1, tL + tPx + 1, tT + tPx + 1
   set the visible of image "Ghost" to true
   set the visible of graphic "GhostBox" to true
   unlock screen
end Ed.GhostMove

-- View menu: how strong the palette, the map and the ghost look ("Palette: 55%" -> blendLevel 45)
on Ed.ViewMenu pItem
   local tWhat, tPct
   put word 1 of pItem into tWhat
   replace ":" with empty in tWhat
   if pItem is "Ghost: Off" then
      put false into sGhostOn
      Ed.GhostMove
      Ed.Status "ghost preview off"
      exit Ed.ViewMenu
   end if
   put word 2 of pItem into tPct
   replace "%" with empty in tPct
   if tPct is not a number then exit Ed.ViewMenu
   switch tWhat
      case "Palette"
         set the blendLevel of image "Palette" to 100 - tPct
         break
      case "Map"
         set the blendLevel of image "OneBit" to 100 - tPct
         break
      case "Ghost"
         put true into sGhostOn
         set the blendLevel of image "Ghost" to 100 - tPct
         break
   end switch
   Ed.Status tWhat && tPct & "%"
end Ed.ViewMenu

-------------------------------------------------------------------- the glyph palette (left, top)

-- all 256 glyphs as one 1-bit picture, 16 a row, light on dark (codes 0-15 on the top row)
on Ed.DrawPalette
   local tPal, r, c
   put 16 into tPal["meta"]["cols"]
   put 16 into tPal["meta"]["rows"]
   put 1 into r
   repeat while r <= 16
      put 1 into c
      repeat while c <= 16
         put (r - 1) * 16 + (c - 1) into tPal["design"][r][c]
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   lock screen
   set the text of image "Palette" to Bit.ToPBM(CellMap.OneBitGrid(tPal, sFont, 1, true))
   set the rect of image "Palette" to 8, 34, 264, 290
   Ed.PalSelect
   unlock screen
end Ed.DrawPalette

on Ed.PalSelect
   local tL, tT
   if there is not a graphic "PalSel" then exit Ed.PalSelect
   put the left of image "Palette" + (sCode mod 16) * 16 into tL
   put the top of image "Palette" + (sCode div 16) * 16 into tT
   set the rect of graphic "PalSel" to tL - 1, tT - 1, tL + 17, tT + 17
end Ed.PalSelect

on Ed.PaletteDown
   local tX, tY
   put the mouseH - the left of image "Palette" into tX
   put the mouseV - the top of image "Palette" into tY
   if tX < 0 or tY < 0 or tX >= 256 or tY >= 256 then exit Ed.PaletteDown
   Ed.SelectCode (tY div 16) * 16 + (tX div 16)
   Ed.Status "glyph" && sCode && "(" & Ed.CharShown(sCode) & ")" && sTags[sCode]["name"]
end Ed.PaletteDown

-------------------------------------------------------------------- the 1bit view (right): one big picture

-- the whole map as one 1-bit picture of its design glyphs, as big as fits
on Ed.DrawOneBit
   local tW, tH
   if there is not an image "OneBit" then exit Ed.DrawOneBit
   put sMap["meta"]["cols"] * 16 into tW
   put sMap["meta"]["rows"] * 16 into tH
   put max(1, min(566 div tW, 546 div tH)) into sScale1
   lock screen
   set the text of image "OneBit" to Bit.ToPBM(CellMap.OneBitGrid(sMap, sFont, sScale1, true))
   set the rect of image "OneBit" to 594, 64, 594 + tW * sScale1, 64 + tH * sScale1
   unlock screen
   if the uGhostScale of image "Ghost" is not sScale1 then
      set the uGhostScale of image "Ghost" to sScale1
      Ed.MakeGhost
   end if
end Ed.DrawOneBit

-- click: paint the selected glyph into the cell (design only); right-click: pick its glyph
on Ed.OneBitDown pButton
   local tCell
   put Ed.OneBitCell() into tCell
   if tCell is empty then exit Ed.OneBitDown
   if pButton is 3 or the optionKey is down then
      Ed.SelectCode sMap["design"][item 2 of tCell][item 1 of tCell]
      Ed.Status "picked glyph" && sCode && "from col" && item 1 of tCell && "row" && item 2 of tCell
      exit Ed.OneBitDown
   end if
   put tCell into sOneBitLast
   Ed.PaintGlyph item 1 of tCell, item 2 of tCell
end Ed.OneBitDown

on Ed.OneBitMove
   local tCell
   if sOneBitLast is empty or the mouse is up then exit Ed.OneBitMove
   put Ed.OneBitCell() into tCell
   if tCell is not empty and tCell is not sOneBitLast then
      put tCell into sOneBitLast
      Ed.PaintGlyph item 1 of tCell, item 2 of tCell
   end if
end Ed.OneBitMove

function Ed.OneBitCell
   if not the visible of image "OneBit" then return empty
   return CellMap.CellAtPixel(sMap, sScale1, the mouseH - the left of image "OneBit", the mouseV - the top of image "OneBit")
end Ed.OneBitCell

on Ed.PaintGlyph pC, pR
   CellMap.Set sMap, "design", pC, pR, sCode
   put true into sDirtyMap
   Ed.DrawOneBit
   Ed.PaintCellView pR, pC
end Ed.PaintGlyph

on Ed.ShowInfo
   local t
   put "CODE" && sCode && "  " & Ed.CharShown(sCode) & return & sTags[sCode]["name"] & return into t
   put "solid" && sTags[sCode]["solid"] & "   height" && sTags[sCode]["height"] & "   " & sTags[sCode]["group"] & return after t
   put "EFFECT:" && sTags[sCode]["effect"] after t
   put t into field "Info"
   set the backgroundColor of graphic "Swatch" to Ed.RGB(sTags[sCode]["colour"])
end Ed.ShowInfo

-------------------------------------------------------------------- the drawing board (middle)

on Ed.DrawGlyph
   local tGrid, r, c, tOn
   put CellMap.Glyph(sFont, sCode) into tGrid
   put Ed.RGB(sTags[sCode]["colour"]) into tOn
   lock screen
   put 1 into r
   repeat while r <= 16
      put 1 into c
      repeat while c <= 16
         if char c of line r of tGrid is "1" then
            set the backgroundColor of graphic ("b_" & r & "_" & c) to tOn
         else
            set the backgroundColor of graphic ("b_" & r & "_" & c) to kOff
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   unlock screen
end Ed.DrawGlyph

-- pValue: "1", "0", or empty = flip
on Ed.SetBit pR, pC, pValue
   local tGrid, tLine
   put CellMap.Glyph(sFont, sCode) into tGrid
   put line pR of tGrid into tLine
   if pValue is empty then
      if char pC of tLine is "1" then
         put "0" into pValue
      else
         put "1" into pValue
      end if
   end if
   put pValue into char pC of tLine
   put tLine into line pR of tGrid
   Ed.SetGlyph tGrid
   if pValue is "1" then
      set the backgroundColor of graphic ("b_" & pR & "_" & pC) to Ed.RGB(sTags[sCode]["colour"])
   else
      set the backgroundColor of graphic ("b_" & pR & "_" & pC) to kOff
   end if
   return pValue
end Ed.SetBit

on Ed.SetGlyph pGrid
   put CellMap.GlyphToRows(pGrid) into sFont[sCode]
   put true into sDirtyFont
   Ed.DrawPalette          -- the palette, the map and the ghost show the change at once
   Ed.DrawOneBit
   Ed.MakeGhost
end Ed.SetGlyph

on Ed.BoardDown pName
   local tR, tC
   set the itemDel to "_"
   put item 2 of pName into tR
   put item 3 of pName into tC
   Ed.SetBit tR, tC
   put the result into sBoardPaint       -- dragging paints the same value
end Ed.BoardDown

on Ed.BoardMove
   local tName
   if sBoardPaint is empty or the mouse is up then exit Ed.BoardMove
   put the short name of the mouseControl into tName
   if tName begins with "b_" then
      set the itemDel to "_"
      Ed.SetBit item 2 of tName, item 3 of tName, sBoardPaint
   end if
end Ed.BoardMove

-- the quick functions and the Bit menu: whole-glyph changes through LIB_BIT
on Ed.GlyphDo pWhat
   local tGrid
   put CellMap.Glyph(sFont, sCode) into tGrid
   switch pWhat
      case "Flip Horizontal"
         put Bit.FlipHorizontal(tGrid) into tGrid
         break
      case "Flip Vertical"
         put Bit.FlipVertical(tGrid) into tGrid
         break
      case "Rotate 90 cw"
         put Bit.Rotate(tGrid, 90) into tGrid
         break
      case "Rotate 90 ccw"
         put Bit.Rotate(tGrid, -90) into tGrid
         break
      case "Invert"
         put Bit.Invert(tGrid) into tGrid
         break
      case "Clear"
         put Bit.Blank(16, 16) into tGrid
         break
      case "Fill"
         put Bit.Invert(Bit.Blank(16, 16)) into tGrid
         break
      case "Shift Left"
         put Bit.Shift(tGrid, "left") into tGrid
         break
      case "Shift Right"
         put Bit.Shift(tGrid, "right") into tGrid
         break
      case "Shift Up"
         put Bit.Shift(tGrid, "up") into tGrid
         break
      case "Shift Down"
         put Bit.Shift(tGrid, "down") into tGrid
         break
      default
         exit Ed.GlyphDo
   end switch
   Ed.SetGlyph tGrid
   Ed.DrawGlyph
   Ed.Status pWhat && "glyph" && sCode
end Ed.GlyphDo

-------------------------------------------------------------------- the map (right, 1bit tab)

on Ed.BuildMapView
   local tCols, tRows, r, c, tL, tT, tName
   put sMap["meta"]["cols"] into tCols
   put sMap["meta"]["rows"] into tRows
   put max(6, min(kMapW div tCols, kMapH div tRows)) into sCellPx
   lock screen
   if there is a group "MapView" then delete group "MapView"
   reset the templateGraphic
   set the style of the templateGraphic to "rectangle"
   set the filled of the templateGraphic to true
   set the lineSize of the templateGraphic to 1
   set the foregroundColor of the templateGraphic to kBG
   set the showName of the templateGraphic to (sCellPx >= 14)
   set the textSize of the templateGraphic to max(9, sCellPx div 2)
   set the textFont of the templateGraphic to "Courier New"
   set the textStyle of the templateGraphic to "bold"
   put the left of graphic "MapFrame" + 4 into tL
   put the top of graphic "MapFrame" + 4 into tT
   reset the templateGroup
   create group "MapView"
   set the margins of group "MapView" to 0
   set the showBorder of group "MapView" to false
   put 1 into r
   repeat while r <= tRows
      put 1 into c
      repeat while c <= tCols
         put "m_" & r & "_" & c into tName
         create graphic tName in group "MapView"
         set the rect of it to tL + (c - 1) * sCellPx, tT + (r - 1) * sCellPx, tL + c * sCellPx, tT + r * sCellPx
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   reset the templateGraphic
   put 1 into r
   repeat while r <= tRows
      put 1 into c
      repeat while c <= tCols
         Ed.PaintCellView r, c
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   unlock screen
end Ed.BuildMapView

-- how one map cell looks in the current view (tags, heights or design)
on Ed.PaintCellView pR, pC
   local tG, tTag, tCode, tH, tLabel, tColour
   put "m_" & pR & "_" & pC into tG
   put sMap["tags"][pR][pC] into tTag
   put sMap["design"][pR][pC] into tCode
   put sMap["heights"][pR][pC] into tH
   switch sView
      case "heights"
         put min(255, 40 + tH * 22) into tColour
         put tColour & comma & tColour & comma & tColour into tColour
         put char (tH + 1) of "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" into tLabel
         break
      case "design"
         put Ed.RGB(sTags[tCode]["colour"]) into tColour
         put Ed.CharShown(tCode) into tLabel
         break
      default
         put Ed.RGB(CellMap.TagInfo(sMap, sTags, tTag, "colour")) into tColour
         put tTag into tLabel
   end switch
   set the backgroundColor of graphic tG to tColour
   set the label of graphic tG to tLabel
   set the textColor of graphic tG to Ed.Contrast(tColour)
   set the tooltip of graphic tG to "col" && pC && "row" && pR & ":" && CellMap.TagInfo(sMap, sTags, tTag, "name") & \
         " (" & CellMap.TagInfo(sMap, sTags, tTag, "effect") & ")" & \
         "  design" && tCode && "(" & Ed.CharShown(tCode) & ")  height" && tH
end Ed.PaintCellView

-- paint the selected code into a cell (sMode: all, design, tag or height)
on Ed.PaintCell pR, pC
   local tChar, tH
   put sTags[sCode]["char"] into tChar
   if sExtrude is "tag" then
      put sTags[sCode]["height"] into tH
   else
      put sExtrude into tH
   end if
   if sMode is "all" or sMode is "design" then CellMap.Set sMap, "design", pC, pR, sCode
   if (sMode is "all" or sMode is "tag") and tChar is not empty then CellMap.Set sMap, "tags", pC, pR, tChar
   if sMode is "all" or sMode is "height" then CellMap.Set sMap, "heights", pC, pR, tH
   put true into sDirtyMap
   Ed.PaintCellView pR, pC
   Ed.DrawOneBit
end Ed.PaintCell

on Ed.MapDown pName, pButton
   local tR, tC, tTag
   set the itemDel to "_"
   put item 2 of pName into tR
   put item 3 of pName into tC
   if pButton is 3 or the optionKey is down then
      -- pick: the cell's design code becomes the selected code (the owner's UNIT idea)
      if sView is "tags" then
         put codepointToNum(sMap["tags"][tR][tC]) into tTag
         Ed.SelectCode tTag
      else
         Ed.SelectCode sMap["design"][tR][tC]
      end if
      Ed.Status "picked" && sCode && "from col" && tC && "row" && tR
      exit Ed.MapDown
   end if
   put pName into sLastCell
   Ed.PaintCell tR, tC
end Ed.MapDown

on Ed.MapMove
   local tName
   if sLastCell is empty or the mouse is up then exit Ed.MapMove
   put the short name of the mouseControl into tName
   if tName begins with "m_" and tName is not sLastCell then
      put tName into sLastCell
      set the itemDel to "_"
      Ed.PaintCell item 2 of tName, item 3 of tName
   end if
end Ed.MapMove

on Ed.SetView pView
   local r, c
   put pView into sView
   lock screen
   put 1 into r
   repeat while r <= sMap["meta"]["rows"]
      put 1 into c
      repeat while c <= sMap["meta"]["cols"]
         Ed.PaintCellView r, c
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   unlock screen
   Ed.Status "view:" && pView
end Ed.SetView

-- new size, keeping what fits; new cells are void
on Ed.Resize pCols, pRows
   local tNew, r, c, tKey
   put CellMap.New(pCols, pRows, sMap["meta"]["name"]) into tNew
   repeat for each item tKey in "cell,wallH,unitPx,font,tags"
      put sMap["meta"][tKey] into tNew["meta"][tKey]
   end repeat
   put sMap["tagdefs"] into tNew["tagdefs"]
   put 1 into r
   repeat while r <= pRows
      put 1 into c
      repeat while c <= pCols
         if r <= sMap["meta"]["rows"] and c <= sMap["meta"]["cols"] then
            put sMap["design"][r][c] into tNew["design"][r][c]
            put sMap["tags"][r][c] into tNew["tags"][r][c]
            put sMap["heights"][r][c] into tNew["heights"][r][c]
         else
            put 32 into tNew["design"][r][c]
            put space into tNew["tags"][r][c]
            put 0 into tNew["heights"][r][c]
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   put tNew into sMap
   put true into sDirtyMap
   Ed.BuildMapView
   Ed.DrawOneBit
   Ed.ShowTab sTab
end Ed.Resize

-------------------------------------------------------------------- tabs and menus

on Ed.ShowTab pTab
   if pTab is empty then put "1bit" into pTab
   put pTab into sTab
   lock screen
   set the visible of image "OneBit" to (pTab is "1bit")
   set the visible of group "MapView" to (pTab is "Cells")
   set the visible of field "NotYet" to (pTab is among the items of "Vibe,xt3D")
   if pTab is not "1bit" then
      set the visible of image "Ghost" to false
      set the visible of graphic "GhostBox" to false
   end if
   if pTab is among the items of "Vibe,xt3D" then put pTab && "viewport: not connected yet." & return & return & \
         "The editor stays separate from the Vibecode3D and xt3d main stacks until the owner says so" && \
         "(11 14 2026). The map is saved as a plain .cellmap file that both engines will read." into field "NotYet"
   unlock screen
end Ed.ShowTab

on menuPick pItem
   local tMenu, tAns
   put the short name of the target into tMenu
   if "|" is in pItem then put item -1 of pItem into pItem  -- (no cascades yet)
   replace "!c" with empty in pItem
   replace "!n" with empty in pItem
   switch tMenu
      case "ViewTabs"
         Ed.ShowTab pItem
         break
      case "File"
         Ed.FileMenu pItem
         break
      case "Bit"
         Ed.GlyphDo pItem
         break
      case "Grid"
         Ed.GridMenu pItem
         break
      case "Mesh"
         Ed.MeshMenu pItem
         break
      case "Scene"
         Ed.Status "Scene: " & pItem & " (comes with the 3D viewports)"
         break
      case "Tiles"
         Ed.TilesMenu pItem
         break
      case "View"
         Ed.ViewMenu pItem
         break
      default
         pass menuPick
   end switch
end menuPick

on Ed.FileMenu pItem
   local tFile
   switch pItem
      case "New Map..."
         ask "Columns and rows (Amazing Couple: 13,13)" with "13,13"
         if it is empty then exit Ed.FileMenu
         put CellMap.New(item 1 of it, item 2 of it, "untitled") into sMap
         put sDir & "/maps/untitled.cellmap" into sMapPath
         Ed.BuildMapView
         break
      case "Open Map..."
         answer file "Open a cellmap" with (sDir & "/maps") with type "Cellmap|cellmap|"
         if it is not empty then Ed.OpenMap it
         break
      case "Save Map"
         Ed.SaveMap
         break
      case "Save Map As..."
         ask file "Save the cellmap as" with (sDir & "/maps/" & sMap["meta"]["name"] & ".cellmap")
         if it is empty then exit Ed.FileMenu
         put it into tFile
         if not (tFile ends with ".cellmap") then put ".cellmap" after tFile
         set the itemDel to "/"
         put item -1 of tFile into sMap["meta"]["name"]
         replace ".cellmap" with empty in sMap["meta"]["name"]
         Ed.SaveMap tFile
         break
      case "Save Font"
         Ed.SaveFont
         break
      case "Export Tags As Text"
         put sDir & "/maps/" & sMap["meta"]["name"] & "_tags.txt" into tFile
         put textEncode(CellMap.LayerText(sMap, "tags"), "UTF-8") into URL ("binfile:" & tFile)
         Ed.Status "wrote" && Ed.ShortName(tFile)
         break
   end switch
end Ed.FileMenu

on Ed.GridMenu pItem
   switch pItem
      case "Size (columns, rows)..."
         ask "Columns and rows" with sMap["meta"]["cols"] & comma & sMap["meta"]["rows"]
         if it is not empty and item 1 of it is an integer and item 2 of it is an integer then Ed.Resize item 1 of it, item 2 of it
         break
      case "Cell Size (engine units)..."
         ask "Cell size in engine units (Amazing Couple: 76)" with sMap["meta"]["cell"]
         if it is a number then put it into sMap["meta"]["cell"]
         break
      case "Wall Height (engine units)..."
         ask "A full wall (height 9) in engine units (Amazing Couple: 58)" with sMap["meta"]["wallH"]
         if it is a number then put it into sMap["meta"]["wallH"]
         break
      case "Font..."
         ask "Font name (a .font.txt in editor/fonts: Base_001, 24_Seniors_Sigils)" with sMap["meta"]["font"]
         if it is empty then exit Ed.GridMenu
         put it into sMap["meta"]["font"]
         Ed.LoadFont it
         Ed.DrawGlyph
         Ed.DrawPalette
         Ed.DrawOneBit
         break
   end switch
   put true into sDirtyMap
   Ed.Status "cell" && sMap["meta"]["cell"] && " wall" && sMap["meta"]["wallH"] && " font" && sMap["meta"]["font"]
end Ed.GridMenu

on Ed.MeshMenu pItem
   switch pItem
      case "Height: Tag Default"
         put "tag" into sExtrude
         break
      case "Height: Floor (0)"
         put 0 into sExtrude
         break
      case "Height: Step (1)"
         put 1 into sExtrude
         break
      case "Height: Block (3)"
         put 3 into sExtrude
         break
      case "Height: Full Wall (9)"
         put 9 into sExtrude
         break
      default
         Ed.Status "Mesh: " & pItem & " (comes with the 3D viewports)"
         exit Ed.MeshMenu
   end switch
   Ed.Status "painting height:" && sExtrude
end Ed.MeshMenu

on Ed.TilesMenu pItem
   local tColour
   switch pItem
      case "Paint Everything"
         put "all" into sMode
         break
      case "Paint Design Only"
         put "design" into sMode
         break
      case "Paint Tag Only"
         put "tag" into sMode
         break
      case "Paint Height Only"
         put "height" into sMode
         break
      case "View Tags"
         Ed.SetView "tags"
         exit Ed.TilesMenu
      case "View Design"
         Ed.SetView "design"
         exit Ed.TilesMenu
      case "View Heights"
         Ed.SetView "heights"
         exit Ed.TilesMenu
      case "Auto Walls"
         -- every plain # wall takes the Aquarius line piece that joins its neighbours
         CellMap.AutoWalls sMap
         put true into sDirtyMap
         Ed.DrawOneBit
         Ed.SetView sView
         Ed.Status "auto walls: the walls are joined line pieces now"
         exit Ed.TilesMenu
      case "Tag Colour..."
         answer color with Ed.RGB(sTags[sCode]["colour"])
         if it is empty then exit Ed.TilesMenu
         put Ed.Hex(it) into tColour
         put tColour into sTags[sCode]["colour"]
         if sTags[sCode]["char"] is not empty then
            put sTags[sCode]["name"] into sMap["tagdefs"][sTags[sCode]["char"]]["name"]
            put tColour into sMap["tagdefs"][sTags[sCode]["char"]]["colour"]
            put sTags[sCode]["solid"] into sMap["tagdefs"][sTags[sCode]["char"]]["solid"]
            put sTags[sCode]["height"] into sMap["tagdefs"][sTags[sCode]["char"]]["height"]
            put sTags[sCode]["effect"] into sMap["tagdefs"][sTags[sCode]["char"]]["effect"]
         end if
         put true into sDirtyMap
         Ed.FillList
         Ed.ShowInfo
         Ed.DrawGlyph
         Ed.SetView sView
         exit Ed.TilesMenu
   end switch
   Ed.Status "painting:" && sMode
end Ed.TilesMenu

-------------------------------------------------------------------- helpers

on Ed.Status pText
   local tFlags
   if sDirtyMap then put "  [map not saved]" after tFlags
   if sDirtyFont then put "  [font not saved]" after tFlags
   put pText & "   |   " & Ed.ShortName(sMapPath) && sMap["meta"]["cols"] & "x" & sMap["meta"]["rows"] & \
         "  paint:" && sMode & "  height:" && sExtrude & "  view:" && sView & tFlags into field "Status"
end Ed.Status

-- "#RRGGBB" -> "r,g,b"
function Ed.RGB pHex
   if char 1 of pHex is not "#" then return pHex
   return baseConvert(char 2 to 3 of pHex, 16, 10) & comma & baseConvert(char 4 to 5 of pHex, 16, 10) & comma & baseConvert(char 6 to 7 of pHex, 16, 10)
end Ed.RGB

function Ed.Hex pRGB
   return "#" & format("%02X%02X%02X", item 1 of pRGB, item 2 of pRGB, item 3 of pRGB)
end Ed.Hex

-- dark text on light colours, light text on dark ones
function Ed.Contrast pRGB
   if item 1 of pRGB * 0.3 + item 2 of pRGB * 0.59 + item 3 of pRGB * 0.11 > 140 then return "20,20,24"
   return "235,235,240"
end Ed.Contrast

-- tests: the state in one line
function Ed.State
   return Ed.ShortName(sMapPath) & "|" & sMap["meta"]["cols"] & "x" & sMap["meta"]["rows"] & "|code " & sCode & "|" & sMode & "|" & sView & "|" & sExtrude & "|" & sDirtyMap & "," & sDirtyFont & "|tab " & sTab & "|1bit " & the width of image "OneBit" & "x" & the height of image "OneBit"
end Ed.State

-- the card script sends these (it sees every click and drag on the board and the map)
on Ed.MouseUp
   put empty into sBoardPaint
   put empty into sLastCell
   put empty into sOneBitLast
   Ed.Status "ok"
end Ed.MouseUp
