script "build_editor"
######################################################################################
## build_editor (LIB_BIT/editor): makes BitEditor.livecode from scratch (layout 2).
##   start using stack ".../editor/livecode/build_editor.livecodescript"
##   Build.Editor ".../editor"        -> saves .../editor/BitEditor.livecode and returns its path
## The stack script is editor_stack.livecodescript; edit that, then build again.
## Layout 2 (the owner, 11 14 2026): left = drawing board over a tabbed list (Glyphs /
## Properties, one at a time); middle = the 2D map, always there, tabs 1bit / Cells / Heights;
## right = the 3D preview. Nothing else on the screen.
## 11 15 2026: the tabs are drawn (Theme.TabStrip), not the native tab control (light grey on
## white whatever the colours); Edit menu (undo); mirror guide lines on the board.
######################################################################################

constant kW = 1280
constant kH = 668

command Build.Editor pDir
   local tS, tPath, r, c, x, tMenu, tMenus, tItems, tCode, tClass, tPair, tClasses, tErr
   put "BitEditor" into tS
   if there is a stack tS then delete stack tS
   -- LIB_THEME: one look for every stack (owner, 11 14 2026); templates reset before and after
   Build.UseTheme pDir
   Theme.Begin
   create invisible stack tS
   set the rect of stack tS to 60, 60, 60 + kW, 60 + kH
   set the title of stack tS to "FOR OWNER | BitEditor"
   dispatch "Users.TitleStack" with tS, "BitEditor"   -- LIB_USERS words it, when in use ("Opus | BitEditor" while an AI drives)
   set the textSize of stack tS to 12
   set the resizable of stack tS to false
   set the defaultStack to tS
   Theme.MenuBar tS, 0, 0, kW, 30          -- menus sit on a light strip (the menu rule)
   put "File" & tab & "New Map...|Open Map...|-|Save Map|Save Map As...|-|Open Pack...|New Pack...|Pack Window|Check Map (E12)|-|Save Font|Export Tags As Text" & return & \
         "Edit" & tab & "Undo (Ctrl+Z)|Redo (Ctrl+Y)|-|Export Change History" & return & \
         "Bit" & tab & "Mirror H While Drawing|Mirror V While Drawing|Mirror H Now (left onto right)|Mirror V Now (top onto bottom)|-|Flip Horizontal|Flip Vertical|Rotate 90 cw|Rotate 90 ccw|-|Shift Left|Shift Right|Shift Up|Shift Down|-|Invert|Clear|Fill" & return & \
         "Grid" & tab & "Size (columns, rows)...|Cell Size (engine units)...|Wall Height (engine units)...|-|Font..." & return & \
         "Mesh" & tab & "Extrude: Whole Cell|Extrude: Glyph Shape|-|Height: Property Default|Height: Floor (1)|Height: Step (11)|Height: Block (33)|Height: Full Wall (100)" & return & \
         "Scene" & tab & "Reset View|Top View (as the 2D map)|From The South|From The East|-|Zoom In|Zoom Out|-|Glyph Relief On / Off|Lean Style (outlines only)|-|Hiding: Off|Hiding: Hidden Lines|-|Show: Floor|Show: Wall|Show: Pit|Show: Water|Show: Ceiling|Show: Green|Show: Sky|Show: Relief|Show: All" & return & \
         "Tiles" & tab & "Property Sets Height|Property Only (heights untouched)|-|Auto Walls|-|Property Colour..." & return & \
         "View" & tab & "Ghost: 100%|Ghost: 70%|Ghost: 40%|Ghost: Off" into tMenus
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

   ---------------------------------------------------------------- left: board, then the tabbed lists
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
         set the rect of it to 8 + (c - 1) * 16, 34 + (r - 1) * 16, 8 + c * 16, 34 + r * 16
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   reset the templateGraphic
   -- the mirror guide lines (Bit menu: Mirror H / V While Drawing), over the board
   repeat for each item tItems in "H,V"
      create graphic ("Mirror" & tItems & "Line")
      set the style of it to "line"
      set the lineSize of it to 2
      set the foregroundColor of it to Theme.Get("accent")
      set the uThemeSkip of it to true
      if tItems is "H" then
         set the points of it to "136,34" & return & "136,290"
      else
         set the points of it to "8,162" & return & "264,162"
      end if
      set the visible of it to false
   end repeat
   -- drawn tabs over a page of the panel colour
   create graphic "LeftFrame"
   set the style of it to "rectangle"
   set the filled of it to true
   set the backgroundColor of it to Theme.Get("panel")
   set the foregroundColor of it to Theme.Get("border")
   set the uThemeSkip of it to true
   set the rect of it to 4, 319, 276, 634
   Theme.TabStrip "Left", "Glyphs" & return & "Properties", 4, 296, 100, 24
   create field "FilterLabel"
   set the rect of it to 12, 326, 56, 348
   put "Filter:" into field "FilterLabel"
   set the lockText of it to true
   create field "Filter"
   set the rect of it to 58, 326, 268, 348
   set the script of it to "on textChanged" & return & "Ed.FilterChanged" & return & "end textChanged"
   repeat for each item tItems in "Glyphs,Props"
      create field tItems
      set the rect of it to 12, 354, 268, 556
      set the listBehavior of it to true
      set the lockText of it to true
      set the dontWrap of it to true
      set the vScrollbar of it to true
      set the textFont of it to "Courier New"
      set the fixedLineHeight of it to true
      set the textHeight of it to 19
      set the script of it to "on mouseUp" & return & "Ed.ListClicked " & quote & tItems & quote & return & "end mouseUp"
   end repeat
   set the visible of field "Props" to false
   create graphic "Swatch"
   set the style of it to "rectangle"
   set the filled of it to true
   set the uThemeSkip of it to true
   set the rect of it to 12, 562, 36, 586
   create field "Info"
   set the rect of it to 40, 560, 268, 628
   set the lockText of it to true
   set the textSize of it to 10
   -- the glyphs' own pictures (16 x 16 each), hidden: the Glyphs list shows them as imageSources
   reset the templateGroup
   create group "GlyphImages"
   put 0 into tCode
   repeat while tCode <= 255
      create image ("g_" & tCode) in group "GlyphImages"
      set the rect of it to 300, 40, 316, 56
      add 1 to tCode
   end repeat
   set the visible of group "GlyphImages" to false

   ---------------------------------------------------------------- middle: the 2D map, three views
   Theme.TabStrip "Map", "1bit" & return & "Cells" & return & "Heights" & return & "Slope", 288, 34, 84, 25
   create graphic "MapFrame"
   set the style of it to "rectangle"
   set the filled of it to true
   set the backgroundColor of it to Theme.Get("panel")
   set the foregroundColor of it to Theme.Get("panel")
   set the uThemeSkip of it to true
   set the rect of it to 288, 58, 778, 628
   create field "PaintInfo"                  -- line 1: what a click paints; line 2: the cell under the mouse
   set the rect of it to 294, 62, 772, 96
   set the lockText of it to true
   set the textSize of it to 10
   set the dontWrap of it to true
   Build.HeightTools
   Build.SlopeTools
   create image "Map2D"
   set the rect of it to 296, 192, 312, 208
   create image "Ghost"
   set the rect of it to 296, 192, 312, 208
   set the blendLevel of it to 30
   set the visible of it to false
   create graphic "GhostBox"
   set the style of it to "rectangle"
   set the filled of it to false
   set the lineSize of it to 1
   set the foregroundColor of it to Theme.Get("accent")
   set the uThemeSkip of it to true
   create graphic "MarkBox"                  -- the cell a checker line points at (pack window)
   set the style of it to "rectangle"
   set the filled of it to false
   set the lineSize of it to 2
   set the foregroundColor of it to "255,60,200"
   set the uThemeSkip of it to true
   set the visible of it to false
   set the visible of it to false

   ---------------------------------------------------------------- right: the 3D preview
   create graphic "ViewBack"
   set the style of it to "rectangle"
   set the filled of it to true
   set the backgroundColor of it to "12,12,16"
   set the foregroundColor of it to "70,70,78"
   set the uThemeSkip of it to true
   set the rect of it to 790, 34, 1274, 634
   reset the templateGroup
   create group "View3D"
   set the margins of group "View3D" to 0
   set the showBorder of group "View3D" to false
   set the lockLoc of group "View3D" to true
   set the rect of group "View3D" to 791, 35, 1273, 633      -- sized while empty: a locked group clips its lines
   put "floor 40,110,130|wall 127,168,255|pit 255,80,64|water 64,224,255|ceiling 144,152,168|green 80,224,112|sky 184,216,255|relief 255,255,255|cursor 255,214,10" into tClasses
   replace "|" with return in tClasses
   repeat for each line tPair in tClasses
      put word 1 of tPair into tClass
      create graphic ("v_" & tClass) in group "View3D"
      set the style of it to "polygon"
      set the filled of it to false
      set the lineSize of it to 1
      if tClass is "cursor" then set the lineSize of it to 2
      set the foregroundColor of it to word 2 of tPair
      set the uThemeSkip of it to true
   end repeat
   set the rect of group "View3D" to 791, 35, 1273, 633
   create field "ViewTitle"
   set the rect of it to 796, 38, 1268, 56
   set the lockText of it to true
   set the textSize of it to 10
   set the dontWrap of it to true
   create field "Status"
   set the rect of it to 4, 640, kW - 4, 664
   set the lockText of it to true
   -- one look for everything (fields, buttons, menus by the menu rule), then templates reset
   Theme.ApplyStack tS
   repeat for each item tItems in "FilterLabel,PaintInfo,ViewTitle"
      set the opaque of field tItems of stack tS to false
      set the showBorder of field tItems of stack tS to false
   end repeat
   Theme.End
   -- the behaviour, then save next to the data
   -- If the stack script does not compile, nothing is saved: a stack without its handlers
   -- throws an error at every mouse move (the owner met this on 11 15 2026, building while
   -- the script was being edited). The card script goes in last, for the same reason.
   set the script of stack tS to Build.ReadText(pDir & "/livecode/editor_stack.livecodescript")
   put the result into tErr
   if tErr is not empty then
      delete stack tS
      answer "BitEditor NOT built: editor_stack.livecodescript does not compile (it may be mid-edit; try again in a minute)." & return & line 1 of tErr
      return "ERROR: editor_stack does not compile:" && line 1 of tErr
   end if
   set the script of card 1 of stack tS to Build.CardScript()
   put pDir & "/BitEditor.livecode" into tPath
   set the fileName of stack tS to tPath
   save stack tS
   return tPath
