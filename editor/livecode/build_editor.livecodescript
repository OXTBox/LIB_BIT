script "build_editor"
######################################################################################
## build_editor (LIB_BIT/editor): makes BitEditor.livecode from scratch.
##   start using stack ".../editor/livecode/build_editor.livecodescript"
##   Build.Editor ".../editor"        -> saves .../editor/BitEditor.livecode and returns its path
## The stack script is editor_stack.livecodescript; edit that, then build again.
######################################################################################

constant kBG = "30,30,34"
constant kPanel = "42,42,48"
constant kText = "220,220,224"

command Build.Editor pDir
   local tS, tPath, r, c, x, tMenu, tMenus, tItems
   put "BitEditor" into tS
   if there is a stack tS then delete stack tS
   reset the templateStack
   create invisible stack tS
   set the rect of stack tS to 120, 80, 120 + 1140, 80 + 660
   set the title of stack tS to "FOR BILL BitEditor"   -- "Opus BitEditor" while an AI drives it (title rule)
   set the backgroundColor of stack tS to kBG
   set the foregroundColor of stack tS to kText
   set the textSize of stack tS to 12
   set the resizable of stack tS to false
   set the defaultStack to tS
   set the script of card 1 of stack tS to Build.CardScript()
   -- menu bar: more menus than tabs (owner's note)
   put "File" & tab & "New Map...|Open Map...|-|Save Map|Save Map As...|-|Save Font|Export Tags As Text" & return & \
         "Bit" & tab & "Flip Horizontal|Flip Vertical|Rotate 90 cw|Rotate 90 ccw|-|Shift Left|Shift Right|Shift Up|Shift Down|-|Invert|Clear|Fill" & return & \
         "Grid" & tab & "Size (columns, rows)...|Cell Size (engine units)...|Wall Height (engine units)...|-|Font..." & return & \
         "Mesh" & tab & "Height: Tag Default|Height: Floor (0)|Height: Step (1)|Height: Block (3)|Height: Full Wall (9)|-|Merge With Neighbours|Keep Every Edge" & return & \
         "Scene" & tab & "Scene Size...|Culling" & return & \
         "Tiles" & tab & "Paint Everything|Paint Design Only|Paint Tag Only|Paint Height Only|-|View Tags|View Design|View Heights|-|Tag Colour..." into tMenus
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
      Build.Dark it
      add 66 to x
   end repeat
   set the itemDel to comma
   -- left: the 256 codes
   create field "FilterLabel"
   set the rect of it to 8, 34, 56, 56
   put "Filter:" into field "FilterLabel"
   set the lockText of it to true
   Build.Dark it
   set the opaque of it to false
   create field "Filter"
   set the rect of it to 58, 34, 230, 56
   set the script of it to "on textChanged" & return & "Ed.FillList" & return & "end textChanged"
   Build.Dark it
   create field "Codes"
   set the rect of it to 8, 62, 230, 620
   set the listBehavior of it to true
   set the lockText of it to true
   set the dontWrap of it to true
   set the vScrollbar of it to true
   set the textFont of it to "Courier New"
   set the script of it to "on mouseUp" & return & "Ed.ListClicked" & return & "end mouseUp"
   Build.Dark it
   -- middle: the drawing board (16 x 16), the selected code, the quick functions
   reset the templateGraphic
   set the style of the templateGraphic to "rectangle"
   set the filled of the templateGraphic to true
   set the foregroundColor of the templateGraphic to kBG
   set the lineSize of the templateGraphic to 1
   put 1 into r
   repeat while r <= 16
      put 1 into c
      repeat while c <= 16
         create graphic ("b_" & r & "_" & c)
         set the rect of it to 242 + (c - 1) * 18, 34 + (r - 1) * 18, 242 + c * 18, 34 + r * 18
         add 1 to c
      end repeat
      add 1 to r
   end repeat
   create graphic "Swatch"
   set the rect of it to 242, 332, 272, 362
   reset the templateGraphic
   create field "Info"
   set the rect of it to 278, 328, 530, 396
   set the lockText of it to true
   Build.Dark it
   create field "Quick"
   set the rect of it to 242, 404, 530, 620
   set the listBehavior of it to true
   set the lockText of it to true
   put "Flip Horizontal|Flip Vertical|Rotate 90 ccw|Rotate 90 cw|Invert|Clear|Shift Left|Shift Right|Shift Up|Shift Down" into tItems
   replace "|" with return in tItems
   put tItems into field "Quick"
   set the script of it to "on mouseUp" & return & "Ed.GlyphDo the value of the clickLine" & return & "end mouseUp"
   Build.Dark it
   -- right: the viewport tabs and the map
   create button "ViewTabs"
   set the style of it to "menu"
   set the menuMode of it to "tabbed"
   set the text of it to "1bit" & return & "Vibe" & return & "xt3D"
   set the rect of it to 540, 30, 1132, 622
   Build.Dark it
   create graphic "MapFrame"
   set the style of it to "rectangle"
   set the filled of it to true
   set the backgroundColor of it to kPanel
   set the foregroundColor of it to kPanel
   set the rect of it to 548, 60, 1124, 614
   create field "NotYet"
   set the rect of it to 560, 80, 1112, 220
   set the lockText of it to true
   set the visible of it to false
   Build.Dark it
   create field "Status"
   set the rect of it to 8, 628, 1132, 652
   set the lockText of it to true
   Build.Dark it
   -- the behaviour, then save next to the data
   set the script of stack tS to Build.ReadText(pDir & "/livecode/editor_stack.livecodescript")
   put pDir & "/BitEditor.livecode" into tPath
   set the fileName of stack tS to tPath
   save stack tS
   return tPath
end Build.Editor

command Build.Dark pObj
   set the backgroundColor of pObj to kPanel
   set the foregroundColor of pObj to kText
   set the borderColor of pObj to "70,70,80"
   set the threeD of pObj to false
   set the showFocusBorder of pObj to false
   if word 1 of pObj is "field" then set the showBorder of pObj to false
end Build.Dark

function Build.CardScript
   return "on mouseDown pButton" & return & \
         "  local tName" & return & \
         "  put the short name of the target into tName" & return & \
         "  if tName begins with " & quote & "m_" & quote & " then Ed.MapDown tName, pButton" & return & \
         "  if tName begins with " & quote & "b_" & quote & " then Ed.BoardDown tName" & return & \
         "end mouseDown" & return & \
         "on mouseMove" & return & "  Ed.BoardMove" & return & "  Ed.MapMove" & return & "end mouseMove" & return & \
         "on mouseUp" & return & "  Ed.MouseUp" & return & "end mouseUp" & return & \
         "on mouseRelease" & return & "  Ed.MouseUp" & return & "end mouseRelease"
end Build.CardScript

function Build.ReadText pPath
   return textDecode(URL ("binfile:" & pPath), "UTF-8")
end Build.ReadText
