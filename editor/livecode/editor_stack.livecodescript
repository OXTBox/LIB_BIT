######################################################################################
## STACK SCRIPT: "BitEditor"  (LIB_BIT/editor, 11 14 2026, layout 2)
## The 1-bit to 3D editor. Layout 2 is the owner's (11 14 2026, afternoon): not everything
## on the screen at once; the 2D map always there; the 3D result seen while you paint.
## Data: cellmap version 2 (editor/CELLMAP_V2.md) through lib_cellmap; glyph maths: lib_bit.
## Built by build_editor.livecodescript; this text is the stack script it sets.
##
## LEFT    top: the drawing board, 16 x 16 bits of the selected glyph. Press and drag paints
##         like a brush (the first bit decides: lit or dark); Bit menu: Mirror H / V While
##         Drawing (both can be on, a guide line shows each), Mirror H / V Now.
##         under it two tabs, one list at a time:
##           Glyphs      number, character, the glyph's own picture (an imageSource in the
##                       text), label. Click = the glyph a map click paints.
##           Properties  the 256 tags in their colours (wall, door, water ...). Click = the
##                       property a map click sets (with its height, unless Tiles says not).
## MIDDLE  the 2D map, always visible and editable, three views of the same picture:
##           1bit     the glyphs, light on dark
##           Cells    the glyphs on their property colours
##           Heights  the glyphs in floor colour on ceiling colour (Ceiling tool flips);
##                    grey / red / green / blue swatches paint the five height layers
##           Slope    (cellmap v3; its own tab since the owner's notes of 19 Nov 2026) a compass
##                    says which way is uphill (Auto: the way you drag). Ramp: drag a box, it
##                    becomes ONE smooth slope (Join: from the floor before it to the floor
##                    after it); One Cell: lift each cell's uphill edge or corner by the swatch;
##                    Flatten. An arrow in a sloped cell points uphill, red when too steep.
##         What a click paints: Heights tab = a height; otherwise the left tab decides.
## RIGHT   the 3D preview: the level's lines exactly as CellMap.LevelSegments gives them to
##         Vibecode3D (LIB_EDITOR E13), redrawn at every change. The cell under the mouse (in
##         the 2D map or here) is marked in yellow. LEFT button paints here, the same brush
##         as the 2D map (CellMap.Pick finds the cell); Alt + click picks up. RIGHT button
##         held = camera mode: drag turns, W A S D move forward / left / back / right, R F up /
##         down (Shift + drag zooms); the wheel zooms.
## MENUS   File  Edit  Bit  Grid  Mesh  Scene  Tiles  View
## TABS    drawn ones (LIB_THEME Theme.TabStrip: fields "tab_<strip>_<n>"), not the native tab
##         control, which stays light grey on white whatever the colours.
## UNDO    Edit menu, Ctrl+Z / Ctrl+Y. Every changed bit or cell is its own numbered line of the
##         change history (with its time: paths and animation can replay it); one press of the
##         mouse (a stroke) or one menu command is one undo. File-less: Edit > Export Change History.
## PACKS   File > Open Pack / New Pack (cellmap v3, CELLMAP_V3.md 4 and 6): a floating "Pack" window
##         lists the level's maps (double-click opens one for painting; Up / Down order them; Place
##         sets place, base, col,row), its doors (Door to... from the last cell clicked) and the
##         E12 checker's lines (Check; a click on a line opens its map and marks the cell).
## STROKES a press on the board or the map starts a stroke; Ed.StrokeTick follows the mouse
##         every 15 ms and paints every cell on the line since the last look, so a fast drag
##         leaves no gaps. The slow redraws (glyph list, 3D) wait for a pause or the release.
######################################################################################

local sDir, sMap, sMapPath, sTags, sFont, sFontPath
local sCode, sTag, sLeft, sTab, sPropHeight, sExtrude
local sDirtyMap, sDirtyFont, sBoardPaint, sPx, sGhostOn, sHover
local sHTool, sHLayer, sHValue, sHBlocks, sCache, sHFrom
local sSlopePart, sSlopeStamp, sSMode, sSDir, sSValue, sSJoin, sRampFrom, sRampId
local sHide, sShow, sVis, sVisAt
local sPack, sPackPath, sPackSel, sPackOpen, sPackDirty, sLastCell, sCheck
local sSegs, sSegCount, sYaw, sPitch, sDist, sRelief3D, sDrag
local sMirrorH, sMirrorV
local sTX, sTY, sTZ, sCamOn, sCamAt, sCamId
local sStrokeKind, sStrokeAt, sStrokeName, sStrokeN, sTickId, sDirty2D, sDirty3D, sDirtyGlyph, sHeavyAt
local sHist, sHistN, sHistMax, sStroke

constant kOff = "48,48,56"
constant kLit = "225,225,230"
constant kDark = "24,24,28"
constant kMapW = 480
constant kMapH = 430
-- class, colour of the 3D lines (the same as E13 Walk The Map)
constant kColours = "floor 40,110,130|wall 127,168,255|pit 255,80,64|water 64,224,255|ceiling 144,152,168|green 80,224,112|sky 184,216,255|relief 255,255,255"

-------------------------------------------------------------------- start

on openStack
   Ed.Init
end openStack

on Ed.Init
   local tPath
   put the effective filename of this stack into tPath
   set the itemDel to "/"
   put item 1 to -2 of tPath into sDir                 -- .../LIB_BIT/editor
   set the itemDel to comma
   if there is not a file (sDir & "/livecode/lib_cellmap.livecodescript") then
      answer "BitEditor: keep this stack in LIB_BIT/editor (lib_cellmap not found next to it)."
      exit Ed.Init
   end if
   Ed.UseLib sDir & "/livecode/lib_cellmap.livecodescript"
   set the itemDel to "/"
   Ed.UseLib item 1 to -2 of sDir & "/livecode/lib_bit.livecodescript"
   Ed.UseLib item 1 to -2 of sDir & "/livecode/lib_lean.livecodescript"     -- Lean style (Scene menu)
   set the itemDel to comma
   put "Glyphs" into sLeft
   put "1bit" into sTab
   put true into sPropHeight
   put "tag" into sExtrude
   put true into sGhostOn
   put "floor" into sHTool
   put "grey" into sHLayer
   put 0 into sHFrom                         -- the From Floor (1) / From Ceiling (2) brush
   put "e" into sSlopePart                   -- the Slope tool: the edge or corner a click lifts
   put empty into sSlopeStamp                -- "nw,ne,se,sw" picked up from a cell (right-click)
   put "ramp" into sSMode                    -- the Slope tab: ramp, cell, flatten (never "one": a constant)
   put "auto" into sSDir                     -- uphill: auto, n, ne, e, se, s, sw, w, nw
   put 30 into sSValue
   put true into sSJoin
   put "off" into sHide                      -- the 3D preview: off, lines (Scene menu)
   put empty into sShow                      -- classes switched off: sShow[class] is false
   put 100 into sHValue
   put false into sHBlocks
   put true into sRelief3D
   put false into sMirrorH
   put false into sMirrorV
   put empty into sStrokeKind
   Ed.HistClear
   put 35 into sCode
   put 35 into sTag
   Ed.ResetCamera
   put CellMap.TagsFromText(CellMap.ReadText(sDir & "/data/tags_default.txt")) into sTags
   if there is a file (sDir & "/maps/wizard_pool.cellmap") then
      Ed.OpenMap sDir & "/maps/wizard_pool.cellmap"
   else
      Ed.OpenMap sDir & "/maps/amazing_couple.cellmap"
   end if
   Ed.FillProps
   Ed.LeftTab "Glyphs"
   Ed.SelectTag 35
   Ed.SelectCode 35
   Ed.MapTab "1bit"
end Ed.Init

on Ed.UseLib pPath
   if there is a file pPath then start using stack pPath
end Ed.UseLib

-------------------------------------------------------------------- files

on Ed.OpenMap pPath
   local tWas
   put CellMap.Read(pPath) into sMap
   put sMap["meta"]["version"] into tWas
   CellMap.Upgrade sMap                    -- a version 1 map is edited (and saved) as version 2
   put pPath into sMapPath
   put Ed.PackIdOf(pPath) into sPackOpen          -- the map's id when it belongs to the open pack
   put empty into sLastCell
   if there is a graphic "MarkBox" then set the visible of graphic "MarkBox" to false
   Ed.LoadFont sMap["meta"]["font"]
   put false into sDirtyMap
   put empty into sCache
   Ed.HistClear
   Ed.ResetCamera
   Ed.Changed
   Ed.MenuMarks
   Ed.PackFill
   if tWas < 2 then
      Ed.Status "opened" && Ed.ShortName(pPath) && "(version 1: saving writes version 2, heights as floors)"
   else
      Ed.Status "opened" && Ed.ShortName(pPath)
   end if
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
   put empty into sCache
   Ed.MakeGlyphImages
   Ed.FillGlyphs
   if sCode is a number then Ed.DrawGlyph
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

-------------------------------------------------------------------- left: the two lists, one at a time

function Ed.CharShown pCode
   if (pCode >= 33 and pCode <= 126) or (pCode >= 161 and pCode <= 255) then return numToCodepoint(pCode)
   if pCode is 32 then return "_"
   return "."
end Ed.CharShown

-- what a glyph is, in a word or two (a font says nothing about its glyphs yet)
function Ed.GlyphLabel pCode
   if pCode is 32 then return "space"
   if pCode >= 48 and pCode <= 57 then return "digit" && numToCodepoint(pCode)
   if pCode >= 65 and pCode <= 90 then return "letter" && numToCodepoint(pCode)
   if pCode >= 97 and pCode <= 122 then return "small" && numToCodepoint(pCode)
   if pCode is among the items of "198,214,172,207,222,205,223,204,206,221,220,200" then return "wall line (Auto Walls)"
   if pCode > 32 and pCode < 127 then return "sign" && numToCodepoint(pCode)
   if pCode >= 128 then return "graphic" && pCode
   return "control" && pCode
end Ed.GlyphLabel

private function edPixel pRGB
   return numToByte(0) & numToByte(item 1 of pRGB) & numToByte(item 2 of pRGB) & numToByte(item 3 of pRGB)
end edPixel

-- one glyph's own 16 x 16 picture (image "g_<code>", hidden): what the list shows in its text
on Ed.GlyphImage pCode
   local tData, tF, tB, tBits, tCh
   if there is not an image ("g_" & pCode) then exit Ed.GlyphImage
   put edPixel(kLit) into tF
   put edPixel(the effective backgroundColor of field "Glyphs") into tB
   repeat for each line tBits in CellMap.Glyph(sFont, pCode)
      repeat for each char tCh in tBits
         if tCh is "1" then
            put tF after tData
         else
            put tB after tData
         end if
      end repeat
   end repeat
   set the imageData of image ("g_" & pCode) to tData
end Ed.GlyphImage

on Ed.MakeGlyphImages
   local tCode
   if there is not a field "Glyphs" then exit Ed.MakeGlyphImages
   lock screen
   put 0 into tCode
   repeat while tCode <= 255
      Ed.GlyphImage tCode
      add 1 to tCode
   end repeat
   unlock screen
end Ed.MakeGlyphImages

-- Glyphs: "065  A  <picture>  letter A"; the picture is the imageSource of the * in the line
on Ed.FillGlyphs
   local tOut, tCode, tLine, tFilter, tN, tCodes
   if there is not a field "Glyphs" then exit Ed.FillGlyphs
   if sLeft is "Glyphs" then put field "Filter" into tFilter
   put 0 into tCode
   repeat while tCode <= 255
      put format("%03d", tCode) & "  " & Ed.CharShown(tCode) & "  *  " & Ed.GlyphLabel(tCode) into tLine
      if tFilter is empty or tFilter is in tLine then
         put tLine & return after tOut
         put tCode & return after tCodes
      end if
      add 1 to tCode
   end repeat
   delete the last char of tOut
   lock screen
   put tOut into field "Glyphs"
   put 1 into tN
   repeat for each line tCode in tCodes
      set the imageSource of char 9 of line tN of field "Glyphs" to the short id of image ("g_" & tCode)
      add 1 to tN
   end repeat
   unlock screen
   Ed.HiliteLists
end Ed.FillGlyphs

-- Properties: "035  #  wall  (block)" in the tag's colour
on Ed.FillProps
   local tOut, tCode, tLine, tFilter, tN, tCodes
   if sLeft is "Properties" then put field "Filter" into tFilter
   put 0 into tCode
   repeat while tCode <= 255
      put format("%03d", tCode) & "  " & Ed.CharShown(tCode) & "  " & sTags[tCode]["name"] & "  (" & sTags[tCode]["effect"] & ")" into tLine
      if tFilter is empty or tFilter is in tLine then
         put tLine & return after tOut
         put tCode & return after tCodes
      end if
      add 1 to tCode
   end repeat
   delete the last char of tOut
   lock screen
   put tOut into field "Props"
   put 1 into tN
   repeat for each line tCode in tCodes
      set the textColor of line tN of field "Props" to Ed.RGB(sTags[tCode]["colour"])
      add 1 to tN
   end repeat
   unlock screen
   Ed.HiliteLists
end Ed.FillProps

on Ed.FilterChanged
   if sLeft is "Glyphs" then
      Ed.FillGlyphs
   else
      Ed.FillProps
   end if
end Ed.FilterChanged

on Ed.HiliteLists
   local n
   if sCode is a number then
      put lineOffset(return & format("%03d", sCode) & " ", return & field "Glyphs") into n
      set the hilitedLine of field "Glyphs" to n
   end if
   if sTag is a number then
      put lineOffset(return & format("%03d", sTag) & " ", return & field "Props") into n
      set the hilitedLine of field "Props" to n
   end if
end Ed.HiliteLists

-- Glyphs or Properties: which list shows, and so what a map click paints
on Ed.LeftTab pTab
   if pTab is not "Properties" then put "Glyphs" into pTab
   put pTab into sLeft
   lock screen
   put empty into field "Filter"
   set the visible of field "Glyphs" to (pTab is "Glyphs")
   set the visible of field "Props" to (pTab is "Properties")
   Ed.TabShow "Left", pTab
   Ed.FilterChanged
   unlock screen
   -- the map follows, unless heights are being painted: glyphs read best in 1bit, properties in Cells
   if sTab is not "Heights" then
      if pTab is "Glyphs" then
         Ed.MapTab "1bit"
      else
         Ed.MapTab "Cells"
      end if
   end if
   Ed.ShowInfo
   Ed.ShowWhat
end Ed.LeftTab

on Ed.ListClicked pWhich
   local tLine
   put the value of the clickLine into tLine
   if word 1 of tLine is not an integer then exit Ed.ListClicked
   if pWhich is "Props" then
      Ed.SelectTag word 1 of tLine + 0
   else
      Ed.SelectCode word 1 of tLine + 0
   end if
end Ed.ListClicked

-- the drawn tabs (LIB_THEME Theme.TabStrip made them): a click on one arrives here
on tabPick pStrip, pTab
   if pStrip is "Left" then
      Ed.LeftTab pTab
   else if pStrip is "Map" then
      Ed.MapTab pTab
   end if
end tabPick

-- show which tab of a strip is selected (each tab field carries its two looks)
on Ed.TabShow pStrip, pTab
   local n, tF
   put 1 into n
   repeat while there is a field ("tab_" & pStrip & "_" & n)
      put the long id of field ("tab_" & pStrip & "_" & n) into tF
      if the uTabName of tF is pTab then
         set the backgroundColor of tF to the uOnBack of tF
         set the foregroundColor of tF to the uOnText of tF
         set the textStyle of tF to "bold"
      else
         set the backgroundColor of tF to the uOffBack of tF
         set the foregroundColor of tF to the uOffText of tF
         set the textStyle of tF to "plain"
      end if
      add 1 to n
   end repeat
end Ed.TabShow

-- the glyph a map click paints (and the one on the drawing board)
on Ed.SelectCode pCode
   put pCode into sCode
   Ed.DrawGlyph
   Ed.MakeGhost
   Ed.HiliteLists
   Ed.ShowInfo
   Ed.ShowWhat
end Ed.SelectCode

-- the property a map click sets
on Ed.SelectTag pCode
   put pCode into sTag
   Ed.HiliteLists
   Ed.ShowInfo
   Ed.ShowWhat
end Ed.SelectTag

on Ed.ShowInfo
   local t
   if sLeft is "Properties" then
      put "PROPERTY" && sTag && "  " & Ed.CharShown(sTag) & "   " & sTags[sTag]["name"] & return into t
      put "solid" && sTags[sTag]["solid"] & "   height" && CellMap.H1ToFloor(sTags[sTag]["height"], "x") & "   " & sTags[sTag]["group"] & return after t
      put "EFFECT:" && sTags[sTag]["effect"] after t
      set the backgroundColor of graphic "Swatch" to Ed.RGB(sTags[sTag]["colour"])
   else
      put "GLYPH" && sCode && "  " & Ed.CharShown(sCode) & "   " & Ed.GlyphLabel(sCode) & return into t
      put "Draw on the board above; Bit menu flips," & return & "turns and shifts. File > Save Font keeps it." after t
      set the backgroundColor of graphic "Swatch" to kLit
   end if
   put t into field "Info"
end Ed.ShowInfo

-------------------------------------------------------------------- the drawing board (top left)

on Ed.DrawGlyph
   local tGrid, r, c
   put CellMap.Glyph(sFont, sCode) into tGrid
   lock screen
   put 1 into r
   repeat while r <= 16
      put 1 into c
      repeat while c <= 16
         if char c of line r of tGrid is "1" then
            set the backgroundColor of graphic ("b_" & r & "_" & c) to kLit
         else
            set the backgroundColor of graphic ("b_" & r & "_" & c) to kOff
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   unlock screen
end Ed.DrawGlyph