end Build.Editor

-- the Slope tab (cellmap v3, the owner's notes of 19 Nov 2026): which way is uphill (a compass, Auto in
-- the middle), how a click paints (Ramp: drag a box, one smooth hill; One Cell; Flatten), Join (a ramp
-- runs from the floor before it to the floor after it) and the rise swatches
command Build.SlopeTools
   local tDirs, i, tName, x, y, v, tShown, tValues
   reset the templateGroup
   create group "SlopeTools"
   set the margins of group "SlopeTools" to 0
   set the showBorder of group "SlopeTools" to false
   set the backgroundColor of the templateButton to Theme.Get("panel")
   set the foregroundColor of the templateButton to Theme.Get("text")
   set the textSize of the templateButton to 10
   put "NW,N,NE,W,Auto,E,SW,S,SE" into tDirs
   repeat with i = 1 to 9
      put item i of tDirs into tName
      create button ("SDir" & tName) in group "SlopeTools"
      set the label of it to tName
      set the autoHilite of it to false
      put 296 + ((i - 1) mod 3) * 34 into x
      put 98 + ((i - 1) div 3) * 21 into y
      set the rect of it to x, y, x + 32, y + 19
      set the tooltip of it to "uphill:" && tName
      set the script of it to "on mouseUp" & return & "Ed.SDir " & quote & toLower(tName) & quote & return & "end mouseUp"
   end repeat
   set the tooltip of button "SDirAuto" to "uphill from the way you drag (a click: the edge or corner nearest it)"
   set the textSize of the templateButton to 11
   put 404 into x
   repeat for each item tName in "Ramp,One Cell,Flatten"
      create button ("SMode" & word -1 of tName) in group "SlopeTools"   -- SModeRamp, SModeCell, SModeFlatten
      set the label of it to tName
      set the autoHilite of it to false
      set the rect of it to x, 98, x + 70, 118
      set the script of it to "on mouseUp" & return & "Ed.SMode " & quote & toLower(word -1 of tName) & quote & return & "end mouseUp"
      add 74 to x
   end repeat
   set the tooltip of button "SModeRamp" to "Drag a box on the map: it becomes one smooth slope rising the compass way"
   set the tooltip of button "SModeCell" to "Each cell on its own: lifts its uphill edge or corner (right-click copies a cell's slope)"
   set the tooltip of button "SModeFlatten" to "Paint cells flat (their floor stays)"
   set the style of the templateButton to "checkbox"
   create button "SJoin" in group "SlopeTools"
   set the label of it to "Join: from the floor before the box to the floor after it"
   set the autoHilite of it to false
   set the rect of it to 404, 122, 772, 140
   set the tooltip of it to "On: a ramp starts at the floor just before the box and ends at the floor just after it (else it rises by the swatch)"
   set the script of it to "on mouseUp" & return & "Ed.SJoin" & return & "end mouseUp"
   reset the templateButton
   reset the templateField
   create field "SWords" in group "SlopeTools"
   set the rect of it to 404, 141, 772, 160
   set the lockText of it to true
   set the textSize of it to 10
   set the dontWrap of it to true
   set the opaque of it to false
   set the showBorder of it to false
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
   put 296 into x
   repeat for each item v in tValues
      put 0 into tShown
      if v > 0 then put 40 + round(v * 215 / 255) into tShown
      create graphic ("ss_" & v) in group "SlopeTools"
      set the rect of it to x, 166, x + 17, 181
      set the backgroundColor of it to tShown & comma & tShown & comma & tShown
      set the uThemeSkip of it to true
      set the tooltip of it to "rise" && v && "hu"
      add 17 to x
   end repeat
   reset the templateGraphic
   create graphic "SSel" in group "SlopeTools"
   set the style of it to "rectangle"
   set the filled of it to false
   set the lineSize of it to 2
   set the foregroundColor of it to Theme.Get("accent")
   set the uThemeSkip of it to true
   set the rect of it to 295, 165, 314, 182
   set the visible of group "SlopeTools" to false
