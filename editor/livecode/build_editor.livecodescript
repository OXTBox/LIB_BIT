script "build_editor"
######################################################################################
## build_editor (LIB_BIT/editor): makes BitEditor.livecode from scratch.
##   start using stack ".../editor/livecode/build_editor.livecodescript"
##   Build.Editor ".../editor"        -> saves .../editor/BitEditor.livecode and returns its path
## The stack script is editor_stack.livecodescript; edit that, then build again.
######################################################################################


command Build.Editor pDir
   local tS, tPath, r, c, x, tMenu, tMenus, tItems
   put "BitEditor" into tS
   if there is a stack tS then delete stack tS
   -- LIB_THEME: one look for every stack (owner, 11 14 2026); templates reset before and after
   Build.UseTheme pDir
   Theme.Begin
   create invisible stack tS
   set the rect of stack tS to 100, 80, 100 + 1180, 80 + 660
   set the title of stack tS to "FOR BILL BitEditor"   -- "Opus BitEditor" while an AI drives it (title rule)
   set the textSize of stack tS to 12
   set the resizable of stack tS to false
   set the defaultStack to tS
   set the script of card 1 of stack tS to Build.CardScript()
   Theme.MenuBar tS, 0, 0, 1180, 30          -- menus sit on a light strip (the menu rule)
   -- menu bar: more menus than tabs (owner's note)
   put "File" & tab & "New Map...|Open Map...|-|Save Map|Save Map As...|-|Save Font|Export Tags As Text" & return & \
         "Bit" & tab & "Flip Horizontal|Flip Vertical|Rotate 90 cw|Rotate 90 ccw|-|Shift Left|Shift Right|Shift Up|Shift Down|-|Invert|Clear|Fill" & return & \
         "Grid" & tab & "Size (columns, rows)...|Cell Size (engine units)...|Wall Height (engine units)...|-|Font..." & return & \
         "Mesh" & tab & "Height: Tag Default|Height: Floor (0)|Height: Step (1)|Height: Block (3)|Height: Full Wall (9)|-|Merge With Neighbours|Keep Every Edge" & return & \
         "Scene" & tab & "Scene Size...|Culling" & return & \
         "Tiles" & tab & "Paint Everything|Paint Design Only|Paint Tag Only|Paint Height Only|-|View Tags|View Design|View Heights|-|Auto Walls|-|Tag Colour..." & return & \
         "View" & tab & "Palette: 100%|Palette: 75%|Palette: 55%|Palette: 35%|-|Map: 100%|Map: 75%|Map: 55%|Map: 35%|-|Ghost: 100%|Ghost: 70%|Ghost: 40%|Ghost: Off" into tMenus
   put 8 into x
   set the itemDel to tab
   repeat for each line tMenu in tMenus
      create button (item 1 of tMenu)
      set the style of it to "menu"
      set the menuMode of it to "pulldown"
      put item 2 of tMenu into tItems
      replace "|" with return in tItems
      set the text of it to tItems
      set the rect of it to x, 4, x + 64, 26
      add 66 to x
   end repeat
   set the itemDel to comma
   -- left: the glyph palette (all 256 glyphs of the map's font, one 1-bit picture), then the codes
   create image "Palette"
   set the rect of it to 8, 34, 264, 290
   create graphic "PalSel"
   set the style of it to "rectangle"
   set the filled of it to false
   set the lineSize of it to 2
   set the foregroundColor of it to Theme.Get("accent")
   set the uThemeSkip of it to true
   set the rect of it to 7, 33, 25, 51
   create field "FilterLabel"
   set the rect of it to 8, 298, 56, 320
   put "Filter:" into field "FilterLabel"
   set the lockText of it to true
   set the opaque of it to false
   create field "Filter"
   set the rect of it to 58, 298, 272, 320
   set the script of it to "on textChanged" & return & "Ed.FillList" & return & "end textChanged"
   create field "Codes"
   set the rect of it to 8, 326, 272, 620
   set the listBehavior of it to true
   set the lockText of it to true
   set the dontWrap of it to true
   set the vScrollbar of it to true
   set the textFont of it to "Courier New"
   set the script of it to "on mouseUp" & return & "Ed.ListClicked" & return & "end mouseUp"
   -- middle: the drawing board (16 x 16), the selected code, the quick functions
   reset the templateGraphic
   set the style of the templateGraphic to "rectangle"
   set the filled of the templateGraphic to true
   set the foregroundColor of the templateGraphic to Theme.Get("bg")
   set the lineSize of the templateGraphic to 1
   put 1 into r
   repeat while r <= 16
      put 1 into c
      repeat while c <= 16
         create graphic ("b_" & r & "_" & c)
         set the rect of it to 284 + (c - 1) * 18, 34 + (r - 1) * 18, 284 + c * 18, 34 + r * 18
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   create graphic "Swatch"
   set the rect of it to 284, 332, 314, 362
   reset the templateGraphic
   create field "Info"
   set the rect of it to 320, 328, 572, 396
   set the lockText of it to true
   create field "Quick"
   set the rect of it to 284, 404, 572, 620
   set the listBehavior of it to true
   set the lockText of it to true
   put "Flip Horizontal|Flip Vertical|Rotate 90 ccw|Rotate 90 cw|Invert|Clear|Shift Left|Shift Right|Shift Up|Shift Down" into tItems
   replace "|" with return in tItems
   put tItems into field "Quick"
   set the script of it to "on mouseUp" & return & "Ed.GlyphDo the value of the clickLine" & return & "end mouseUp"
   -- right: the viewport tabs and the map
   create button "ViewTabs"
   set the style of it to "menu"
   set the menuMode of it to "tabbed"
   set the text of it to "1bit" & return & "Cells" & return & "Heights" & return & "Vibe" & return & "xt3D"
   set the rect of it to 582, 30, 1172, 622
   create graphic "MapFrame"
   set the style of it to "rectangle"
   set the filled of it to true
   set the backgroundColor of it to Theme.Get("panel")
   set the foregroundColor of it to Theme.Get("panel")
   set the rect of it to 590, 60, 1164, 614
   -- the 1bit view: the whole map as one 1-bit picture of its glyphs (drawn by the stack script)
   create image "OneBit"
   set the rect of it to 594, 64, 610, 80
   -- the ghost: the selected glyph, shown in the cell under the mouse before it is painted
   create image "Ghost"
   set the rect of it to 594, 64, 610, 80
   set the visible of it to false
   create graphic "GhostBox"
   set the style of it to "rectangle"
   set the filled of it to false
   set the lineSize of it to 1
   set the foregroundColor of it to Theme.Get("accent")
   set the uThemeSkip of it to true
   set the visible of it to false
   -- the Heights view (CELLMAP_V2.md): the map in floor / ceiling colours, tools and swatches over it
   create image "HeightMap"
   set the rect of it to 594, 170, 610, 186
   set the visible of it to false
   Build.HeightTools
   create field "NotYet"
   set the rect of it to 602, 80, 1152, 220
   set the lockText of it to true
   set the visible of it to false
   create field "Status"
   set the rect of it to 8, 628, 1172, 652
   set the lockText of it to true
   -- one look for everything (fields, buttons, menus by the menu rule), then templates reset
   Theme.ApplyStack tS
   set the opaque of field "HInfo" of stack tS to false
   set the showBorder of field "HInfo" of stack tS to false
   set the opaque of field "FilterLabel" of stack tS to false
   Theme.End
   -- the behaviour, then save next to the data
   set the script of stack tS to Build.ReadText(pDir & "/livecode/editor_stack.livecodescript")
   put pDir & "/BitEditor.livecode" into tPath
   set the fileName of stack tS to tPath
   save stack tS
   return tPath
end Build.Editor

-- Floor / Ceiling / Blocks buttons, the info lines, four rows of swatches (grey, red, green, blue:
-- 0, 1, 10, 20 ... 250, 255), the selection box; one group, shown with the Heights tab
command Build.HeightTools
   local tValues, v, x, y, tRow, tName, tColour, tShown, tTint
   reset the templateGroup
   create group "HeightTools"
   set the margins of group "HeightTools" to 0
   set the showBorder of group "HeightTools" to false
   put 594 into x
   repeat for each item tName in "Floor,Ceiling,Blocks"
      create button ("Tool" & tName) in group "HeightTools"
      set the label of it to tName
      set the autoHilite of it to false
      set the rect of it to x, 64, x + 66, 86
      set the script of it to "on mouseUp" & return & "Ed.HTool " & quote & toLower(tName) & quote & return & "end mouseUp"
      add 70 to x
   end repeat
   set the tooltip of button "ToolFloor" to "Greys paint the floor; glyphs show the floor colour"
   set the tooltip of button "ToolCeiling" to "Greys paint the ceiling; glyphs show the ceiling colour"
   set the tooltip of button "ToolBlocks" to "Show squares instead of glyphs (the same two colours)"
   create field "HInfo" in group "HeightTools"
   set the rect of it to 808, 60, 1162, 92
   set the lockText of it to true
   set the textSize of it to 10
   set the dontWrap of it to true
   put "0,1" into tValues
   put 10 into v
   repeat while v <= 250
      put comma & v after tValues
      add 10 to v
   end repeat
   put ",255" after tValues
   reset the templateGraphic
   set the style of the templateGraphic to "rectangle"
   set the filled of the templateGraphic to true
   set the lineSize of the templateGraphic to 1
   set the foregroundColor of the templateGraphic to "70,70,78"
   put 94 into y
   repeat for each item tRow in "grey,red,green,blue"
      put 594 into x
      repeat for each item v in tValues
         put 0 into tShown
         if v > 0 then put 40 + round(v * 215 / 255) into tShown
         put 0 into tTint
         if v > 0 then put 90 + round(v * 165 / 255) into tTint
         switch tRow
            case "grey"
               put tShown & comma & tShown & comma & tShown into tColour
               break
            case "red"
               put tTint & ",12,12" into tColour
               break
            case "green"
               put "12," & tTint & ",12" into tColour
               break
            case "blue"
               put "12,12," & tTint into tColour
               break
         end switch
         create graphic ("hs_" & tRow & "_" & v) in group "HeightTools"
         set the rect of it to x, y, x + 20, y + 16
         set the backgroundColor of it to tColour
         set the uThemeSkip of it to true
         set the tooltip of it to tRow && v
         add 20 to x
      end repeat
      add 17 to y
   end repeat
   reset the templateGraphic
   create graphic "HSel" in group "HeightTools"
   set the style of it to "rectangle"
   set the filled of it to false
   set the lineSize of it to 2
   set the foregroundColor of it to Theme.Get("accent")
   set the uThemeSkip of it to true
   set the rect of it to 593, 93, 615, 111
   set the visible of group "HeightTools" to false
end Build.HeightTools

command Build.UseTheme pDir
   local tLib
   set the itemDel to "/"
   put item 1 to -3 of pDir & "/LIB_THEME/livecode/lib_theme.livecodescript" into tLib
   if there is not a file tLib then
      answer "LIB_THEME not found: " & tLib
      exit to top
   end if
   start using stack tLib
   Theme.Use "dark"
end Build.UseTheme

function Build.CardScript
   return "on mouseDown pButton" & return & \
         "  local tName" & return & \
         "  put the short name of the target into tName" & return & \
         "  if tName begins with " & quote & "m_" & quote & " then Ed.MapDown tName, pButton" & return & \
         "  if tName begins with " & quote & "b_" & quote & " then Ed.BoardDown tName" & return & \
         "  if tName is " & quote & "OneBit" & quote & " or tName is " & quote & "Ghost" & quote & " then Ed.OneBitDown pButton" & return & \
         "  if tName is " & quote & "Palette" & quote & " then Ed.PaletteDown" & return & \
         "  if tName is " & quote & "HeightMap" & quote & " then Ed.HDown pButton" & return & \
         "  if tName begins with " & quote & "hs_" & quote & " then Ed.HSwatch tName" & return & \
         "end mouseDown" & return & \
         "on mouseMove" & return & "  Ed.BoardMove" & return & "  Ed.MapMove" & return & "  Ed.OneBitMove" & return & "  Ed.GhostMove" & return & "  Ed.HMove" & return & "end mouseMove" & return & \
         "on mouseUp" & return & "  Ed.MouseUp" & return & "end mouseUp" & return & \
         "on mouseLeave" & return & "  Ed.GhostMove" & return & "end mouseLeave" & return & \
         "on mouseRelease" & return & "  Ed.MouseUp" & return & "end mouseRelease"
end Build.CardScript

function Build.ReadText pPath
   return textDecode(URL ("binfile:" & pPath), "UTF-8")
end Build.ReadText