-- one bit of the selected glyph, at once and cheaply (the bit's square, the font, the history);
-- the slow followers (list picture, map, 3D) are Ed.GlyphRefresh. pValue: "1", "0", or empty = flip
on Ed.RawBit pR, pC, pValue
   local tGrid, tLine, tOld
   if pR < 1 or pC < 1 or pR > 16 or pC > 16 then return empty
   put CellMap.Glyph(sFont, sCode) into tGrid
   put line pR of tGrid into tLine
   put char pC of tLine into tOld
   if pValue is empty then
      if tOld is "1" then
         put "0" into pValue
      else
         put "1" into pValue
      end if
   end if
   if tOld is pValue then return pValue
   put pValue into char pC of tLine
   put tLine into line pR of tGrid
   put CellMap.GlyphToRows(tGrid) into sFont[sCode]
   Ed.Record "bit", sCode, pC, pR, tOld, pValue
   if pValue is "1" then
      set the backgroundColor of graphic ("b_" & pR & "_" & pC) to kLit
   else
      set the backgroundColor of graphic ("b_" & pR & "_" & pC) to kOff
   end if
   put true into sDirtyFont
   put true into sDirtyGlyph
   return pValue
end Ed.RawBit

-- one bit as one undo step (tests, scripts); a drag uses the stroke handlers below
on Ed.SetBit pR, pC, pValue
   local tValue
   Ed.StrokeBegin "call", "bit of glyph" && sCode
   Ed.RawBit pR, pC, pValue
   put the result into tValue
   Ed.StrokeEnd
   return tValue
end Ed.SetBit

-- the brush on the board: the bit and its mirror images
on Ed.BoardBit pR, pC
   local tCells, tCell
   put pR & comma & pC into tCells
   if sMirrorH then put return & pR & comma & (17 - pC) after tCells
   if sMirrorV then put return & (17 - pR) & comma & pC after tCells
   if sMirrorH and sMirrorV then put return & (17 - pR) & comma & (17 - pC) after tCells
   repeat for each line tCell in tCells
      Ed.RawBit item 1 of tCell, item 2 of tCell, sBoardPaint
   end repeat
end Ed.BoardBit

-- a glyph changed: its picture in the list, the map, the ghost and the 3D relief all follow
on Ed.GlyphRefresh
   local n
   put empty into sCache
   Ed.GlyphImage sCode
   put lineOffset(return & format("%03d", sCode) & " ", return & field "Glyphs") into n
   if n > 0 then
      set the imageSource of char 9 of line n of field "Glyphs" to empty
      set the imageSource of char 9 of line n of field "Glyphs" to the short id of image ("g_" & sCode)
   end if
   Ed.MakeGhost
   Ed.Changed
   put false into sDirtyGlyph
   put false into sDirty2D
   put false into sDirty3D
end Ed.GlyphRefresh

-- the whole selected glyph at once (the Bit menu): one undo step
on Ed.SetGlyph pGrid, pLabel
   local tOld, tNew
   if pLabel is empty then put "glyph" && sCode into pLabel
   put sFont[sCode] into tOld
   put CellMap.GlyphToRows(pGrid) into tNew
   if tOld is tNew then exit Ed.SetGlyph
   Ed.StrokeBegin "call", pLabel
   put tNew into sFont[sCode]
   Ed.Record "glyph", sCode, empty, empty, tOld, tNew
   put true into sDirtyFont
   put true into sDirtyGlyph
   Ed.StrokeEnd
   Ed.DrawGlyph
end Ed.SetGlyph

-- "row,col" of the board under the mouse, empty outside it
function Ed.BoardCell
   local tX, tY
   if there is not a graphic "b_1_1" then return empty
   put the mouseH - the left of graphic "b_1_1" into tX
   put the mouseV - the top of graphic "b_1_1" into tY
   if tX < 0 or tY < 0 or tX >= 256 or tY >= 256 then return empty
   return (tY div 16 + 1) & comma & (tX div 16 + 1)
end Ed.BoardCell

-- press on the board: a stroke starts; the first bit decides what the drag paints
on Ed.BoardDown
   local tCell
   put Ed.BoardCell() into tCell
   if tCell is empty then exit Ed.BoardDown
   Ed.StrokeBegin "board", "draw on glyph" && sCode
   if char (item 2 of tCell) of line (item 1 of tCell) of CellMap.Glyph(sFont, sCode) is "1" then
      put "0" into sBoardPaint
   else
      put "1" into sBoardPaint
   end if
   put tCell into sStrokeAt
   Ed.BoardBit item 1 of tCell, item 2 of tCell
   Ed.StrokeTick sTickId
end Ed.BoardDown

-- Bit menu: the mirrors (H = left and right, V = top and bottom)
on Ed.Mirror pWhich, pOn
   if pWhich is "H" then
      put pOn into sMirrorH
   else
      put pOn into sMirrorV
   end if
   Ed.MenuMarks
   Ed.Status "mirror while drawing: left-right" && Ed.OnOff(sMirrorH) & ", top-bottom" && Ed.OnOff(sMirrorV)
end Ed.Mirror

function Ed.OnOff pBool
   if pBool is true then return "ON"
   return "off"
end Ed.OnOff

-- check marks in the menus and the mirror guide lines on the board follow the settings
on Ed.MenuMarks
   Ed.MenuMark "Bit", "Mirror H While Drawing", sMirrorH
   Ed.MenuMark "Bit", "Mirror V While Drawing", sMirrorV
   Ed.MenuMark "Mesh", "Extrude: Whole Cell", (sMap["meta"]["extrude"] is not "glyph")
   Ed.MenuMark "Mesh", "Extrude: Glyph Shape", (sMap["meta"]["extrude"] is "glyph")
   if there is a button "HExtrude" then set the hilite of button "HExtrude" to (sMap["meta"]["extrude"] is "glyph")
   Ed.HTopShow
   Ed.SceneMarks
   if there is a graphic "MirrorHLine" then
      set the visible of graphic "MirrorHLine" to (sMirrorH is true)
      set the visible of graphic "MirrorVLine" to (sMirrorV is true)
   end if
end Ed.MenuMarks

on Ed.MenuMark pMenu, pItem, pOn
   local tText, tLine, tOut
   if there is not a button pMenu then exit Ed.MenuMark
   put the text of button pMenu into tText
   repeat for each line tLine in tText
      if tLine is pItem or tLine is ("!c" & pItem) then
         if pOn then
            put "!c" & pItem into tLine
         else
            put pItem into tLine
         end if
      end if
      put tLine & return after tOut
   end repeat
   delete the last char of tOut
   if tOut is not tText then set the text of button pMenu to tOut
end Ed.MenuMark

-- the Bit menu: whole-glyph changes through LIB_BIT
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
      case "Mirror H While Drawing"
         Ed.Mirror "H", not sMirrorH
         exit Ed.GlyphDo
      case "Mirror V While Drawing"
         Ed.Mirror "V", not sMirrorV
         exit Ed.GlyphDo
      case "Mirror H Now (left onto right)"
         put Ed.Mirrored(tGrid, "H") into tGrid
         break
      case "Mirror V Now (top onto bottom)"
         put Ed.Mirrored(tGrid, "V") into tGrid
         break
      default
         exit Ed.GlyphDo
   end switch
   Ed.SetGlyph tGrid, pWhat && "glyph" && sCode
   Ed.Status pWhat && "glyph" && sCode
end Ed.GlyphDo

-- a grid made symmetric once: H copies the left half onto the right, V the top onto the bottom
function Ed.Mirrored pGrid, pWhich
   local r, c, tLine
   put 1 into r
   repeat while r <= 16
      if pWhich is "V" then
         if r <= 8 then
            put line r of pGrid into line (17 - r) of pGrid
         end if
      else
         put line r of pGrid into tLine
         put 1 into c
         repeat while c <= 8
            put char c of tLine into char (17 - c) of tLine
            add 1 to c
         end repeat
         put tLine into line r of pGrid
      end if
      add 1 to r
   end repeat
   return pGrid
end Ed.Mirrored

-------------------------------------------------------------------- strokes: one press of the mouse, followed until it is released

-- pKind: "board", "map" or "view" (the 3D preview), followed by Ed.StrokeTick; or "call" (one
-- command, ended by its caller)
on Ed.StrokeBegin pKind, pName
   if sStrokeKind is not empty then Ed.StrokeEnd
   add 1 to sStroke
   add 1 to sTickId
   put pKind into sStrokeKind
   put pName into sStrokeName
   put sHistN into sStrokeN
   put empty into sStrokeAt
   put the milliseconds into sHeavyAt
end Ed.StrokeBegin

-- every cell from pFrom (not included) to pTo (included), "a,b" a line: a fast drag leaves no gaps
function Ed.LineCells pFrom, pTo
   local a, b, a2, b2, da, db, tSteps, i, tOut, tA, tB, tLast
   put item 1 of pFrom into a
   put item 2 of pFrom into b
   put item 1 of pTo into a2
   put item 2 of pTo into b2
   put a2 - a into da
   put b2 - b into db
   put max(abs(da), abs(db)) into tSteps
   put pFrom into tLast
   put 1 into i
   repeat while i <= tSteps
      put a + round(da * i / tSteps) into tA
      put b + round(db * i / tSteps) into tB
      if (tA & comma & tB) is not tLast then
         put tA & comma & tB into tLast
         put tLast & return after tOut
      end if
      add 1 to i
   end repeat
   delete the last char of tOut
   return tOut
end Ed.LineCells

on Ed.StrokeCell pCell
   if sStrokeKind is "board" then
      Ed.BoardBit item 1 of pCell, item 2 of pCell
   else
      Ed.PaintCell item 1 of pCell, item 2 of pCell
   end if
end Ed.StrokeCell

-- the brush: every 15 ms while the mouse is down, paint from the last cell to the one under the mouse
on Ed.StrokeTick pId
   local tCell, tStep
   if pId is not sTickId or sStrokeKind is empty then exit Ed.StrokeTick
   if the mouse is up then
      Ed.StrokeEnd
      exit Ed.StrokeTick
   end if
   if sStrokeKind is "board" then
      put Ed.BoardCell() into tCell
   else if sStrokeKind is "view" then
      put Ed.ViewCell() into tCell
   else
      put Ed.MapCell() into tCell
   end if
   if tCell is not empty and tCell is not sStrokeAt then
      repeat for each line tStep in Ed.LineCells(sStrokeAt, tCell)
         Ed.StrokeCell tStep
      end repeat
      put tCell into sStrokeAt
   end if
   Ed.StrokeShow false
   send "Ed.StrokeTick" && sTickId to me in 15 milliseconds
end Ed.StrokeTick

-- show what the stroke changed. The 2D map at once; the slow ones (glyph list, ghost, 3D) when
-- the stroke ends or the brush has had 200 ms without them
on Ed.StrokeShow pFinal
   local tHeavy
   put (pFinal or the milliseconds - sHeavyAt > 200) into tHeavy
   if sDirtyGlyph then
      if tHeavy then
         Ed.GlyphRefresh
         put the milliseconds into sHeavyAt
      end if
      exit Ed.StrokeShow
   end if
   if sDirty2D then
      Ed.DrawMap
      put false into sDirty2D
      if sHover is not empty then Ed.ShowHover
   end if
   if sDirty3D and tHeavy then
      Ed.Build3D
      Ed.Draw3D
      put false into sDirty3D
      put the milliseconds into sHeavyAt
   end if
end Ed.StrokeShow

on Ed.StrokeEnd
   local tN
   if sStrokeKind is empty then exit Ed.StrokeEnd
   put empty into sStrokeKind
   add 1 to sTickId
   Ed.StrokeShow true
   put sHistN - sStrokeN into tN
   if tN > 0 then Ed.Status sStrokeName & ":" && tN && "changes (Ctrl+Z undoes them)"
end Ed.StrokeEnd

-- as a drag would: pKind "board" (cells "row,col") or "map" (cells "col,row"), pCells words
on Ed.TestStroke pKind, pCells
   local tCell, tStep
   Ed.StrokeBegin pKind, "test stroke"
   put word 1 of pCells into tCell
   if pKind is "board" then
      if char (item 2 of tCell) of line (item 1 of tCell) of CellMap.Glyph(sFont, sCode) is "1" then
         put "0" into sBoardPaint
      else
         put "1" into sBoardPaint
      end if
   end if
   put tCell into sStrokeAt
   Ed.StrokeCell tCell
   repeat for each word tCell in word 2 to -1 of pCells
      repeat for each line tStep in Ed.LineCells(sStrokeAt, tCell)
         Ed.StrokeCell tStep
      end repeat
      put tCell into sStrokeAt
   end repeat
   Ed.StrokeEnd
end Ed.TestStroke

-------------------------------------------------------------------- the change history and undo

on Ed.HistClear
   put empty into sHist
   put 0 into sHistN
   put 0 into sHistMax
   put 0 into sStroke
end Ed.HistClear

-- one change = one numbered line of the history. pKind: "cell" (pWhat = the layer, pA = col,
-- pB = row), "bit" (pWhat = the glyph, pA = col, pB = row), "glyph" (a whole glyph's rows),
-- "map" (the whole map before and after: size, walls, options)
on Ed.Record pKind, pWhat, pA, pB, pOld, pNew
   add 1 to sHistN
   put empty into sHist[sHistN]
   put sStroke into sHist[sHistN]["stroke"]
   put sStrokeName into sHist[sHistN]["name"]
   put the milliseconds into sHist[sHistN]["ms"]
   put pKind into sHist[sHistN]["kind"]
   put pWhat into sHist[sHistN]["what"]
   put pA into sHist[sHistN]["a"]
   put pB into sHist[sHistN]["b"]
   put pOld into sHist[sHistN]["old"]
   put pNew into sHist[sHistN]["new"]
   put sHistN into sHistMax              -- a new change ends what could be redone
end Ed.Record

-- a cell of a layer (design, tags, floor, ceiling, red, green, blue), recorded
on Ed.SetCell pWhich, pC, pR, pValue
   local tOld
   if pC < 1 or pR < 1 or pC > sMap["meta"]["cols"] or pR > sMap["meta"]["rows"] then exit Ed.SetCell
   put sMap[pWhich][pR][pC] into tOld
   if pWhich is "tags" then
      if tOld is empty or pValue is empty then
         if tOld is pValue then
            exit Ed.SetCell
         end if
      else if codepointToNum(tOld) is codepointToNum(pValue) then
         exit Ed.SetCell                    -- by number: "a" is not "A" here
      end if
   else if tOld is pValue then
      exit Ed.SetCell
   end if
   put pValue into sMap[pWhich][pR][pC]
   Ed.Record "cell", pWhich, pC, pR, tOld, pValue
   put true into sDirtyMap
   put true into sDirty2D
   put true into sDirty3D
end Ed.SetCell

-- after a whole-map command: one undo step holding the map as it was (pOld) and as it is
on Ed.MapSnap pName, pOld
   Ed.StrokeBegin "call", pName
   Ed.Record "map", empty, empty, empty, pOld, sMap
   put true into sDirtyMap
   put true into sDirty2D
   put true into sDirty3D
   Ed.StrokeEnd
end Ed.MapSnap

-- put one history line's old or new value back; says what kind of thing changed
private command edApply pN, pWhich
   local tGrid, tLine, tWas
   switch sHist[pN]["kind"]
      case "cell"
         if sHist[pN]["what"] is "slope" then
            CellMap.SetSlope sMap, sHist[pN]["a"], sHist[pN]["b"], sHist[pN][pWhich]
            return "map"
         end if
         put sHist[pN][pWhich] into sMap[sHist[pN]["what"]][sHist[pN]["b"]][sHist[pN]["a"]]
         return "map"
      case "bit"
         put CellMap.Glyph(sFont, sHist[pN]["what"]) into tGrid
         put line sHist[pN]["b"] of tGrid into tLine
         put sHist[pN][pWhich] into char sHist[pN]["a"] of tLine
         put tLine into line sHist[pN]["b"] of tGrid
         put CellMap.GlyphToRows(tGrid) into sFont[sHist[pN]["what"]]
         return "font" && sHist[pN]["what"]
      case "glyph"
         put sHist[pN][pWhich] into sFont[sHist[pN]["what"]]
         return "font" && sHist[pN]["what"]
      case "map"
         put sHist[pN][pWhich] into sMap
         return "whole"
   end switch
   return empty
end edApply

-- the last stroke (or command) back to what it was: every one of its changes, newest first
on Ed.Undo
   local tStroke, tSeen, tName, tCount
   if sStrokeKind is not empty then Ed.StrokeEnd
   if sHistN < 1 then
      Ed.Status "nothing to undo"
      exit Ed.Undo
   end if
   put sHist[sHistN]["stroke"] into tStroke
   put sHist[sHistN]["name"] into tName
   put 0 into tCount
   repeat while sHistN >= 1
      if sHist[sHistN]["stroke"] is not tStroke then exit repeat
      edApply sHistN, "old"
      put true into tSeen[the result]
      subtract 1 from sHistN
      add 1 to tCount
   end repeat
   Ed.AfterHistory tSeen
   Ed.Status "undid:" && tName && "(" & tCount && "changes; Ctrl+Y brings them back)"
end Ed.Undo

on Ed.Redo
   local tStroke, tSeen, tName, tCount
   if sStrokeKind is not empty then Ed.StrokeEnd
   if sHistN >= sHistMax then
      Ed.Status "nothing to redo"
      exit Ed.Redo
   end if
   put sHist[sHistN + 1]["stroke"] into tStroke
   put sHist[sHistN + 1]["name"] into tName
   put 0 into tCount
   repeat while sHistN < sHistMax
      if sHist[sHistN + 1]["stroke"] is not tStroke then exit repeat
      add 1 to sHistN
      edApply sHistN, "new"
      put true into tSeen[the result]
      add 1 to tCount
   end repeat
   Ed.AfterHistory tSeen
   Ed.Status "redid:" && tName && "(" & tCount && "changes)"
end Ed.Redo

-- redraw what undo or redo touched: glyph pictures, the board, the map, the 3D preview
on Ed.AfterHistory pSeen
   local tKey, tFont
   put false into tFont
   repeat for each key tKey in pSeen
      if word 1 of tKey is "font" then
         put true into tFont
         Ed.GlyphImage word 2 of tKey
      end if
      if tKey is "map" or tKey is "whole" then put true into sDirtyMap
      if tKey is "whole" then put empty into sHover
   end repeat
   if tFont then
      put true into sDirtyFont
      put empty into sCache
      Ed.FillGlyphs
      Ed.DrawGlyph
   end if
   Ed.Changed
   Ed.MakeGhost
   Ed.MenuMarks
   if sHover is not empty then Ed.ShowHover
   put false into sDirtyGlyph
   put false into sDirty2D
   put false into sDirty3D
end Ed.AfterHistory

-- "done,undone" lines of the history, for tests and the status line
function Ed.HistCount
   return sHistN & comma & (sHistMax - sHistN)
end Ed.HistCount

-- the history as text, one change a line (tab between): number, stroke, time in ms since the
-- first change, kind, what, a, b, old, new, stroke name. Paths and animation can replay it.
function Ed.HistText
   local n, tOut, tT0, tOld, tNew
   put sHist[1]["ms"] into tT0
   put "# BitEditor change history: n, stroke, ms, kind, what (layer or glyph), col, row, old, new, stroke name" & return into tOut
   put 1 into n
   repeat while n <= sHistN
      put sHist[n]["old"] into tOld
      put sHist[n]["new"] into tNew
      if sHist[n]["kind"] is "map" then
         put "(whole map)" into tOld
         put "(whole map)" into tNew
      else if sHist[n]["what"] is "tags" then
         put codepointToNum(tOld) into tOld          -- tag characters as numbers (a space or # would hide)
         put codepointToNum(tNew) into tNew
      end if
      put n & tab & sHist[n]["stroke"] & tab & (sHist[n]["ms"] - tT0) & tab & sHist[n]["kind"] & tab & sHist[n]["what"] & tab & sHist[n]["a"] & tab & sHist[n]["b"] & tab & \
            tOld & tab & tNew & tab & sHist[n]["name"] & return after tOut
      add 1 to n
   end repeat
   return tOut
end Ed.HistText

on Ed.EditMenu pItem
   local tFile
   switch pItem
      case "Undo (Ctrl+Z)"
         Ed.Undo
         break
      case "Redo (Ctrl+Y)"
         Ed.Redo
         break
      case "Export Change History"
         put sDir & "/maps/" & sMap["meta"]["name"] & "_history.txt" into tFile
         put textEncode(Ed.HistText(), "UTF-8") into URL ("binfile:" & tFile)
         Ed.Status "wrote" && Ed.ShortName(tFile) && "(" & sHistN && "changes)"
         break
   end switch
end Ed.EditMenu

-- Ctrl+Z, Ctrl+Y, Ctrl+Shift+Z (typing in the Filter keeps its own keys)
on commandKeyDown pKey
   local tFocus
   put the focusedObject into tFocus
   if tFocus is not empty then
      if word 1 of tFocus is "field" then
         if the short name of tFocus is "Filter" then pass commandKeyDown
      end if
   end if
   if pKey is "z" and the shiftKey is down then
      Ed.Redo
   else if pKey is "z" then
      Ed.Undo
   else if pKey is "y" then
      Ed.Redo
   else
      pass commandKeyDown
   end if
end commandKeyDown

-------------------------------------------------------------------- middle: the 2D map, one picture, three views

-- grey n on screen: 0 is black, 1 is already visible, 255 is white
function Ed.GreyShown pN
   if pN <= 0 then return 0
   return 40 + round(pN * 215 / 255)
end Ed.GreyShown

function Ed.TintShown pN
   return 90 + round(pN * 165 / 255)
end Ed.TintShown

-- the floor colour of a cell: its grey, or red where a pit is dug (deeper = brighter)
function Ed.FloorColour pF, pR
   local g
   put Ed.GreyShown(pF) into g
   if pR > 0 then return Ed.TintShown(pR) & comma & (g div 4) & comma & (g div 4)
   return g & comma & g & comma & g
end Ed.FloorColour

-- the ceiling colour: its grey; green and blue take their channels where something is built above
function Ed.CeilColour pC, pG, pB
   local g, tG, tB
   put Ed.GreyShown(pC) into g
   if pG <= 0 and pB <= 0 then return g & comma & g & comma & g
   put g div 4 into tG
   put g div 4 into tB
   if pG > 0 then put Ed.TintShown(pG) into tG
   if pB > 0 then put Ed.TintShown(pB) into tB
   return (g div 4) & comma & tG & comma & tB
end Ed.CeilColour

function Ed.HeightsOf pC, pR
   return "floor" && sMap["floor"][pR][pC] & "  ceiling" && sMap["ceiling"][pR][pC] & "  red" && sMap["red"][pR][pC] & \
         "  green" && sMap["green"][pR][pC] & "  blue" && sMap["blue"][pR][pC] & Ed.FromShort(sMap["from"][pR][pC]) & Ed.SlopeShort(pC, pR)
end Ed.HeightsOf

-- a cell's slope in a few words for the hover line ("" when flat)
function Ed.SlopeShort pC, pR
   local tS
   put CellMap.Slope(sMap, pC, pR) into tS
   if tS is empty then return empty
   if CellMap.Steep(sMap, pC, pR) then return "  SLOPE nw,ne,se,sw" && tS && "(STEEP: cannot be walked up)"
   return "  SLOPE nw,ne,se,sw" && tS
end Ed.SlopeShort

-- a cell's From flags in a few words for the hover line ("" when both are off)
function Ed.FromShort pFlags
   put pFlags + 0 into pFlags
   if pFlags is 3 then return "  FROM FLOOR + CEILING"
   if pFlags is 1 then return "  FROM FLOOR"
   if pFlags is 2 then return "  FROM CEILING"
   return empty
end Ed.FromShort

-- one cell's picture: sPx lines of sPx pixels (4 bytes each), glyph bits in pFore on pBack
private function edCellLines pCode, pFore, pBack, pBlocks
   local tKey, tGlyph, tF, tB, tRows, g, x, tLine, tBits, tOut, y
   put pCode & "|" & pFore & "|" & pBack & "|" & pBlocks & "|" & sPx into tKey
   if sCache[tKey] is an array then return sCache[tKey]
   if pBlocks then
      -- blocks: a square of the first colour framed by the second
      put "0000000000000000" & return & "0000000000000000" into tGlyph
      repeat 12 times
         put return & "0011111111111100" after tGlyph
      end repeat
      put return & "0000000000000000" & return & "0000000000000000" after tGlyph
   else
      put CellMap.Glyph(sFont, pCode) into tGlyph
   end if
   put edPixel(pFore) into tF
   put edPixel(pBack) into tB
   put 1 into g
   repeat for each line tBits in tGlyph
      put empty into tLine
      put 0 into x
      repeat while x < sPx
         if char (x * 16 div sPx + 1) of tBits is "1" then
            put tF after tLine
         else
            put tB after tLine
         end if
         add 1 to x
      end repeat
      put tLine into tRows[g]
      add 1 to g
   end repeat
   put 0 into y
   repeat while y < sPx
      put tRows[y * 16 div sPx + 1] into tOut[y + 1]
      add 1 to y
   end repeat
   put tOut into sCache[tKey]
   return tOut
end edCellLines

-- a cell's From flags drawn on its picture: From Floor a bar along its bottom (orange), From Ceiling
-- along its top (sky blue)
private function edFromMarks pLines, pFlags
   local tBar, tRow, y, tN
   put max(1, sPx div 8) into tN
   if (pFlags bitAnd 1) is not 0 then
      put empty into tRow
      repeat sPx times
         put edPixel("255,150,0") after tRow
      end repeat
      repeat with y = sPx - tN + 1 to sPx
         put tRow into pLines[y]
      end repeat
   end if
   if (pFlags bitAnd 2) is not 0 then
      put empty into tRow
      repeat sPx times
         put edPixel("90,200,255") after tRow
      end repeat
      repeat with y = 1 to tN
         put tRow into pLines[y]
      end repeat
   end if
   return pLines
end edFromMarks

-- a sloped cell drawn on its picture (CELLMAP_V3.md 6): an arrow pointing uphill, brighter for higher,
-- red when the cell is steep; a dot in every lifted corner (a twisted cell has no single uphill)
private function edSlopeMarks pLines, pC, pR
   local tS, tPx, tTop, v, gx, gy, tLen, ux, uy, m, L, tW, tHead, a, tCos, tSin, k, tCorner, x, y
   put CellMap.Slope(sMap, pC, pR) into tS
   if tS is empty then return pLines
   if CellMap.Steep(sMap, pC, pR) then
      put edPixel("255,60,60") into tPx
   else
      put max(tS) into tTop
      put 160 + round(tTop * 95 / 255) into v
      put edPixel(v & comma & v & comma & (v div 4)) into tPx
   end if
   put (sPx - 1) / 2 into m
   put max(1, sPx div 10) into tW
   -- the dots: a lifted corner
   put max(1, sPx div 8) into k
   repeat with tCorner = 1 to 4
      if item tCorner of tS <= 0 then next repeat
      if tCorner is 1 or tCorner is 4 then put 1 into x else put sPx - k - 1 into x
      if tCorner is 1 or tCorner is 2 then put 1 into y else put sPx - k - 1 into y
      put edDot(pLines, x, y, k, tPx) into pLines
   end repeat
   -- the arrow: along the way the ground rises (east and south are + in the picture)
   put (item 2 of tS + item 3 of tS - item 1 of tS - item 4 of tS) / 2 into gx
   put (item 3 of tS + item 4 of tS - item 1 of tS - item 2 of tS) / 2 into gy
   put sqrt(gx * gx + gy * gy) into tLen
   if tLen is 0 or sPx < 6 then return pLines
   put gx / tLen into ux
   put gy / tLen into uy
   put sPx * 0.32 into L
   put edLine(pLines, m - ux * L, m - uy * L, m + ux * L, m + uy * L, tW, tPx) into pLines
   put L * 0.6 into tHead
   repeat for each item a in "0.6,-0.6"
      put cos(a) into tCos
      put sin(a) into tSin
      put edLine(pLines, m + ux * L, m + uy * L, m + ux * L - (ux * tCos - uy * tSin) * tHead, m + uy * L - (ux * tSin + uy * tCos) * tHead, tW, tPx) into pLines
   end repeat
   return pLines
end edSlopeMarks

-- a k x k square of one pixel colour at x,y (0-based) of a cell picture
private function edDot pLines, pX, pY, pK, pPx
   local x, y, tX, tY
   repeat with y = 0 to pK - 1
      put round(pY) + y into tY
      if tY < 0 or tY >= sPx then next repeat
      repeat with x = 0 to pK - 1
         put round(pX) + x into tX
         if tX < 0 or tX >= sPx then next repeat
         put pPx into byte (tX * 4 + 1) to (tX * 4 + 4) of pLines[tY + 1]
      end repeat
   end repeat
   return pLines
end edDot

-- a line pW pixels wide from x1,y1 to x2,y2 (0-based, fractions allowed) on a cell picture
private function edLine pLines, pX1, pY1, pX2, pY2, pW, pPx
   local n, i, h
   put max(1, round(max(abs(pX2 - pX1), abs(pY2 - pY1)) * 2)) into n
   put (pW - 1) / 2 into h
   repeat with i = 0 to n
      put edDot(pLines, pX1 + (pX2 - pX1) * i / n - h, pY1 + (pY2 - pY1) * i / n - h, pW, pPx) into pLines
   end repeat
   return pLines
end edLine

-- the two colours of a cell in the current view: "fore|back"
function Ed.CellColours pC, pR
   local tFloor, tCeil, tBack
   switch sTab
      case "Slope"
         put Ed.FloorColour(sMap["floor"][pR][pC], sMap["red"][pR][pC]) into tFloor
         put Ed.CeilColour(sMap["ceiling"][pR][pC], sMap["green"][pR][pC], sMap["blue"][pR][pC]) into tCeil
         return tFloor & "|" & tCeil
      case "Heights"
         put Ed.FloorColour(sMap["floor"][pR][pC], sMap["red"][pR][pC]) into tFloor
         put Ed.CeilColour(sMap["ceiling"][pR][pC], sMap["green"][pR][pC], sMap["blue"][pR][pC]) into tCeil
         if sHTool is "ceiling" then return tCeil & "|" & tFloor
         return tFloor & "|" & tCeil
      case "Cells"
         put Ed.RGB(CellMap.TagInfo(sMap, sTags, sMap["tags"][pR][pC], "colour")) into tBack
         if tBack is empty then put kDark into tBack
         return Ed.Contrast(tBack) & "|" & tBack
   end switch
   return kLit & "|" & kDark
end Ed.CellColours

-- the whole map as one picture, as big as fits its place
on Ed.DrawMap
   local tCols, tRows, r, c, y, tData, tPair, tLine, tLeft, tTop, tBlocks
   if there is not an image "Map2D" then exit Ed.DrawMap
   if sMap["floor"] is not an array then exit Ed.DrawMap
   put sMap["meta"]["cols"] into tCols
   put sMap["meta"]["rows"] into tRows
   put max(4, min(kMapW div tCols, kMapH div tRows, 40)) into sPx
   put (sHBlocks and (sTab is "Heights" or sTab is "Slope")) into tBlocks
   set the itemDel to "|"
   put 1 into r
   repeat while r <= tRows
      put 1 into c
      repeat while c <= tCols
         put Ed.CellColours(c, r) into tPair
         put edCellLines(sMap["design"][r][c], item 1 of tPair, item 2 of tPair, tBlocks) into tLine[c]
         if sTab is "Heights" and sMap["from"][r][c] > 0 then put edFromMarks(tLine[c], sMap["from"][r][c]) into tLine[c]
         if (sTab is "Heights" or sTab is "Slope") and sMap["slope"][r][c] is not empty then put edSlopeMarks(tLine[c], c, r) into tLine[c]
         add 1 to c
      end repeat
      put 1 into y
      repeat while y <= sPx
         put 1 into c
         repeat while c <= tCols
            put tLine[c][y] after tData
            add 1 to c
         end repeat
         add 1 to y
      end repeat
      add 1 to r
   end repeat
   set the itemDel to comma
   put the left of graphic "MapFrame" + 8 into tLeft
   put the top of graphic "MapFrame" + 134 into tTop
   lock screen
   set the lockLoc of image "Map2D" to true
   set the rect of image "Map2D" to tLeft, tTop, tLeft + tCols * sPx, tTop + tRows * sPx
   set the imageData of image "Map2D" to tData
   unlock screen
end Ed.DrawMap

-- after ANY change to the map or its font: the 2D picture and the 3D preview, at once
on Ed.Changed
   Ed.DrawMap
   Ed.Build3D
   Ed.Draw3D
end Ed.Changed

-- 1bit, Cells or Heights: three views of the same map
on Ed.MapTab pTab
   if pTab is not among the items of "1bit,Cells,Heights,Slope" then put "1bit" into pTab
   put pTab into sTab
   lock screen
   Ed.TabShow "Map", pTab
   set the visible of group "HeightTools" to (pTab is "Heights")
   if there is a group "SlopeTools" then set the visible of group "SlopeTools" to (pTab is "Slope")
   Ed.DrawMap
   Ed.HShowTool
   Ed.SShowTool
   unlock screen
   Ed.GhostMove
   Ed.ShowWhat
end Ed.MapTab

-- what a click on the map does right now, in words: the first line over the map
function Ed.What
   if sTab is "Heights" then return "HEIGHT:" && Ed.HPainting()
   if sTab is "Slope" then return "SLOPE:" && Ed.SPainting()
   if sLeft is "Properties" then
      if sPropHeight then return "PROPERTY:" && Ed.CharShown(sTag) && sTags[sTag]["name"] & ", with its height (" & Ed.PropFloor() & ")"
      return "PROPERTY:" && Ed.CharShown(sTag) && sTags[sTag]["name"] & " (heights untouched)"
   end if
   return "GLYPH:" && sCode && Ed.CharShown(sCode) && "(" & Ed.GlyphLabel(sCode) & ")"
end Ed.What

on Ed.ShowWhat
   if there is not a field "PaintInfo" then exit Ed.ShowWhat
   put "A CLICK PAINTS  " & toUpper(Ed.What()) into line 1 of field "PaintInfo"
end Ed.ShowWhat

-- the floor a property brings: its own default, or the Mesh menu's choice
function Ed.PropFloor
   local tChar
   put sTags[sTag]["char"] into tChar
   if tChar is empty then put "x" into tChar
   if sExtrude is "tag" then return CellMap.H1ToFloor(sTags[sTag]["height"], tChar)
   return CellMap.H1ToFloor(sExtrude, tChar)
end Ed.PropFloor

-- "col,row" under the mouse, empty outside the map picture
function Ed.MapCell
   local tX, tY
   if there is not an image "Map2D" or sPx is not a number then return empty
   put the mouseH - the left of image "Map2D" into tX
   put the mouseV - the top of image "Map2D" into tY
   if tX < 0 or tY < 0 or tX >= the width of image "Map2D" or tY >= the height of image "Map2D" then return empty
   return (tX div sPx + 1) & comma & (tY div sPx + 1)
end Ed.MapCell

-- the part of the cell under the mouse the Slope tool lifts: a corner (nw ne se sw) when the mouse is
-- in its third of both ways, else the nearest edge (n e s w)
function Ed.MapPart
   local tX, tY
   if there is not an image "Map2D" or sPx is not a number then return sSlopePart
   put ((the mouseH - the left of image "Map2D") mod sPx + 0.5) / sPx into tX
   put ((the mouseV - the top of image "Map2D") mod sPx + 0.5) / sPx into tY
   return Ed.PartAt(tX, tY)
end Ed.MapPart

-- pX, pY: 0 to 1 across the cell (west to east, north to south)
function Ed.PartAt pX, pY
   local tNS, tWE
   if pY < 1 / 3 then put "n" into tNS
   if pY > 2 / 3 then put "s" into tNS
   if pX < 1 / 3 then put "w" into tWE
   if pX > 2 / 3 then put "e" into tWE
   if tNS is not empty and tWE is not empty then return tNS & tWE
   if min(pX, 1 - pX) < min(pY, 1 - pY) then
      if pX < 0.5 then return "w"
      return "e"
   end if
   if pY < 0.5 then return "n"
   return "s"
end Ed.PartAt

-- the corners (1 nw, 2 ne, 3 se, 4 sw) an edge or corner name lifts
function Ed.PartCorners pPart
   switch pPart
      case "n"
         return "1,2"
      case "e"
         return "2,3"
      case "s"
         return "3,4"
      case "w"
         return "1,4"
      case "nw"
         return "1"
      case "ne"
         return "2"
      case "se"
         return "3"
      case "sw"
         return "4"
   end switch
   return empty
end Ed.PartCorners

function Ed.PartWords pPart
   switch pPart
      case "n"
         return "north edge"
      case "e"
         return "east edge"
      case "s"
         return "south edge"
      case "w"
         return "west edge"
   end switch
   return pPart && "corner"
end Ed.PartWords

-- the layer a height click changes: a grey goes to the tool's layer, the colours to their own
function Ed.HTarget
   if sHLayer is "grey" then return sHTool
   return sHLayer
end Ed.HTarget

on Ed.MapDown pButton
   local tCell, tC, tR
   put Ed.MapCell() into tCell
   if tCell is empty then exit Ed.MapDown
   put item 1 of tCell into tC
   put item 2 of tCell into tR
   put tCell into sLastCell
   if there is a graphic "MarkBox" then set the visible of graphic "MarkBox" to false
   if pButton is 3 or the optionKey is down then
      Ed.PickUp tC, tR
      exit Ed.MapDown
   end if
   if sTab is "Slope" then
      if sSMode is "ramp" then
         Ed.RampBegin tCell
         exit Ed.MapDown
      end if
      if sSDir is "auto" then
         put Ed.MapPart() into sSlopePart
      else
         put sSDir into sSlopePart
      end if
   end if
   Ed.StrokeBegin "map", "paint" && toLower(Ed.What())
   put tCell into sStrokeAt
   Ed.PaintCell tC, tR
   Ed.StrokeTick sTickId
end Ed.MapDown

-- pick up what is in a cell, for the thing being painted
on Ed.PickUp pC, pR
   if sTab is "Slope" then
      put CellMap.Slope(sMap, pC, pR) into sSlopeStamp
      if sSlopeStamp is empty then put "0,0,0,0" into sSlopeStamp
      put "cell" into sSMode
      Ed.SShowTool
   else if sTab is "Heights" then
      put sMap[Ed.HTarget()][pR][pC] + 0 into sHValue
      if sHLayer is "from" then put sHValue into sHFrom
      Ed.HShowTool
   else if sLeft is "Properties" then
      Ed.SelectTag codepointToNum(sMap["tags"][pR][pC])
   else
      Ed.SelectCode sMap["design"][pR][pC]
   end if
   Ed.ShowWhat
   Ed.Status "picked from col" && pC && "row" && pR & ":" && Ed.What()
end Ed.PickUp

on Ed.MapMove
   local tCell
   put Ed.MapCell() into tCell
   if tCell is empty and sCamOn is not true then put Ed.ViewCell() into tCell     -- the 3D preview hovers too
   if tCell is not sHover then
      put tCell into sHover
      Ed.ShowHover
      Ed.Draw3DCursor
   end if
end Ed.MapMove

-- the second line over the map: everything about the cell under the mouse
on Ed.ShowHover
   local tC, tR, tTag
   if there is not a field "PaintInfo" then exit Ed.ShowHover
   if sHover is empty then
      put empty into line 2 of field "PaintInfo"
      exit Ed.ShowHover
   end if
   put item 1 of sHover into tC
   put item 2 of sHover into tR
   put sMap["tags"][tR][tC] into tTag
   put "col" && tC && "row" && tR & ":" && CellMap.TagInfo(sMap, sTags, tTag, "name") && "(" & CellMap.TagInfo(sMap, sTags, tTag, "effect") & ")  glyph" && \
         sMap["design"][tR][tC] & "  " & Ed.HeightsOf(tC, tR) into line 2 of field "PaintInfo"
end Ed.ShowHover

-- one click as one undo step (tests, scripts); a drag is a stroke of Ed.PaintCell
on Ed.PaintAt pC, pR
   Ed.StrokeBegin "call", "paint" && toLower(Ed.What())
   Ed.PaintCell pC, pR
   Ed.StrokeEnd
end Ed.PaintAt

-- one cell of a stroke: a height, a property or a glyph (see Ed.What)
on Ed.PaintCell pC, pR
   local tChar
   if sTab is "Slope" then
      if sSMode is "flatten" then
         Ed.SetSlope pC, pR, empty
      else if sSMode is "cell" then
         Ed.SlopeCell pC, pR
      else
         Ed.Status "Ramp: drag a box on the 2D map (One Cell paints in 3D)"
      end if
   else if sTab is "Heights" then
      Ed.SetCell Ed.HTarget(), pC, pR, sHValue
   else if sLeft is "Properties" then
      put sTags[sTag]["char"] into tChar
      if tChar is empty then
         Ed.Status "property" && sTag && "has no character: it cannot be written in a map (pick one from 32 up)"
         exit Ed.PaintCell
      end if
      Ed.SetCell "tags", pC, pR, tChar
      if sPropHeight then
         Ed.SetCell "floor", pC, pR, Ed.PropFloor()
      end if
   else
      Ed.SetCell "design", pC, pR, sCode
   end if
end Ed.PaintCell

-------------------------------------------------------------------- the Slope tab (cellmap v3; owner's notes 19 Nov 2026)

-- what a click does on the Slope tab, in words
function Ed.SPainting
   local tWay
   if sSDir is "auto" then
      put "the way you drag" into tWay
   else
      put toUpper(sSDir) into tWay
   end if
   switch sSMode
      case "flatten"
         return "Flatten (cells painted flat; their floor stays)"
      case "cell"
         if sSlopeStamp is not empty then return "One Cell: the copied slope nw,ne,se,sw" && sSlopeStamp && "(a swatch ends the copy)"
         if sSValue <= 0 then return "One Cell, rise 0: flattens"
         if sSDir is "auto" then return "One Cell: lift the edge or corner nearest the click by" && sSValue && "hu"
         return "One Cell: lift the" && Ed.PartWords(sSDir) && "by" && sSValue && "hu"
   end switch
   if sSJoin then return "Ramp: drag a box; uphill" && tWay & ", from the floor before it to the floor after it (else by" && sSValue && "hu)"
   return "Ramp: drag a box; uphill" && tWay & ", rising" && sSValue && "hu across it"
end Ed.SPainting

on Ed.SShowTool
   local tD
   if there is not a group "SlopeTools" then exit Ed.SShowTool
   repeat for each item tD in "NW,N,NE,W,Auto,E,SW,S,SE"
      set the hilite of button ("SDir" & tD) to (toLower(tD) is sSDir)
   end repeat
   set the hilite of button "SModeRamp" to (sSMode is "ramp")
   set the hilite of button "SModeCell" to (sSMode is "cell")
   set the hilite of button "SModeFlatten" to (sSMode is "flatten")
   set the hilite of button "SJoin" to sSJoin
   set the enabled of button "SJoin" to (sSMode is "ramp")
   put Ed.SPainting() into field "SWords"
   if there is a graphic ("ss_" & sSValue) and sSlopeStamp is empty then
      set the rect of graphic "SSel" to the left of graphic ("ss_" & sSValue) - 1, 165, the right of graphic ("ss_" & sSValue) + 1, 182
      set the visible of graphic "SSel" to true
   else
      set the visible of graphic "SSel" to false
   end if
end Ed.SShowTool

on Ed.SDir pDir
   if pDir is not among the items of "auto,n,ne,e,se,s,sw,w,nw" then exit Ed.SDir
   put pDir into sSDir
   Ed.SShowTool
   Ed.ShowWhat
end Ed.SDir

on Ed.SMode pMode
   if pMode is not among the items of "ramp,cell,flatten" then exit Ed.SMode
   put pMode into sSMode
   put empty into sSlopeStamp
   Ed.SShowTool
   Ed.ShowWhat
end Ed.SMode

on Ed.SJoin pOn
   if pOn is empty then put not sSJoin into pOn
   put (pOn is true) into sSJoin
   Ed.SShowTool
   Ed.ShowWhat
end Ed.SJoin

-- a rise swatch "ss_<value>"
on Ed.SSwatch pName
   set the itemDel to "_"
   put item 2 of pName into sSValue
   set the itemDel to comma
   put empty into sSlopeStamp
   Ed.SShowTool
   Ed.ShowWhat
end Ed.SSwatch

-- "dx,dy" of an uphill word (east and south are +)
function Ed.DirVector pDir
   switch pDir
      case "n"
         return "0,-1"
      case "ne"
         return "1,-1"
      case "e"
         return "1,0"
      case "se"
         return "1,1"
      case "s"
         return "0,1"
      case "sw"
         return "-1,1"
      case "w"
         return "-1,0"
      case "nw"
         return "-1,-1"
   end switch
   return empty
end Ed.DirVector

-- Ramp: the press starts a box; it follows the mouse (framed) until the release paints it
on Ed.RampBegin pCell
   put pCell into sRampFrom
   if sRampFrom is empty then put pCell into sRampFrom
   put Ed.MapPart() into sSlopePart       -- a click with Auto: the edge or corner nearest it
   add 1 to sRampId
   Ed.RampTick sRampId
end Ed.RampBegin

on Ed.RampTick pId
   local tCell, tL, tT
   if pId is not sRampId or sRampFrom is empty then exit Ed.RampTick
   put Ed.MapCell() into tCell
   if tCell is empty then put sStrokeAt into tCell
   if tCell is empty then put sRampFrom into tCell
   put tCell into sStrokeAt
   if the mouse is up then
      put sRampFrom into tL
      put empty into sRampFrom
      put empty into sStrokeAt
      if there is a graphic "MarkBox" then set the visible of graphic "MarkBox" to false
      Ed.Ramp tL, tCell
      exit Ed.RampTick
   end if
   if there is a graphic "MarkBox" and sPx is a number then
      put the left of image "Map2D" + (min(item 1 of sRampFrom, item 1 of tCell) - 1) * sPx into tL
      put the top of image "Map2D" + (min(item 2 of sRampFrom, item 2 of tCell) - 1) * sPx into tT
      set the rect of graphic "MarkBox" to tL - 2, tT - 2, \
            the left of image "Map2D" + max(item 1 of sRampFrom, item 1 of tCell) * sPx + 2, the top of image "Map2D" + max(item 2 of sRampFrom, item 2 of tCell) * sPx + 2
      set the visible of graphic "MarkBox" to true
   end if
   send "Ed.RampTick" && pId to me in 30 milliseconds
end Ed.RampTick

-- a box of cells from pFrom to pTo ("col,row" each) becomes ONE slope rising the compass way (Auto: from
-- pFrom towards pTo). Every cell continues where its neighbour ends: corner heights are one plane over the
-- box; each cell gets floor = base + its lowest corner and rises = its corners above that. Base: the floor
-- just before the box (else the box's own low cell); the climb: with Join the floor just after the box
-- minus the base, else (or when that is not higher) the swatch. One undo.
on Ed.Ramp pFrom, pTo
   local c0, c1, r0, r1, w, h, tV, dx, dy, dc, dr, pMin, pMax, tP, u, v, cL, rL, cH, rH, tBase, tH, tHigh
   local c, r, tK, tNW, tNE, tSE, tSW, m, tMid, n
   put min(item 1 of pFrom, item 1 of pTo) into c0
   put max(item 1 of pFrom, item 1 of pTo) into c1
   put min(item 2 of pFrom, item 2 of pTo) into r0
   put max(item 2 of pFrom, item 2 of pTo) into r1
   put max(1, c0) into c0
   put max(1, r0) into r0
   put min(sMap["meta"]["cols"], c1) into c1
   put min(sMap["meta"]["rows"], r1) into r1
   if c0 > c1 or r0 > r1 then exit Ed.Ramp
   put c1 - c0 + 1 into w
   put r1 - r0 + 1 into h
   if sSDir is "auto" then
      put item 1 of pTo - item 1 of pFrom into dc
      put item 2 of pTo - item 2 of pFrom into dr
      if dc is 0 and dr is 0 then
         put Ed.DirVector(sSlopePart) into tV          -- a click: the edge or corner nearest it
      else if abs(dc) >= 2 * abs(dr) then
         put edSign(dc) & ",0" into tV
      else if abs(dr) >= 2 * abs(dc) then
         put "0," & edSign(dr) into tV
      else
         put edSign(dc) & comma & edSign(dr) into tV
      end if
   else
      put Ed.DirVector(sSDir) into tV
   end if
   put item 1 of tV into dx
   put item 2 of tV into dy
   if dx is 0 and dy is 0 then exit Ed.Ramp
   -- the plane: p = u * dx + v * dy over the box's grid corners (u 0..w, v 0..h)
   put min(0, w * dx) + min(0, h * dy) into pMin
   put max(0, w * dx) + max(0, h * dy) into pMax
   -- the low and high sides, and the cells just outside them
   put (c0 + c1) div 2 into cL
   put cL into cH
   if dx > 0 then
      put c0 into cL
      put c1 into cH
   else if dx < 0 then
      put c1 into cL
      put c0 into cH
   end if
   put (r0 + r1) div 2 into rL
   put rL into rH
   if dy > 0 then
      put r0 into rL
      put r1 into rH
   else if dy < 0 then
      put r1 into rL
      put r0 into rH
   end if
   put Ed.FloorAt(cL - dx, rL - dy) into tBase
   if tBase <= 0 then put Ed.FloorAt(cL, rL) into tBase
   if tBase <= 0 then put 1 into tBase
   put sSValue into tH
   if sSJoin then
      put Ed.FloorAt(cH + dx, rH + dy) into tHigh
      if tHigh > tBase then put tHigh - tBase into tH
   end if
   put min(tH, 255 - tBase) into tH
   if tH <= 0 then
      Ed.Status "ramp: nothing to climb (pick a rise swatch, or a higher floor after the box)"
      exit Ed.Ramp
   end if
   Ed.StrokeBegin "call", "ramp"
   repeat with r = r0 to r1
      repeat with c = c0 to c1
         put c - c0 into u
         put r - r0 into v
         put round(tH * ((u * dx + v * dy) - pMin) / (pMax - pMin)) into tNW
         put round(tH * (((u + 1) * dx + v * dy) - pMin) / (pMax - pMin)) into tNE
         put round(tH * (((u + 1) * dx + (v + 1) * dy) - pMin) / (pMax - pMin)) into tSE
         put round(tH * ((u * dx + (v + 1) * dy) - pMin) / (pMax - pMin)) into tSW
         put min(tNW, tNE, tSE, tSW) into m
         Ed.SetCell "floor", c, r, tBase + m
         Ed.SetCell "red", c, r, 0                     -- a pit under a ramp would break it
         Ed.SetSlope c, r, (tNW - m) & comma & (tNE - m) & comma & (tSE - m) & comma & (tSW - m)
      end repeat
   end repeat
   Ed.StrokeEnd
   Ed.Status "ramp: cols" && c0 & "-" & c1 && "rows" && r0 & "-" & r1 & ", uphill" && Ed.DirWord(dx, dy) & ", floor" && tBase && "to" && tBase + tH && "(Ctrl+Z undoes it)"
end Ed.Ramp

private function edSign pN
   if pN > 0 then return 1
   if pN < 0 then return -1
   return 0
end edSign

function Ed.FloorAt pC, pR
   if pC < 1 or pR < 1 or pC > sMap["meta"]["cols"] or pR > sMap["meta"]["rows"] then return 0
   return sMap["floor"][pR][pC] - sMap["red"][pR][pC]
end Ed.FloorAt

function Ed.DirWord pDX, pDY
   local tOut
   if pDY < 0 then put "N" into tOut
   if pDY > 0 then put "S" into tOut
   if pDX > 0 then put "E" after tOut
   if pDX < 0 then put "W" after tOut
   return tOut
end Ed.DirWord

-- the Slope tool on one cell (CELLMAP_V3.md 6): the picked-up rises, or the brush's rise on the part
-- (edge or corner) chosen where the stroke began; grey 0 flattens. Kept tidy: when all four corners
-- end up lifted they are lowered and the floor raised by the same amount
on Ed.SlopeCell pC, pR
   local tS, i, tLow, tFloor
   if pC < 1 or pR < 1 or pC > sMap["meta"]["cols"] or pR > sMap["meta"]["rows"] then exit Ed.SlopeCell
   if sMap["floor"][pR][pC] <= 0 then
      Ed.Status "col" && pC && "row" && pR && "has floor 0 (empty): give it a floor before sloping it"
      exit Ed.SlopeCell
   end if
   if sSlopeStamp is not empty then
      put sSlopeStamp into tS
   else if sSValue <= 0 then
      put "0,0,0,0" into tS
   else
      put CellMap.Slope(sMap, pC, pR) into tS
      if tS is empty then put "0,0,0,0" into tS
      repeat for each item i in Ed.PartCorners(sSlopePart)
         put min(255, sSValue) into item i of tS
      end repeat
   end if
   put min(tS) into tLow
   put sMap["floor"][pR][pC] into tFloor
   if tLow > 0 and tFloor + tLow <= 255 then
      repeat with i = 1 to 4
         subtract tLow from item i of tS
      end repeat
      Ed.SetCell "floor", pC, pR, tFloor + tLow
   end if
   Ed.SetSlope pC, pR, tS
end Ed.SlopeCell

-- the part the next Slope click lifts (scripts, tests): n e s w, nw ne se sw
on Ed.SlopePart pPart
   if Ed.PartCorners(pPart) is empty then exit Ed.SlopePart
   put pPart into sSlopePart
   Ed.ShowWhat
end Ed.SlopePart

-- a cell's slope "nw,ne,se,sw" (empty or zeros = flat), recorded like any cell
on Ed.SetSlope pC, pR, pRises
   local tOld, tNew
   put CellMap.Slope(sMap, pC, pR) into tOld
   put pRises into tNew
   if tNew is "0,0,0,0" then put empty into tNew
   if tOld is tNew then exit Ed.SetSlope
   CellMap.SetSlope sMap, pC, pR, tNew
   put CellMap.Slope(sMap, pC, pR) into tNew
   if tOld is tNew then exit Ed.SetSlope
   Ed.Record "cell", "slope", pC, pR, tOld, tNew
   put true into sDirtyMap
   put true into sDirty2D
   put true into sDirty3D
end Ed.SetSlope

-------------------------------------------------------------------- the ghost: the glyph about to be painted

on Ed.MakeGhost
   local tLines, tData, y
   if there is not an image "Ghost" or sPx is not a number then exit Ed.MakeGhost
   put edCellLines(sCode, "255,214,10", kDark, false) into tLines
   put 1 into y
   repeat while y <= sPx
      put tLines[y] after tData
      add 1 to y
   end repeat
   lock screen
   set the lockLoc of image "Ghost" to true
   set the width of image "Ghost" to sPx
   set the height of image "Ghost" to sPx
   set the imageData of image "Ghost" to tData
   unlock screen
end Ed.MakeGhost

-- over the map, while glyphs are what a click paints: the ghost sits on the cell under the mouse
on Ed.GhostMove
   local tCell, tL, tT
   if there is not an image "Ghost" then exit Ed.GhostMove
   put empty into tCell
   if sGhostOn and sLeft is "Glyphs" and sTab is not "Heights" and the mouseStack is the short name of this stack then put Ed.MapCell() into tCell
   if tCell is empty then
      if the visible of image "Ghost" then
         set the visible of image "Ghost" to false
         set the visible of graphic "GhostBox" to false
      end if
      exit Ed.GhostMove
   end if
   if the width of image "Ghost" is not sPx then Ed.MakeGhost
   put the left of image "Map2D" + (item 1 of tCell - 1) * sPx into tL
   put the top of image "Map2D" + (item 2 of tCell - 1) * sPx into tT
   lock screen
   set the topLeft of image "Ghost" to tL, tT
   set the rect of graphic "GhostBox" to tL - 1, tT - 1, tL + sPx + 1, tT + sPx + 1
   set the visible of image "Ghost" to true
   set the visible of graphic "GhostBox" to true
   unlock screen
end Ed.GhostMove

-------------------------------------------------------------------- the height tools (Heights tab; CELLMAP_V2.md section 8)

-- Floor or Ceiling: which grey a grey swatch paints, and which colour the glyphs take
on Ed.HTool pTool
   if pTool is "blocks" then
      put not sHBlocks into sHBlocks
   else
      put pTool into sHTool
   end if
   Ed.DrawMap
   Ed.HShowTool
   Ed.ShowWhat
   Ed.Status "heights:" && Ed.HPainting()
end Ed.HTool

function Ed.HPainting
   local tWhat
   if sHLayer is "from" then return Ed.HFromWords(sHValue)
   if sHLayer is "grey" then
      put sHTool && sHValue into tWhat
      if sHValue is 0 then put " (empty: nothing there)" after tWhat
      if sHValue is 1 and sHTool is "floor" then put " (a flat plane)" after tWhat
      if sHValue is 100 and sHTool is "floor" then put " (a full wall)" after tWhat
      if sHValue is 100 and sHTool is "ceiling" then
         put " (a standard hallway roof)" after tWhat
      end if
   else
      put sHLayer && sHValue into tWhat
      if sHLayer is "red" then put " (dug under the floor)" after tWhat
      if sHLayer is "green" and sHValue > 0 then put " (a block, its top at" && 255 + sHValue && "hu)" after tWhat
      if sHLayer is "blue" and sHValue > 0 then put " (a block, its top at" && 510 + sHValue && "hu)" after tWhat
   end if
   return tWhat
end Ed.HPainting

on Ed.HShowTool
   local tName
   if there is not a button "ToolFloor" then exit Ed.HShowTool
   set the hilite of button "ToolFloor" to (sHTool is "floor")
   set the hilite of button "ToolCeiling" to (sHTool is "ceiling")
   set the hilite of button "ToolBlocks" to sHBlocks
   put "hs_" & sHLayer & "_" & sHValue into tName
   if sHLayer is "from" then
      -- the brush is the two boxes
      set the rect of graphic "HSel" to the left of button "HFromFloor" - 1, 97, the right of button "HFromCeiling" + 1, 119
      set the visible of graphic "HSel" to true
   else if there is a graphic tName then
      set the rect of graphic "HSel" to the left of graphic tName - 1, the top of graphic tName - 1, the right of graphic tName + 1, the bottom of graphic tName + 1
      set the visible of graphic "HSel" to true
   else
      set the visible of graphic "HSel" to false      -- a picked value between two swatches
   end if
   Ed.HFromShow
   Ed.HTopShow
end Ed.HShowTool

-- From Floor / From Ceiling (the owner, 18 Nov 2026; CELLMAP_V2.md 3b), painted cell by cell: a click
-- on a box turns it on or off and makes the two boxes the brush; a click on a cell then gives it
-- what the boxes say (its [from] value: 1 From Floor + 2 From Ceiling). A swatch is the brush again.
on Ed.HFrom pWhich
   local tBit
   if pWhich is "floor" then
      put 1 into tBit
   else
      put 2 into tBit
   end if
   if sHLayer is "from" then
      put sHFrom bitXor tBit into sHFrom       -- already the brush: the box turns on or off
   else
      put sHFrom bitOr tBit into sHFrom        -- the boxes become the brush, with this one on
   end if
   put "from" into sHLayer
   put sHFrom into sHValue
   Ed.HShowTool
   Ed.ShowWhat
   Ed.Status "click cells to paint:" && Ed.HFromWords(sHFrom)
end Ed.HFrom

-- the two boxes show the brush (what a click on a cell gives it)
on Ed.HFromShow
   if there is not a button "HFromFloor" then exit Ed.HFromShow
   set the hilite of button "HFromFloor" to ((sHFrom bitAnd 1) is not 0)
   set the hilite of button "HFromCeiling" to ((sHFrom bitAnd 2) is not 0)
end Ed.HFromShow

function Ed.HFromWords pFlags
   put pFlags + 0 into pFlags
   if pFlags is 3 then return "From Floor + From Ceiling (the cell solid from the floor to the top," && CellMap.Top(sMap) && "hu)"
   if pFlags is 1 then return "From Floor (fills the cell solid under its block)"
   if pFlags is 2 then return "From Ceiling (the block hangs from the top of the map," && CellMap.Top(sMap) && "hu)"
   return "both off (blocks float)"
end Ed.HFromWords

-- the map's top, shown in the tool row (From Ceiling hangs from it)
on Ed.HTopShow
   if there is not a field "HTop" then exit Ed.HTopShow
   put "top" && CellMap.Top(sMap) into field "HTop"
end Ed.HTopShow

-- a click on the top: a new top in hu (empty = the default, 765), one undo step
on Ed.HTopAsk
   local tOld, tNew
   if sMap["floor"] is not an array then exit Ed.HTopAsk
   ask "The top of the map in hu (From Ceiling hangs from it). Empty = 765, the top of the blue band:" with sMap["meta"]["top"]
   if the result is "Cancel" then exit Ed.HTopAsk
   put it into tNew
   Ed.HSetTop tNew
end Ed.HTopAsk

on Ed.HSetTop pTop
   local tOld
   if pTop is not empty and not (pTop is an integer and pTop > 0) then
      Ed.Status "the top must be a whole number of hu (or empty for 765)"
      exit Ed.HSetTop
   end if
   if pTop is sMap["meta"]["top"] then exit Ed.HSetTop
   put sMap into tOld
   if pTop is empty then
      delete variable sMap["meta"]["top"]
   else
      put pTop into sMap["meta"]["top"]
   end if
   Ed.MapSnap "set the top", tOld
   Ed.HTopShow
   Ed.Changed
   Ed.Status "the top of the map:" && CellMap.Top(sMap) && "hu"
end Ed.HSetTop

-- Extrude Glyphs to Heights on or off (the Mesh menu's two Extrude items)
on Ed.HExtrude
   if sMap["meta"]["extrude"] is "glyph" then
      Ed.MeshMenu "Extrude: Whole Cell"
   else
      Ed.MeshMenu "Extrude: Glyph Shape"
   end if
end Ed.HExtrude

-- a swatch: "hs_<grey|red|green|blue>_<value>"
on Ed.HSwatch pName
   set the itemDel to "_"
   put item 2 of pName into sHLayer
   put item 3 of pName into sHValue
   set the itemDel to comma
   Ed.HShowTool
   Ed.ShowWhat
   Ed.Status "heights:" && Ed.HPainting()
end Ed.HSwatch

-------------------------------------------------------------------- map packs (cellmap v3: CELLMAP_V3.md 4 and 6)
-- sPack is CellMap.ReadPack's array (maps[n] id file place base at map, doors[n] from type to note);
-- sPackSel the selected map's number, sPackOpen the id of the map open for painting (empty: a map
-- that is not in the pack), sCheck the checker's last lines (kind, map, col,row, words: tabs)

function Ed.PackFolder
   set the itemDel to "/"
   get item 1 to -2 of sPackPath
   set the itemDel to comma
   return it
end Ed.PackFolder

-- the id of the pack's map stored in pPath (empty: not one of them)
function Ed.PackIdOf pPath
   local i
   if sPackPath is empty or sPack["count"] is not a number then return empty
   repeat with i = 1 to sPack["count"]
      if Ed.PackFolder() & "/" & sPack["maps"][i]["file"] is pPath then return sPack["maps"][i]["id"]
   end repeat
   return empty
end Ed.PackIdOf

on Ed.OpenPack pPath
   local n
   if there is not a file pPath then
      Ed.Status "no pack" && pPath
      exit Ed.OpenPack
   end if
   put CellMap.ReadPack(pPath) into sPack
   put pPath into sPackPath
   put false into sPackDirty
   put empty into sCheck
   put CellMap.PackIndex(sPack, sPack["meta"]["start"]) into n
   if n < 1 then put 1 into n
   put n into sPackSel
   Ed.PackPanel
   if sPack["count"] >= 1 and sPack["maps"][n]["map"] is an array then Ed.PackOpenMap n
   Ed.PackFill
   if sPack["problems"] is not empty then
      Ed.Status "pack" && Ed.ShortName(pPath) & ":" && the number of lines of sPack["problems"] && "problems (Check lists them)"
   else
      Ed.Status "pack" && Ed.ShortName(pPath) & ":" && sPack["count"] && "maps; double-click one to paint it"
   end if
end Ed.OpenPack

-- a new pack holding the map open now; it must be saved, and the pack goes in its folder
on Ed.NewPackAsk
   local tName
   if sMapPath is empty or there is not a file sMapPath then
      Ed.Status "save the map first: a pack is written beside its maps"
      exit Ed.NewPackAsk
   end if
   ask "A name for the new pack (written beside this map, as <name>.cellpack):" with sMap["meta"]["name"]
   if it is empty or the result is "Cancel" then exit Ed.NewPackAsk
   put it into tName
   Ed.NewPack tName
end Ed.NewPackAsk

on Ed.NewPack pName
   local tPack, tFolder, tId
   set the itemDel to "/"
   put item 1 to -2 of sMapPath into tFolder
   put item -1 of sMapPath into tPack["maps"][1]["file"]
   set the itemDel to comma
   put sMap["meta"]["name"] into tId
   if tId is empty then put "map1" into tId
   replace space with "_" in tId
   put pName into tPack["meta"]["name"]
   put tId into tPack["meta"]["start"]
   put tId into tPack["maps"][1]["id"]
   put "main" into tPack["maps"][1]["place"]
   put 0 into tPack["maps"][1]["base"]
   put "1,1" into tPack["maps"][1]["at"]
   put 1 into tPack["count"]
   put tFolder & "/" & pName & ".cellpack" into sPackPath
   put tPack into sPack
   Ed.PackSave
   Ed.OpenPack sPackPath
end Ed.NewPack

on Ed.PackSave
   if sPackPath is empty then exit Ed.PackSave
   put textEncode(CellMap.PackToText(sPack), "UTF-8") into URL ("binfile:" & sPackPath)
   put false into sPackDirty
   Ed.PackFill
   Ed.Status "saved pack" && Ed.ShortName(sPackPath)
end Ed.PackSave

-- open map n of the pack for painting (asks first when the open map has unsaved changes)
on Ed.PackOpenMap n
   local tPath
   if n < 1 or n > sPack["count"] then exit Ed.PackOpenMap
   put Ed.PackFolder() & "/" & sPack["maps"][n]["file"] into tPath
   if there is not a file tPath then
      Ed.Status "no file" && sPack["maps"][n]["file"] && "beside the pack"
      exit Ed.PackOpenMap
   end if
   if tPath is sMapPath then
      put n into sPackSel                            -- already open (maybe with unsaved changes): keep it
      put sPack["maps"][n]["id"] into sPackOpen
      Ed.PackFill
      exit Ed.PackOpenMap
   end if
   if sDirtyMap then
      answer "Save the changes to" && Ed.ShortName(sMapPath) && "first?" with "Cancel" or "Don't Save" or "Save"
      if it is "Cancel" then exit Ed.PackOpenMap
      if it is "Save" then Ed.SaveMap
   end if
   put n into sPackSel
   Ed.OpenMap tPath
   Ed.PackFill
end Ed.PackOpenMap

-- the pack window: built the first time it is wanted, floating at the right of the screen
on Ed.PackPanel
   local tS, tB, tF, tPanel, tText, tY, x, tName, tW, tWas
   put "BitEditorPack" into tS
   if there is a stack tS then
      try
         palette stack tS
      end try
      Ed.PackFill
      exit Ed.PackPanel
   end if
   put the defaultStack into tWas
   put the effective backgroundColor of button "ToolFloor" into tB
   put the effective foregroundColor of button "ToolFloor" into tF
   put the effective backgroundColor of graphic "MapFrame" into tPanel
   put the effective foregroundColor of field "PaintInfo" into tText
   put 344 into tW
   create invisible stack tS
   set the defaultStack to tS
   set the title of stack tS to "FOR OWNER | BitEditor Pack"
   dispatch "Users.TitleStack" with tS, "BitEditor Pack"
   set the rect of stack tS to item 3 of the screenRect - tW - 12, 32, item 3 of the screenRect - 12, 32 + 600
   set the resizable of stack tS to false
   set the destroyStack of stack tS to true          -- closing it frees it (LIB_ALPHA 12b)
   set the backgroundColor of stack tS to tPanel
   set the foregroundColor of stack tS to tText
   set the textSize of stack tS to 11
   set the script of stack tS to "on closeStackRequest" & return & "set the destroyStack of me to true" & return & "pass closeStackRequest" & return & "end closeStackRequest"
   -- template colours first (the owner's rule), then the controls
   reset the templateField
   set the backgroundColor of the templateField to kDark
   set the foregroundColor of the templateField to kLit
   set the textSize of the templateField to 11
   set the lockText of the templateField to true
   set the dontWrap of the templateField to true
   reset the templateButton
   set the style of the templateButton to "standard"
   set the backgroundColor of the templateButton to tB
   set the foregroundColor of the templateButton to tF
   set the textSize of the templateButton to 11
   create field "PackTitle"
   set the rect of it to 8, 8, tW - 8, 42
   set the backgroundColor of it to tPanel
   set the foregroundColor of it to tText
   Ed.PackLabel "LMaps", "MAPS  (double-click = paint it)", 46, tW, tPanel, tText
   create field "PackMaps"
   set the rect of it to 8, 62, tW - 8, 172
   set the listBehavior of it to true
   set the vScrollbar of it to true
   set the tabStops of it to "74,124,160,200"
   set the script of it to "on mouseUp" & return & "send " & quote & "Ed.PackDo Select" & quote & " to stack " & quote & "BitEditor" & quote & return & "end mouseUp" & return & \
         "on mouseDoubleUp" & return & "send " & quote & "Ed.PackDo Open" & quote & " to stack " & quote & "BitEditor" & quote & return & "end mouseDoubleUp"
   put 8 into x
   repeat for each item tName in "Open,Up,Down,Place...,Add...,Remove,Start"
      Ed.PackButton tName, x, 176, 44
      add 47 to x
   end repeat
   Ed.PackLabel "LDoors", "DOORS  (one way each; Door to... starts at the last cell clicked)", 204, tW, tPanel, tText
   create field "PackDoors"
   set the rect of it to 8, 220, tW - 8, 290
   set the listBehavior of it to true
   set the vScrollbar of it to true
   set the tabStops of it to "100,150,250"
   put 8 into x
   repeat for each item tName in "Door to...,Remove Door"
      Ed.PackButton tName, x, 294, 90
      add 94 to x
   end repeat
   Ed.PackLabel "LCheck", "CHECK (E12)  (a click on a line marks its cell)", 322, tW, tPanel, tText
   Ed.PackButton "Check", tW - 98, 318, 90
   create field "PackCheck"
   set the rect of it to 8, 342, tW - 8, 556
   set the listBehavior of it to true
   set the vScrollbar of it to true
   set the dontWrap of it to false
   set the tabStops of it to "70,130,170"
   set the script of it to "on mouseUp" & return & "send " & quote & "Ed.PackDo Jump" & quote & " to stack " & quote & "BitEditor" & quote & return & "end mouseUp"
   put 8 into x
   repeat for each item tName in "Open Pack...,New Pack...,Save Pack"
      Ed.PackButton tName, x, 566, 104
      add 110 to x
   end repeat
   reset the templateField
   reset the templateButton
   set the defaultStack to tWas
   try
      palette stack tS
   end try
   Ed.PackFill
end Ed.PackPanel

on Ed.PackLabel pName, pText, pTop, pW, pBack, pFore
   create field pName
   set the rect of it to 8, pTop, pW - 8, pTop + 16
   set the backgroundColor of it to pBack
   set the foregroundColor of it to pFore
   set the opaque of it to false
   set the showBorder of it to false
   set the textSize of it to 10
   put pText into it
end Ed.PackLabel

on Ed.PackButton pName, pLeft, pTop, pWidth
   create button pName
   set the rect of it to pLeft, pTop, pLeft + pWidth, pTop + 22
   set the script of it to "on mouseUp" & return & "send " & quote & "Ed.PackDo " & pName & quote & " to stack " & quote & "BitEditor" & quote & return & "end mouseUp"
end Ed.PackButton

-- the window's lists from sPack and sCheck
on Ed.PackFill
   local tS, tOut, i, tLine, tMark, tKind, tWords
   put "BitEditorPack" into tS
   if there is not a stack tS then exit Ed.PackFill
   lock screen
   if sPackPath is empty then
      put "no pack open: File > Open Pack..., or New Pack... (it holds the map open now)" & return & "Check checks the open map alone" into field "PackTitle" of stack tS
   else
      put "PACK" && sPack["meta"]["name"] && "  start:" && sPack["meta"]["start"] into tLine
      if sPackDirty then put "   [pack not saved]" after tLine
      if sPackOpen is empty then
         put tLine & return & Ed.ShortName(sPackPath) && "  painting a map outside the pack (Check checks it alone)" into field "PackTitle" of stack tS
      else
         put tLine & return & Ed.ShortName(sPackPath) && "  painting:" && sPackOpen into field "PackTitle" of stack tS
      end if
   end if
   put empty into tOut
   if sPack["count"] is a number then
      repeat with i = 1 to sPack["count"]
         put empty into tMark
         if sPack["maps"][i]["id"] is sPackOpen and sPackOpen is not empty then put "* " into tMark
         put tMark & sPack["maps"][i]["id"] & tab & sPack["maps"][i]["place"] & tab & sPack["maps"][i]["base"] & tab & \
               sPack["maps"][i]["at"] & tab & sPack["maps"][i]["file"] & return after tOut
      end repeat
   end if
   put char 1 to -2 of tOut into field "PackMaps" of stack tS
   if sPackSel >= 1 and sPackSel <= sPack["count"] then set the hilitedLine of field "PackMaps" of stack tS to sPackSel
   put empty into tOut
   repeat with i = 1 to CellMap.Count(sPack["doors"])
      put sPack["doors"][i]["from"] & tab & sPack["doors"][i]["type"] & tab & sPack["doors"][i]["to"] & tab & sPack["doors"][i]["note"] & return after tOut
   end repeat
   put char 1 to -2 of tOut into field "PackDoors" of stack tS
   put sCheck into field "PackCheck" of stack tS
   unlock screen
end Ed.PackFill

-- every button and list of the pack window arrives here
on Ed.PackDo pWhat
   local tS, n, tAsk, tLine, tOld
   set the defaultStack to "BitEditor"
   put "BitEditorPack" into tS
   if there is a stack tS then put the hilitedLine of field "PackMaps" of stack tS into n
   if pWhat is not among the items of "Open Pack...,New Pack...,Check,Jump" and sPackPath is empty then
      Ed.Status "open a pack first (File > Open Pack...)"
      exit Ed.PackDo
   end if
   switch pWhat
      case "Select"
         if n is a number then put n into sPackSel
         break
      case "Open"
         if n is a number then Ed.PackOpenMap n
         break
      case "Up"
         Ed.PackMove sPackSel, -1
         break
      case "Down"
         Ed.PackMove sPackSel, 1
         break
      case "Place..."
         if sPackSel < 1 then exit Ed.PackDo
         ask "Place, base (hu), col,row of" && sPack["maps"][sPackSel]["id"] & "'s cell 1,1 on the place's first map:" with \
               sPack["maps"][sPackSel]["place"] && sPack["maps"][sPackSel]["base"] && sPack["maps"][sPackSel]["at"]
         if it is empty or the result is "Cancel" then exit Ed.PackDo
         Ed.PackPlace sPackSel, word 1 of it, word 2 of it, word 3 of it
         break
      case "Add..."
         answer file "Add a map from the pack's folder" with Ed.PackFolder() with type "Cellmap|cellmap|"
         if it is empty then exit Ed.PackDo
         put it into tLine
         set the itemDel to "/"
         put item -1 of tLine into tAsk
         set the itemDel to comma
         if tLine is not (Ed.PackFolder() & "/" & tAsk) then
            Ed.Status "a pack's maps live in its own folder:" && Ed.PackFolder()
            exit Ed.PackDo
         end if
         replace ".cellmap" with empty in tAsk
         ask "Its id in the pack (a short word):" with tAsk
         if it is empty or the result is "Cancel" then exit Ed.PackDo
         Ed.PackAdd tLine, it
         break
      case "Remove"
         Ed.PackRemove sPackSel
         break
      case "Start"
         if sPackSel < 1 then exit Ed.PackDo
         put sPack["maps"][sPackSel]["id"] into sPack["meta"]["start"]
         put true into sPackDirty
         Ed.PackFill
         break
      case "Door to..."
         put sPackOpen & ":" & sLastCell into tLine
         if sPackOpen is empty or sLastCell is empty then put "map:col,row" into tLine
         ask "A door: from type to note (from and to are map:col,row; type a free word: door, ladder, stairs, lift, teleport, hole):" with \
               tLine && "door" && "map:col,row"
         if it is empty or the result is "Cancel" then exit Ed.PackDo
         Ed.PackAddDoor word 1 of it, word 2 of it, word 3 of it, word 4 to -1 of it
         break
      case "Remove Door"
         if there is a stack tS then put the hilitedLine of field "PackDoors" of stack tS into n
         Ed.PackRemoveDoor n
         break
      case "Check"
         Ed.Check
         break
      case "Jump"
         if there is a stack tS then Ed.CheckJump the hilitedLine of field "PackCheck" of stack tS
         break
      case "Open Pack..."
         Ed.FileMenu "Open Pack..."
         break
      case "New Pack..."
         Ed.NewPackAsk
         break
      case "Save Pack"
         Ed.PackSave
         break
   end switch
end Ed.PackDo

-- swap map n with its neighbour (pBy -1 up, 1 down); the order is the order of the file's lines
on Ed.PackMove n, pBy
   local tA
   if n < 1 or n + pBy < 1 or n + pBy > sPack["count"] then exit Ed.PackMove
   put sPack["maps"][n] into tA
   put sPack["maps"][n + pBy] into sPack["maps"][n]
   put tA into sPack["maps"][n + pBy]
   put n + pBy into sPackSel
   put true into sPackDirty
   Ed.PackFill
   Ed.Status "moved" && tA["id"] && "(a place's FIRST map is the one the others are placed on)"
end Ed.PackMove

on Ed.PackPlace n, pPlace, pBase, pAt
   if n < 1 or n > sPack["count"] then exit Ed.PackPlace
   if pPlace is empty then put "main" into pPlace
   if pBase is not a number then put 0 into pBase
   if not (item 1 of pAt is an integer and item 2 of pAt is an integer) then put "1,1" into pAt
   put pPlace into sPack["maps"][n]["place"]
   put pBase into sPack["maps"][n]["base"]
   put pAt into sPack["maps"][n]["at"]
   if sPack["maps"][n]["map"] is an array then put pBase into sPack["maps"][n]["map"]["meta"]["base"]
   put true into sPackDirty
   Ed.PackFill
end Ed.PackPlace

-- a map file of the pack's folder joins the pack, last, in place main at base 0
on Ed.PackAdd pPath, pId
   local n, tMap, tFile
   replace space with "_" in pId
   if CellMap.PackIndex(sPack, pId) > 0 then
      Ed.Status "the pack already has a map" && pId
      exit Ed.PackAdd
   end if
   set the itemDel to "/"
   put item -1 of pPath into tFile
   set the itemDel to comma
   put sPack["count"] + 1 into n
   put pId into sPack["maps"][n]["id"]
   put tFile into sPack["maps"][n]["file"]
   put "main" into sPack["maps"][n]["place"]
   put 0 into sPack["maps"][n]["base"]
   put "1,1" into sPack["maps"][n]["at"]
   put CellMap.Read(pPath) into tMap
   CellMap.Upgrade tMap
   put 0 into tMap["meta"]["base"]
   put tMap into sPack["maps"][n]["map"]
   put n into sPack["count"]
   put n into sPackSel
   put true into sPackDirty
   Ed.PackFill
end Ed.PackAdd

on Ed.PackRemove n
   local i
   if n < 1 or n > sPack["count"] then exit Ed.PackRemove
   repeat with i = n to sPack["count"] - 1
      put sPack["maps"][i + 1] into sPack["maps"][i]
   end repeat
   delete variable sPack["maps"][sPack["count"]]
   subtract 1 from sPack["count"]
   put min(n, sPack["count"]) into sPackSel
   put true into sPackDirty
   Ed.PackFill
   Ed.Status "removed from the pack (the file stays; doors to it are reported by Check)"
end Ed.PackRemove

on Ed.PackAddDoor pFrom, pType, pTo, pNote
   local n
   set the itemDel to ":"
   if CellMap.PackIndex(sPack, item 1 of pFrom) < 1 or CellMap.PackIndex(sPack, item 1 of pTo) < 1 then
      set the itemDel to comma
      Ed.Status "a door goes from map:col,row to map:col,row of maps in this pack"
      exit Ed.PackAddDoor
   end if
   set the itemDel to comma
   if pType is empty then put "door" into pType
   put CellMap.Count(sPack["doors"]) + 1 into n
   put pFrom into sPack["doors"][n]["from"]
   put pType into sPack["doors"][n]["type"]
   put pTo into sPack["doors"][n]["to"]
   put pNote into sPack["doors"][n]["note"]
   put true into sPackDirty
   Ed.PackFill
end Ed.PackAddDoor

on Ed.PackRemoveDoor n
   local i, tCount
   put CellMap.Count(sPack["doors"]) into tCount
   if n is not a number or n < 1 or n > tCount then exit Ed.PackRemoveDoor
   repeat with i = n to tCount - 1
      put sPack["doors"][i + 1] into sPack["doors"][i]
   end repeat
   delete variable sPack["doors"][tCount]
   put true into sPackDirty
   Ed.PackFill
end Ed.PackRemoveDoor

-- the E12 checker: the whole pack when the map being painted is one of its maps (that map as it is now,
-- saved or not), else the open map alone
on Ed.Check
   local tPack, n, tOut
   if sPackOpen is not empty then
      put sPack into tPack
      put CellMap.PackIndex(tPack, sPackOpen) into n
      if n > 0 then
         put sMap into tPack["maps"][n]["map"]
         put tPack["maps"][n]["base"] into tPack["maps"][n]["map"]["meta"]["base"]
      end if
      put CellMap.CheckPack(tPack, sTags) into tOut
   else
      put CellMap.Check(sMap, sTags) into tOut
   end if
   if char -1 of tOut is return then delete char -1 of tOut
   put tOut into sCheck
   Ed.PackPanel
   if tOut is empty then
      Ed.Status "check: no problems"
   else
      Ed.Status "check:" && the number of lines of tOut && "lines (click one in the Pack window to see its cell)"
   end if
end Ed.Check

-- line n of the checker: open its map when it is another of the pack's, then mark the cell
on Ed.CheckJump n
   local tLine, tId, tCell, i
   if n is not a number then exit Ed.CheckJump
   put line n of sCheck into tLine
   set the itemDel to tab
   put item 2 of tLine into tId
   put item 3 of tLine into tCell
   set the itemDel to comma
   if sPackPath is not empty and tId is not empty and tId is not sPackOpen then
      put CellMap.PackIndex(sPack, tId) into i
      if i > 0 then Ed.PackOpenMap i
   end if
   if item 1 of tCell is an integer and item 2 of tCell is an integer then
      Ed.MarkCell item 1 of tCell, item 2 of tCell
   end if
   set the itemDel to tab
   Ed.Status item 1 of tLine & ":" && item 4 of tLine
   set the itemDel to comma
end Ed.CheckJump

-- a frame round one cell of the 2D map (and the 3D cursor there) until the next click on the map
on Ed.MarkCell pC, pR
   local tL, tT
   if there is not a graphic "MarkBox" or sPx is not a number then exit Ed.MarkCell
   put the left of image "Map2D" + (pC - 1) * sPx into tL
   put the top of image "Map2D" + (pR - 1) * sPx into tT
   set the rect of graphic "MarkBox" to tL - 2, tT - 2, tL + sPx + 2, tT + sPx + 2
   set the visible of graphic "MarkBox" to true
   put pC & comma & pR into sHover
   Ed.ShowHover
   Ed.Draw3DCursor
end Ed.MarkCell

function Ed.PackState
   return sPack["meta"]["name"] & "|" & sPack["count"] & "|" & sPackSel & "|" & sPackOpen & "|" & sPackDirty & "|" & CellMap.Count(sPack["doors"])
end Ed.PackState

-------------------------------------------------------------------- right: the 3D preview

on Ed.ResetCamera
   put 0 into sYaw                           -- north up, as in the 2D map
   put 0.87 into sPitch                      -- about 50 degrees down
   put empty into sDist                      -- fitted to the map when it is built
   put 0 into sTX                            -- what the camera looks at and turns around
   put 0 into sTY
   put 0 into sTZ
end Ed.ResetCamera

-- the level's lines (CellMap.LevelSegments, the same as Vibecode3D gets), in engine units
on Ed.Build3D
   local tSegs, tSeg, tE, tFontUsed, tW
   if sMap["floor"] is not an array then exit Ed.Build3D
   put empty into sSegs
   if sRelief3D or sMap["meta"]["extrude"] is "glyph" then put sFont into tFontUsed
   -- the map's style: lean = only the outline you can see, straight runs joined, uprights at corners,
   -- the seams of roofs and blocks cut (LIB_BIT/livecode/lib_lean.livecodescript; saved as meta "style")
   if sMap["meta"]["style"] is "lean" then
      put Lean.MapSegments(sMap, sTags, tFontUsed, empty) into tSegs
   else
      put CellMap.LevelSegments(sMap, sTags, tFontUsed) into tSegs
   end if
   put empty into sVis
   put the number of lines of tSegs into sSegCount
   repeat for each line tSeg in tSegs
      put CellMap.SegToEngine(sMap, tSeg) into tE
      put item 1 to 6 of tE & return after sSegs[item 7 of tE]
   end repeat
   if sDist is not a number then
      put max(sMap["meta"]["cols"], sMap["meta"]["rows"]) * sMap["meta"]["cell"] into tW
      put tW * 1.25 into sDist
   end if
end Ed.Build3D

-- engine point -> "x,y" in the viewport (empty behind the eye). Up is +y in map space.
private function edProject pX, pY, pZ, pCY, pSY, pCP, pSP, pMidX, pMidY, pF
   local x1, z1, yc, zc, d
   subtract sTX from pX
   subtract sTY from pY
   subtract sTZ from pZ
   put pX * pCY + pZ * pSY into x1
   put pZ * pCY - pX * pSY into z1
   put pY * pCP - z1 * pSP into yc
   put pY * pSP + z1 * pCP into zc
   put sDist - zc into d
   if d < 20 then return empty
   return round(pMidX + x1 * pF / d) & comma & round(pMidY - yc * pF / d)
end edProject

on Ed.Draw3D
   local tPair, tClass, tPts, tSeg, tA, tB, tCY, tSY, tCP, tSP, tMidX, tMidY, tF, tRect, tClasses, tLines, tHid
   if there is not a group "View3D" then exit Ed.Draw3D
   put the rect of graphic "ViewBack" into tRect
   put (item 1 of tRect + item 3 of tRect) div 2 into tMidX
   put (item 2 of tRect + item 4 of tRect) div 2 + 30 into tMidY
   put (item 3 of tRect - item 1 of tRect) * 0.95 into tF
   put cos(sYaw) into tCY
   put sin(sYaw) into tSY
   put cos(sPitch) into tCP
   put sin(sPitch) into tSP
   put kColours into tClasses
   replace "|" with return in tClasses
   lock screen
   if sHide is "lines" and sCamOn is not true then
      if sVis is not an array or sVisAt is not (sYaw & comma & sPitch & comma & sDist & comma & sTX & comma & sTY & comma & sTZ) then
         Ed.HideLines
         put sYaw & comma & sPitch & comma & sDist & comma & sTX & comma & sTY & comma & sTZ into sVisAt
      end if
   end if
   repeat for each line tPair in tClasses
      put word 1 of tPair into tClass
      put empty into tPts
      if not Ed.Shown(tClass) then
         set the points of graphic ("v_" & tClass) to empty
         next repeat
      end if
      if sHide is "lines" and sCamOn is not true then
         put sVis[tClass] into tLines
      else
         put sSegs[tClass] into tLines
      end if
      repeat for each line tSeg in tLines
         put edProject(item 1 of tSeg, item 2 of tSeg, item 3 of tSeg, tCY, tSY, tCP, tSP, tMidX, tMidY, tF) into tA
         if tA is empty then next repeat
         put edProject(item 4 of tSeg, item 5 of tSeg, item 6 of tSeg, tCY, tSY, tCP, tSP, tMidX, tMidY, tF) into tB
         if tB is empty then next repeat
         put tA & return & tB & return & return after tPts
      end repeat
      set the points of graphic ("v_" & tClass) to tPts
   end repeat
   unlock screen
   Ed.Draw3DCursor
   if sHide is "lines" then put ", hidden lines hidden" into tHid
   if sMap["meta"]["extrude"] is "glyph" then
      put "3D  " & sSegCount & tHid && "lines, glyph shapes (Mesh menu)   LEFT: paint   RIGHT held: drag turns, WASD RF move   wheel: zoom" into field "ViewTitle"
   else
      put "3D  " & sSegCount & tHid && "lines, whole cells (Mesh menu)   LEFT: paint   RIGHT held: drag turns, WASD RF move   wheel: zoom" into field "ViewTitle"
   end if
end Ed.Draw3D

-- the cell under the mouse in the 2D map, marked in the 3D preview: its square on its own
-- ground and a pin standing on it (where you are about to paint)
on Ed.Draw3DCursor
   local tC, tR, tX0, tX1, tZ0, tZ1, tY, tCell, tPts, tCorner, tP, tRect, tMidX, tMidY, tF, tCY, tSY, tCP, tSP, tCol, tFirst
   if there is not a graphic "v_cursor" then exit Ed.Draw3DCursor
   if sHover is empty or sDist is not a number then
      set the points of graphic "v_cursor" to empty
      exit Ed.Draw3DCursor
   end if
   put item 1 of sHover into tC
   put item 2 of sHover into tR
   put sMap["meta"]["cell"] into tCell
   put CellMap.CellX(sMap, tC) - tCell / 2 into tX0
   put tX0 + tCell into tX1
   put CellMap.CellZ(sMap, tR) - tCell / 2 into tZ0
   put tZ0 + tCell into tZ1
   put 0 into tY
   put CellMap.Column(sMap, tC, tR) into tCol
   if tCol is not empty then put item 1 of tCol * CellMap.HU(sMap) into tY
   put the rect of graphic "ViewBack" into tRect
   put (item 1 of tRect + item 3 of tRect) div 2 into tMidX
   put (item 2 of tRect + item 4 of tRect) div 2 + 30 into tMidY
   put (item 3 of tRect - item 1 of tRect) * 0.95 into tF
   put cos(sYaw) into tCY
   put sin(sYaw) into tSY
   put cos(sPitch) into tCP
   put sin(sPitch) into tSP
   repeat for each word tCorner in (tX0 & comma & tZ0) && (tX1 & comma & tZ0) && (tX1 & comma & tZ1) && (tX0 & comma & tZ1)
      put edProject(item 1 of tCorner, tY, item 2 of tCorner, tCY, tSY, tCP, tSP, tMidX, tMidY, tF) into tP
      if tP is empty then
         set the points of graphic "v_cursor" to empty
         exit Ed.Draw3DCursor
      end if
      if tFirst is empty then put tP into tFirst
      put tP & return after tPts
   end repeat
   put tFirst & return & return after tPts
   put edProject((tX0 + tX1) / 2, tY, (tZ0 + tZ1) / 2, tCY, tSY, tCP, tSP, tMidX, tMidY, tF) & return after tPts
   put edProject((tX0 + tX1) / 2, tY + sMap["meta"]["wallH"], (tZ0 + tZ1) / 2, tCY, tSY, tCP, tSP, tMidX, tMidY, tF) after tPts
   set the points of graphic "v_cursor" to tPts
end Ed.Draw3DCursor

-- the ray from the eye through a point of the preview: "ex,ey,ez,dx,dy,dz" (engine units, y up)
function Ed.ViewRay pH, pV
   local tRect, tMidX, tMidY, tF, u, v, tCY, tSY, tCP, tSP, tOut, tPt, x1, yc, zc, y, z1
   put the rect of graphic "ViewBack" into tRect
   put (item 1 of tRect + item 3 of tRect) div 2 into tMidX
   put (item 2 of tRect + item 4 of tRect) div 2 + 30 into tMidY
   put (item 3 of tRect - item 1 of tRect) * 0.95 into tF
   put (pH - tMidX) / tF into u
   put (tMidY - pV) / tF into v
   put cos(sYaw) into tCY
   put sin(sYaw) into tSY
   put cos(sPitch) into tCP
   put sin(sPitch) into tSP
   -- the eye, then the point one unit along the ray, from camera space back to the map's
   repeat for each line tPt in ("0,0," & sDist) & return & (u & comma & v & comma & (sDist - 1))
      put item 1 of tPt into x1
      put item 2 of tPt into yc
      put item 3 of tPt into zc
      put tCP * yc + tSP * zc into y
      put tCP * zc - tSP * yc into z1
      put (x1 * tCY - z1 * tSY + sTX) & comma & (y + sTY) & comma & (x1 * tSY + z1 * tCY + sTZ) & comma after tOut
   end repeat
   return item 1 to 3 of tOut & comma & (item 4 of tOut - item 1 of tOut) & comma & (item 5 of tOut - item 2 of tOut) & comma & (item 6 of tOut - item 3 of tOut)
end Ed.ViewRay

-- "col,row" of the map under a point of the 3D preview (empty: nothing there)
function Ed.ViewCellAt pH, pV
   local tRay, tHit
   if sDist is not a number or sMap["floor"] is not an array then return empty
   put Ed.ViewRay(pH, pV) into tRay
   put CellMap.Pick(sMap, item 1 of tRay, item 2 of tRay, item 3 of tRay, item 4 of tRay, item 5 of tRay, item 6 of tRay, sDist * 4 + 4000) into tHit
   return item 1 to 2 of tHit
end Ed.ViewCellAt

function Ed.ViewCell
   if not Ed.OverView() then return empty
   return Ed.ViewCellAt(the mouseH, the mouseV)
end Ed.ViewCell

-- left button in the 3D preview: the same brush as on the 2D map (Alt + click picks up)
on Ed.ViewPaintDown
   local tCell
   put Ed.ViewCell() into tCell
   if tCell is empty then exit Ed.ViewPaintDown
   if the optionKey is down then
      Ed.PickUp item 1 of tCell, item 2 of tCell
      exit Ed.ViewPaintDown
   end if
   Ed.StrokeBegin "view", "paint in 3D" && toLower(Ed.What())
   put tCell into sStrokeAt
   Ed.PaintCell item 1 of tCell, item 2 of tCell
   Ed.StrokeTick sTickId
end Ed.ViewPaintDown

-- right button in the 3D preview: camera mode for as long as it is held
on Ed.CamBegin
   focus on nothing                           -- W A S D must not be typed into the Filter
   put true into sCamOn
   add 1 to sCamId
   put the milliseconds into sCamAt
   put the mouseLoc & comma & sYaw & comma & sPitch & comma & sDist into sDrag
   Ed.Status "camera: drag turns, W A S D move, R F up and down, Shift + drag zooms (while the right button is held)"
   Ed.CamTick sCamId
end Ed.CamBegin

on Ed.CamEnd
   put false into sCamOn
   put empty into sDrag
   add 1 to sCamId
   if sHide is "lines" then Ed.Draw3D          -- the view stopped: work out what is hidden
end Ed.CamEnd

-- every 30 ms while the right button is down: turn by the drag, move by the keys held
on Ed.CamTick pId
   local tKeys, tNow, tMove, tF, tR, tU, dx, dy, tWas
   if pId is not sCamId or sCamOn is not true then exit Ed.CamTick
   if mouse(3) is not "down" then
      Ed.CamEnd
      exit Ed.CamTick
   end if
   put sYaw & comma & sPitch & comma & sDist & comma & sTX & comma & sTY & comma & sTZ into tWas
   put the mouseH - item 1 of sDrag into dx
   put the mouseV - item 2 of sDrag into dy
   if the shiftKey is down then
      put max(150, item 5 of sDrag * (1 + dy / 200)) into sDist
   else
      put item 3 of sDrag + dx / 150 into sYaw
      put max(0.05, min(1.57, item 4 of sDrag + dy / 150)) into sPitch
   end if
   put the milliseconds into tNow
   put Ed.CamKeys(the keysDown) into tKeys
   put sDist * 0.8 * min(0.2, (tNow - sCamAt) / 1000) into tMove      -- 0.8 of the distance a second
   put tNow into sCamAt
   Ed.CamMove item 1 of tKeys * tMove, item 2 of tKeys * tMove, item 3 of tKeys * tMove
   if (sYaw & comma & sPitch & comma & sDist & comma & sTX & comma & sTY & comma & sTZ) is not tWas then Ed.Draw3D
   send "Ed.CamTick" && sCamId to me in 30 milliseconds
end Ed.CamTick

-- the keys held, as "forward,right,up" each -1, 0 or 1 (W S, D A, R F; capitals too)
function Ed.CamKeys pKeysDown
   local tF, tR, tU, k
   put 0 into tF
   put 0 into tR
   put 0 into tU
   repeat for each item k in pKeysDown
      switch k
         case 119
         case 87
            add 1 to tF
            break
         case 115
         case 83
            subtract 1 from tF
            break
         case 100
         case 68
            add 1 to tR
            break
         case 97
         case 65
            subtract 1 from tR
            break
         case 114
         case 82
            add 1 to tU
            break
         case 102
         case 70
            subtract 1 from tU
            break
      end switch
   end repeat
   return max(-1, min(1, tF)) & comma & max(-1, min(1, tR)) & comma & max(-1, min(1, tU))
end Ed.CamKeys

-- move what the camera looks at: forward (the way it looks, along the ground), right, up
on Ed.CamMove pForward, pRight, pUp
   add pForward * sin(sYaw) + pRight * cos(sYaw) to sTX
   add pRight * sin(sYaw) - pForward * cos(sYaw) to sTZ
   add pUp to sTY
end Ed.CamMove

-- camera mode swallows the letters (they move the camera, they are not typed)
on keyDown pKey
   if sCamOn is true then exit keyDown
   pass keyDown
end keyDown

on Ed.Zoom pFactor
   if sDist is not a number then exit Ed.Zoom
   put max(150, sDist * pFactor) into sDist
   Ed.Draw3D
end Ed.Zoom

function Ed.OverView
   return the mouseLoc is within the rect of graphic "ViewBack"
end Ed.OverView

on rawKeyDown pKey
   -- the wheel over the 3D preview zooms it
   if (pKey is 65309 or pKey is 65308) and Ed.OverView() then
      if pKey is 65309 then
         Ed.Zoom 0.9
      else
         Ed.Zoom 1.1
      end if
      exit rawKeyDown
   end if
   pass rawKeyDown
end rawKeyDown

on Ed.SceneMenu pItem
   local tC, tOld
   switch pItem
      case "Reset View"
         Ed.ResetCamera
         Ed.Build3D
         break
      case "Top View (as the 2D map)"
         put 0 into sYaw
         put 1.57 into sPitch
         break
      case "From The South"
         put 0 into sYaw
         put 0.35 into sPitch
         break
      case "From The East"
         put 1.5708 into sYaw
         put 0.6 into sPitch
         break
      case "Glyph Relief On / Off"
         put not sRelief3D into sRelief3D
         Ed.Build3D
         break
      case "Lean Style (outlines only)"
         -- a style of the map: saved with it, so a game reading the map can draw it the same way
         put sMap into tOld
         if sMap["meta"]["style"] is "lean" then
            delete variable sMap["meta"]["style"]
         else
            put "lean" into sMap["meta"]["style"]
         end if
         Ed.MapSnap "Lean Style", tOld
         Ed.Build3D
         Ed.SceneMarks
         break
      case "Hiding: Off"
         put "off" into sHide
         Ed.SceneMarks
         break
      case "Hiding: Hidden Lines"
         put "lines" into sHide
         put empty into sVis
         Ed.SceneMarks
         break
      case "Show: All"
         put empty into sShow
         put empty into sVis
         Ed.SceneMarks
         break
      case "Zoom In"
         put sDist * 0.8 into sDist
         break
      case "Zoom Out"
         put sDist * 1.25 into sDist
         break
   end switch
   if pItem begins with "Show: " and pItem is not "Show: All" then
      put toLower(word 2 of pItem) into tC
      put not Ed.Shown(tC) into sShow[tC]
      put empty into sVis
      Ed.SceneMarks
   end if
   if pItem begins with "Zoom" or pItem begins with "Reset" or pItem begins with "Top" or pItem begins with "From" then put empty into sVis
   Ed.Draw3D
   Ed.Status "3D preview:" && pItem
end Ed.SceneMenu

-- check marks on the Scene menu's Hiding and Show items
on Ed.SceneMarks
   local tC, tText
   -- an editor built before 21 Nov 2026 has no Lean Style item yet: add it under Glyph Relief
   if there is a button "Scene" then
      put the text of button "Scene" into tText
      if "Lean Style (outlines only)" is not in tText and "Glyph Relief On / Off" is in tText then
         replace "Glyph Relief On / Off" with ("Glyph Relief On / Off" & return & "Lean Style (outlines only)") in tText
         set the text of button "Scene" to tText
      end if
   end if
   Ed.MenuMark "Scene", "Lean Style (outlines only)", (sMap["meta"]["style"] is "lean")
   Ed.MenuMark "Scene", "Hiding: Off", (sHide is not "lines")
   Ed.MenuMark "Scene", "Hiding: Hidden Lines", (sHide is "lines")
   repeat for each item tC in "Floor,Wall,Pit,Water,Ceiling,Green,Sky,Relief"
      Ed.MenuMark "Scene", "Show:" && tC, Ed.Shown(toLower(tC))
   end repeat
end Ed.SceneMarks

-------------------------------------------------------------------- the 3D preview's hiding (Scene menu)
-- Show: <class> switches one kind of line on or off (sShow[class] false = off); Hiding: Hidden Lines
-- leaves out what a wall, floor, roof or block stands in front of, as seen from the camera. Each line
-- is cut in three pieces; a piece is drawn when the sight line from its middle to the eye is clear
-- (marched through the map in steps of a third of a cell). Worked out when the view stops moving.

function Ed.Shown pClass
   return sShow[pClass] is not false
end Ed.Shown

-- the eye in engine units (as Ed.ViewRay finds it)
function Ed.Eye
   local tCY, tSY, tCP, tSP, z1
   put cos(sYaw) into tCY
   put sin(sYaw) into tSY
   put cos(sPitch) into tCP
   put sin(sPitch) into tSP
   put tCP * sDist into z1
   return (sTX - z1 * tSY) & comma & (tSP * sDist + sTY) & comma & (z1 * tCY + sTZ)
end Ed.Eye

-- sVis[class]: the visible pieces of sSegs[class] from where the camera is now
on Ed.HideLines
   local tCell, tHU, tBase, tCols, tRows, tSolid, r, c, tC, tLine, tEye, ex, ey, ez, tPair, tClass, tSeg, k, t0, t1
   local x, y, z, tOut, tStep, tTop, tVisPrev, ax, ay, az, bx, by2, bz, tA
   put empty into sVis
   if sMap["floor"] is not an array then exit Ed.HideLines
   put sMap["meta"]["cell"] into tCell
   put CellMap.HU(sMap) into tHU
   put CellMap.Opt(sMap, "base") into tBase
   put sMap["meta"]["cols"] into tCols
   put sMap["meta"]["rows"] into tRows
   put 0 into tTop
   -- each cell's solid spans in engine y: "lo,hi" lines
   repeat with r = 1 to tRows
      repeat with c = 1 to tCols
         put CellMap.Column(sMap, c, r) into tC
         if tC is empty then next repeat
         put "-99999," & ((item 1 of tC + tBase) * tHU) into tSolid[c, r]
         if item 2 of tC is a number then put return & ((item 2 of tC + tBase) * tHU) & comma & ((max(item 3 of tC, item 2 of tC + 4) + tBase) * tHU) after tSolid[c, r]
         repeat for each line tLine in CellMap.Blocks(tC)
            put return & ((item 1 of tLine + tBase) * tHU) & comma & ((item 2 of tLine + tBase) * tHU) after tSolid[c, r]
         end repeat
         repeat for each line tLine in tSolid[c, r]
            put max(tTop, item 2 of tLine) into tTop
         end repeat
      end repeat
   end repeat
   put Ed.Eye() into tEye
   put item 1 of tEye into ex
   put item 2 of tEye into ey
   put item 3 of tEye into ez
   put tCell / 3 into tStep
   repeat for each key tClass in sSegs
      if not Ed.Shown(tClass) then next repeat
      put empty into tOut
      repeat for each line tSeg in sSegs[tClass]
         put item 1 of tSeg into ax
         put item 2 of tSeg into ay
         put item 3 of tSeg into az
         put item 4 of tSeg into bx
         put item 5 of tSeg into by2
         put item 6 of tSeg into bz
         put empty into tVisPrev                   -- where the run of visible pieces began
         repeat with k = 0 to 3
            put false into tA
            if k < 3 then put edClear(ax + (bx - ax) * (k + 0.5) / 3, ay + (by2 - ay) * (k + 0.5) / 3, az + (bz - az) * (k + 0.5) / 3, \
                  ex, ey, ez, tStep, tCell, tCols, tRows, tTop, tSolid) into tA
            if tA and tVisPrev is empty then put k into tVisPrev
            if not tA and tVisPrev is not empty then
               put tVisPrev / 3 into t0
               put k / 3 into t1
               put (ax + (bx - ax) * t0) & comma & (ay + (by2 - ay) * t0) & comma & (az + (bz - az) * t0) & comma & \
                     (ax + (bx - ax) * t1) & comma & (ay + (by2 - ay) * t1) & comma & (az + (bz - az) * t1) & return after tOut
               put empty into tVisPrev
            end if
         end repeat
      end repeat
      put tOut into sVis[tClass]
   end repeat
end Ed.HideLines

-- true when nothing solid stands between the point and the eye
private function edClear pX, pY, pZ, pEX, pEY, pEZ, pStep, pCell, pCols, pRows, pTop, @pSolid
   local dx, dy, dz, tLen, n, i, x, y, z, c, r, tLine, tF
   put pEX - pX into dx
   put pEY - pY into dy
   put pEZ - pZ into dz
   put sqrt(dx * dx + dy * dy + dz * dz) into tLen
   if tLen < pStep then return true
   put trunc(tLen / pStep) into n
   repeat with i = 1 to n
      put i * pStep / tLen into tF
      put pY + dy * tF into y
      if y > pTop and dy >= 0 then return true          -- above everything and still climbing
      put pX + dx * tF into x
      put pZ + dz * tF into z
      put trunc(x / pCell + pCols / 2 + 1000) - 999 into c
      put trunc(z / pCell + pRows / 2 + 1000) - 999 into r
      if c < 1 or r < 1 or c > pCols or r > pRows then
         if dy >= 0 then return true
         next repeat
      end if
      repeat for each line tLine in pSolid[c, r]
         if y < item 2 of tLine - 0.5 and y > item 1 of tLine + 0.5 then return false
      end repeat
   end repeat
   return true
end edClear

-------------------------------------------------------------------- the card sends every click and move here

on Ed.AnyDown pButton
   local tName
   put the short name of the target into tName
   if Ed.BoardCell() is not empty and (tName begins with "b_" or tName begins with "Mirror") then
      Ed.BoardDown
   else if tName begins with "hs_" then
      Ed.HSwatch tName
   else if tName begins with "ss_" then
      Ed.SSwatch tName
   else if Ed.MapCell() is not empty and (tName is "Map2D" or tName is "Ghost" or tName is "GhostBox" or tName is "MarkBox") then
      Ed.MapDown pButton
   else if Ed.OverView() and (tName is "ViewBack" or tName begins with "v_") then
      if pButton is 3 then
         Ed.CamBegin
      else
         Ed.ViewPaintDown
      end if
   end if
end Ed.AnyDown

on Ed.AnyMove
   Ed.MapMove
   Ed.GhostMove
end Ed.AnyMove

on Ed.MouseUp
   if sStrokeKind is "board" or sStrokeKind is "map" or sStrokeKind is "view" then Ed.StrokeEnd
end Ed.MouseUp

-------------------------------------------------------------------- menus

-- new size, keeping what fits; new cells are empty space
on Ed.Resize pCols, pRows
   local tNew, r, c, tKey, tOld
   put sMap into tOld
   put CellMap.New(pCols, pRows, sMap["meta"]["name"]) into tNew
   CellMap.Upgrade tNew
   repeat for each key tKey in sMap["meta"]
      if tKey is not among the items of "cols,rows" then put sMap["meta"][tKey] into tNew["meta"][tKey]
   end repeat
   repeat for each item tKey in "links,objects,stack,tagdefs"
      if sMap[tKey] is an array then put sMap[tKey] into tNew[tKey]
   end repeat
   put 1 into r
   repeat while r <= pRows
      put 1 into c
      repeat while c <= pCols
         if r <= sMap["meta"]["rows"] and c <= sMap["meta"]["cols"] then
            put sMap["design"][r][c] into tNew["design"][r][c]
            put sMap["tags"][r][c] into tNew["tags"][r][c]
            repeat for each item tKey in "floor,ceiling,red,green,blue,from"
               put sMap[tKey][r][c] into tNew[tKey][r][c]
            end repeat
         else
            put 32 into tNew["design"][r][c]
            put space into tNew["tags"][r][c]
            repeat for each item tKey in "floor,ceiling,red,green,blue,from"
               put 0 into tNew[tKey][r][c]
            end repeat
         end if
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   put tNew into sMap
   put empty into sHover
   Ed.ResetCamera
   Ed.MapSnap "resize to" && pCols & "x" & pRows, tOld
   Ed.MakeGhost
end Ed.Resize

on menuPick pItem
   local tMenu
   put the short name of the target into tMenu
   if "|" is in pItem then
      set the itemDel to "|"
      put item -1 of pItem into pItem
      set the itemDel to comma
   end if
   replace "!c" with empty in pItem
   replace "!n" with empty in pItem
   switch tMenu
      case "File"
         Ed.FileMenu pItem
         break
      case "Edit"
         Ed.EditMenu pItem
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
         Ed.SceneMenu pItem
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
         put sFont["meta"]["name"] into sMap["meta"]["font"]
         CellMap.Upgrade sMap
         put sDir & "/maps/untitled.cellmap" into sMapPath
         Ed.HistClear
         put empty into sHover
         Ed.ResetCamera
         Ed.Changed
         Ed.MakeGhost
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
         set the itemDel to comma
         replace ".cellmap" with empty in sMap["meta"]["name"]
         Ed.SaveMap tFile
         break
      case "Save Font"
         Ed.SaveFont
         break
      case "Open Pack..."
         answer file "Open a map pack (.cellpack)" with (sDir & "/maps") with type "Map pack|cellpack|"
         if it is not empty then Ed.OpenPack it
         break
      case "New Pack..."
         Ed.NewPackAsk
         break
      case "Pack Window"
         Ed.PackPanel
         break
      case "Check Map (E12)"
         Ed.PackPanel
         Ed.Check
         break
      case "Export Tags As Text"
         put sDir & "/maps/" & sMap["meta"]["name"] & "_tags.txt" into tFile
         put textEncode(CellMap.LayerText(sMap, "tags"), "UTF-8") into URL ("binfile:" & tFile)
         Ed.Status "wrote" && Ed.ShortName(tFile)
         break
   end switch
end Ed.FileMenu

on Ed.GridMenu pItem
   local tOld
   put sMap into tOld
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
         ask "Height 100 (a full hallway) in engine units (Amazing Couple: 58)" with sMap["meta"]["wallH"]
         if it is a number then put it into sMap["meta"]["wallH"]
         break
      case "Font..."
         ask "Font name (a .font.txt in editor/fonts: Aquarius, Base_001, 24_Seniors_Sigils)" with sMap["meta"]["font"]
         if it is empty then exit Ed.GridMenu
         put it into sMap["meta"]["font"]
         Ed.LoadFont it
         Ed.MakeGhost
         break
   end switch
   if pItem is not "Size (columns, rows)..." then
      if sMap["meta"]["cell"] is not tOld["meta"]["cell"] or sMap["meta"]["wallH"] is not tOld["meta"]["wallH"] or sMap["meta"]["font"] is not tOld["meta"]["font"] then
         Ed.MapSnap toLower(pItem), tOld
      end if
   end if
   Ed.Status "cell" && sMap["meta"]["cell"] && " wall" && sMap["meta"]["wallH"] && " font" && sMap["meta"]["font"]
end Ed.GridMenu

-- the height a property brings when it is painted
on Ed.MeshMenu pItem
   local tOld
   switch pItem
      case "Extrude: Whole Cell"
      case "Extrude: Glyph Shape"
         -- what a height raises: the whole cell (a block), or the cell's glyph as drawn
         put sMap into tOld
         if pItem is "Extrude: Glyph Shape" then
            put "glyph" into sMap["meta"]["extrude"]
         else
            delete variable sMap["meta"]["extrude"]
         end if
         if (sMap["meta"]["extrude"] is "glyph") is not (tOld["meta"]["extrude"] is "glyph") then Ed.MapSnap toLower(pItem), tOld
         Ed.MenuMarks
         if pItem is "Extrude: Glyph Shape" then
            Ed.Status "extrude: glyph shape. A raised cell lifts its glyph's lit bits; the rest of the cell stays floor (saved with the map)"
         else
            Ed.Status "extrude: whole cell. A raised cell is a block; glyphs are low relief on floors"
         end if
         exit Ed.MeshMenu
      case "Height: Property Default"
         put "tag" into sExtrude
         break
      case "Height: Floor (1)"
         put 0 into sExtrude
         break
      case "Height: Step (11)"
         put 1 into sExtrude
         break
      case "Height: Block (33)"
         put 3 into sExtrude
         break
      case "Height: Full Wall (100)"
         put 9 into sExtrude
         break
      default
         exit Ed.MeshMenu
   end switch
   Ed.ShowWhat
   Ed.Status "a painted property brings height:" && Ed.PropFloor()
end Ed.MeshMenu

on Ed.TilesMenu pItem
   local tColour, tOld
   switch pItem
      case "Property Sets Height"
         put true into sPropHeight
         break
      case "Property Only (heights untouched)"
         put false into sPropHeight
         break
      case "Auto Walls"
         -- every plain # wall takes the Aquarius line piece that joins its neighbours
         put sMap into tOld
         CellMap.AutoWalls sMap
         Ed.MapSnap "auto walls", tOld
         Ed.Status "auto walls: the walls are joined line pieces now"
         exit Ed.TilesMenu
      case "Property Colour..."
         answer color with Ed.RGB(sTags[sTag]["colour"])
         if it is empty then exit Ed.TilesMenu
         put Ed.Hex(it) into tColour
         put tColour into sTags[sTag]["colour"]
         if sTags[sTag]["char"] is not empty then
            put sTags[sTag]["name"] into sMap["tagdefs"][sTags[sTag]["char"]]["name"]
            put tColour into sMap["tagdefs"][sTags[sTag]["char"]]["colour"]
            put sTags[sTag]["solid"] into sMap["tagdefs"][sTags[sTag]["char"]]["solid"]
            put sTags[sTag]["height"] into sMap["tagdefs"][sTags[sTag]["char"]]["height"]
            put sTags[sTag]["effect"] into sMap["tagdefs"][sTags[sTag]["char"]]["effect"]
         end if
         put true into sDirtyMap
         Ed.FillProps
         Ed.ShowInfo
         Ed.DrawMap
         exit Ed.TilesMenu
   end switch
   Ed.ShowWhat
   Ed.Status Ed.What()
end Ed.TilesMenu

-- View menu: the ghost's strength ("Ghost: 70%" -> blendLevel 30)
on Ed.ViewMenu pItem
   local tPct
   if pItem is "Ghost: Off" then
      put false into sGhostOn
      Ed.GhostMove
      Ed.Status "ghost preview off"
      exit Ed.ViewMenu
   end if
   put word 2 of pItem into tPct
   replace "%" with empty in tPct
   if tPct is not a number then exit Ed.ViewMenu
   put true into sGhostOn
   set the blendLevel of image "Ghost" to 100 - tPct
   Ed.Status "ghost" && tPct & "%"
end Ed.ViewMenu

-------------------------------------------------------------------- helpers

on Ed.Status pText
   local tFlags
   if sDirtyMap then put "  [map not saved]" after tFlags
   if sDirtyFont then put "  [font not saved]" after tFlags
   put pText & "   |   " & Ed.ShortName(sMapPath) && sMap["meta"]["cols"] & "x" & sMap["meta"]["rows"] & tFlags into field "Status"
end Ed.Status

-- "#RRGGBB" -> "r,g,b"
function Ed.RGB pHex
   if char 1 of pHex is not "#" then return pHex
   return baseConvert(char 2 to 3 of pHex, 16, 10) & comma & baseConvert(char 4 to 5 of pHex, 16, 10) & comma & baseConvert(char 6 to 7 of pHex, 16, 10)
end Ed.RGB

function Ed.Hex pRGB
   return "#" & format("%02X%02X%02X", item 1 of pRGB, item 2 of pRGB, item 3 of pRGB)
end Ed.Hex

-- dark on light colours, light on dark ones
function Ed.Contrast pRGB
   if item 1 of pRGB * 0.3 + item 2 of pRGB * 0.59 + item 3 of pRGB * 0.11 > 140 then return "20,20,24"
   return "235,235,240"
end Ed.Contrast

-------------------------------------------------------------------- tests

-- the state in one line
function Ed.State
   return Ed.ShortName(sMapPath) & "|" & sMap["meta"]["cols"] & "x" & sMap["meta"]["rows"] & "|left " & sLeft & "|glyph " & sCode & "|prop " & sTag & \
         "|map " & sTab & "|h " & sHTool & "," & sHLayer & "," & sHValue & "," & sHBlocks & "|px " & sPx & "|3d " & sSegCount & " lines|" & sDirtyMap & "," & sDirtyFont & "|hist " & Ed.HistCount() & "|" & Ed.What()
end Ed.State

-- the colours really drawn in one cell of the 2D map, most first: "r,g,b xN; ..."
function Ed.MapPixels pC, pR
   local tData, tW, x, y, tAt, tSeen, tKey, tOut
   put the imageData of image "Map2D" into tData
   put the width of image "Map2D" into tW
   put (pR - 1) * sPx into y
   repeat while y < pR * sPx
      put (pC - 1) * sPx into x
      repeat while x < pC * sPx
         put (y * tW + x) * 4 into tAt
         add 1 to tSeen[byteToNum(byte tAt + 2 of tData) & comma & byteToNum(byte tAt + 3 of tData) & comma & byteToNum(byte tAt + 4 of tData)]
         add 1 to x
      end repeat
      add 1 to y
   end repeat
   repeat for each key tKey in tSeen
      put tSeen[tKey] & tab & tKey & return after tOut
   end repeat
   sort lines of tOut descending numeric by word 1 of each
   set the itemDel to tab
   put empty into tData
   repeat for each line tKey in tOut
      put item 2 of tKey && "x" & item 1 of tKey & "; " after tData
   end repeat
   return char 1 to -3 of tData
end Ed.MapPixels

-- where the middle of a cell's top is drawn in the 3D preview: "h,v"
function Ed.TestProject pC, pR
   local tRect, tCol, tY
   put the rect of graphic "ViewBack" into tRect
   put CellMap.Column(sMap, pC, pR) into tCol
   put 0 into tY
   if tCol is not empty then put (item 1 of tCol + CellMap.Opt(sMap, "base")) * CellMap.HU(sMap) into tY
   return edProject(CellMap.CellX(sMap, pC), tY, CellMap.CellZ(sMap, pR), cos(sYaw), sin(sYaw), cos(sPitch), sin(sPitch), \
         (item 1 of tRect + item 3 of tRect) div 2, (item 2 of tRect + item 4 of tRect) div 2 + 30, (item 3 of tRect - item 1 of tRect) * 0.95)
end Ed.TestProject

-- the camera as it is: "yaw,pitch,distance,x,y,z" (what it looks at)
function Ed.TestCamera
   return sYaw & comma & sPitch & comma & sDist & comma & sTX & comma & sTY & comma & sTZ
end Ed.TestCamera

-- the font and one cell of one layer, as they are now
function Ed.TestFont
   return sFont
end Ed.TestFont

-- the 3D preview's lines of one class: all (pVis false) or the visible pieces (tests)
function Ed.TestSegs pClass, pVis
   if pVis then return sVis[pClass]
   return sSegs[pClass]
end Ed.TestSegs

function Ed.TestEye
   return Ed.Eye()
end Ed.TestEye

function Ed.TestCell pWhich, pC, pR
   return sMap[pWhich][pR][pC]
end Ed.TestCell

-- as if the mouse were over cell pC,pR of the 2D map (the 3D mark follows)
on Ed.TestHover pC, pR
   if pC is empty then
      put empty into sHover
   else
      put pC & comma & pR into sHover
   end if
   Ed.ShowHover
   Ed.Draw3DCursor
end Ed.TestHover

-- turn the 3D preview as a drag would
on Ed.TestTurn pYaw, pPitch
   put pYaw into sYaw
   put pPitch into sPitch
   Ed.Draw3D
end Ed.TestTurn