end Build.SlopeTools

-- Floor / Ceiling / Blocks buttons, a hint, four rows of swatches (grey, red, green, blue:
-- 0, 1, 10, 20 ... 250, 255), the selection box; one group, shown with the Heights view
command Build.HeightTools
   local tValues, v, x, y, tRow, tName, tColour, tShown, tTint
   reset the templateGroup
   create group "HeightTools"
   set the margins of group "HeightTools" to 0
   set the showBorder of group "HeightTools" to false
   put 296 into x
   repeat for each item tName in "Floor,Ceiling,Blocks"
      create button ("Tool" & tName) in group "HeightTools"
      set the label of it to tName
      set the autoHilite of it to false
      if tName is "Ceiling" then
         set the rect of it to x, 98, x + 56, 118
         add 60 to x
      else
         set the rect of it to x, 98, x + 48, 118
         add 52 to x
      end if
      set the script of it to "on mouseUp" & return & "Ed.HTool " & quote & toLower(tName) & quote & return & "end mouseUp"
   end repeat
   set the tooltip of button "ToolFloor" to "Greys paint the floor; glyphs show the floor colour on the ceiling colour"
   set the tooltip of button "ToolCeiling" to "Greys paint the ceiling; glyphs show the ceiling colour on the floor colour"
   set the tooltip of button "ToolBlocks" to "Show squares instead of glyphs (the same two colours)"
   -- From Floor / From Ceiling (the owner, 18 Nov 2026): painted cell by cell like a height. A click
   -- on a box makes the two boxes the brush; a click on a cell gives it what the boxes say
   -- (CELLMAP_V2.md 3b; the cell's [from] value: 1 From Floor + 2 From Ceiling)
   set the backgroundColor of the templateButton to Theme.Get("panel")
   set the foregroundColor of the templateButton to Theme.Get("text")
   set the style of the templateButton to "checkbox"
   put 462 into x
   repeat for each item tName in "Floor,Ceiling"
      create button ("HFrom" & tName) in group "HeightTools"
      set the label of it to "From" && tName
      set the autoHilite of it to false
      if tName is "Ceiling" then
         set the rect of it to x, 98, x + 92, 118
      else
         set the rect of it to x, 98, x + 84, 118
      end if
      set the script of it to "on mouseUp" & return & "Ed.HFrom " & quote & toLower(tName) & quote & return & "end mouseUp"
      add 86 to x
   end repeat
   reset the templateButton
   set the tooltip of button "HFromFloor" to "Paint it on cells: From Floor fills the cell solid under its block"
   set the tooltip of button "HFromCeiling" to "Paint it on cells: the block hangs from the top of the map (a roof too)"
   -- the map's top (where From Ceiling hangs from): shown, a click changes it
   set the backgroundColor of the templateField to Theme.Get("panel")
   set the foregroundColor of the templateField to Theme.Get("text")
   create field "HTop" in group "HeightTools"
   reset the templateField
   set the rect of it to 642, 99, 692, 118
   set the lockText of it to true
   set the textSize of it to 10
   set the dontWrap of it to true
   set the tooltip of it to "The top of the map in hu: From Ceiling hangs from here. Click to change it"
   set the script of it to "on mouseUp" & return & "Ed.HTopAsk" & return & "end mouseUp"
   -- Extrude Glyphs to Heights: a second step, off while you paint heights (the owner, 18 Nov 2026)
   set the backgroundColor of the templateButton to Theme.Get("panel")
   set the foregroundColor of the templateButton to Theme.Get("text")
   create button "HExtrude" in group "HeightTools"
   reset the templateButton
   set the label of it to "Extrude Glyphs"
   set the autoHilite of it to false
   set the rect of it to 694, 98, 772, 118
   set the tooltip of it to "Extrude Glyphs to Heights: a raised cell lifts its glyph's shape, not the whole cell (Mesh menu too; saved with the map)"
   set the script of it to "on mouseUp" & return & "Ed.HExtrude" & return & "end mouseUp"
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
   put 122 into y
   repeat for each item tRow in "grey,red,green,blue"
      put 296 into x
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
         set the rect of it to x, y, x + 17, y + 15
         set the backgroundColor of it to tColour
         set the uThemeSkip of it to true
         if tRow is "green" and v > 0 then
            set the tooltip of it to "green" && v & ": a block whose top is" && 255 + v && "hu"
         else if tRow is "blue" and v > 0 then
            set the tooltip of it to "blue" && v & ": a block whose top is" && 510 + v && "hu"
         else
            set the tooltip of it to tRow && v
         end if
         add 17 to x
      end repeat
      add 16 to y
   end repeat
   reset the templateGraphic
   create graphic "HSel" in group "HeightTools"
   set the style of it to "rectangle"
   set the filled of it to false
   set the lineSize of it to 2
   set the foregroundColor of it to Theme.Get("accent")
   set the uThemeSkip of it to true
   set the rect of it to 295, 121, 314, 138
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

-- the card sees every click and move and hands them to the stack script
function Build.CardScript
   return "on mouseDown pButton" & return & "  Ed.AnyDown pButton" & return & "end mouseDown" & return & \
         "on mouseMove" & return & "  Ed.AnyMove" & return & "end mouseMove" & return & \
         "on mouseUp" & return & "  Ed.MouseUp" & return & "end mouseUp" & return & \
         "on mouseLeave" & return & "  Ed.GhostMove" & return & "end mouseLeave" & return & \
         "on mouseRelease" & return & "  Ed.MouseUp" & return & "end mouseRelease"
end Build.CardScript

function Build.ReadText pPath
   return textDecode(URL ("binfile:" & pPath), "UTF-8")
end Build.ReadText
