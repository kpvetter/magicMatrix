#!/bin/sh
# Restart with tcl: -*- mode: tcl; tab-width: 8; -*- \
exec tclsh $0 ${1+"$@"} & \
exit

##+##########################################################################
#
# numberSums.tcl -- <description>
# by Keith Vetter 2025-08-19
#
# TODO:
#  mode with punishes guesses -- bark if not forced
#  check starting size w/ screensize
#  reveal: from logic or by brute force
#  show size/seed and create board with size/seed
#
#  auto solve
#  animation
#  dynamic resizing
#  unscaled constant in GrowBox for circle
#  unscaled constant for roundRect
#  levels of hint: try row 3 then need 4,5, etc
#  turn for into foreach
#  select/kill only work on "normal" digits???
#  if size > X, then insure one slice has only 1 selected digit
#  newBoard and BRD use different format
#  always provide focus hint
#  get rid of tagFocus???
#  interface for reading puzzle from file
#  interface for restarting


package require Tk

source victory.tcl
source hints.tcl
source newBoard.tsh
source solve.tsh

set S(title) "Magic Matrix"
set S(version) "1.2"

set S(canvas,width) 800
set S(canvas,height) 800

set S(gulley) .1
set S(margins) .9
set S(button,middle) "2"
set S(button,right) "3"
if {$::tcl_platform(os) eq "Darwin" && [info tclversion] < 9.0} {
    set S(button,middle) "3"
    set S(button,right) "2"
}
set S(size) Random

set B(font,hintBox) [expr {"TkFixedFont" in [font names] ? "TkFixedFont" : "fixed"}]
set B(font,settings,title) "[font actual TkDefaultFont] -size 48 -weight bold"
set B(font,settings,heading) "[font actual TkDefaultFont] -size 24 -weight bold"

set MIDDLE_DOT "\u00B7"
set STAR " \u272a"
set ONEBAR "\u23af"
set STRIKETHROUGH "\u0336"
set SUPERPLUS "\u207A"
set SUPERMINUS "\u207B"
# set GOOD_STATE "\u2665\ufe0f "
set GOOD_STATE "\u2764\ufe0f "
set UNKNOWN_STATE "\ufffd "
set BAD_STATE "\u26d4\ufe0f "       ;# No entry
# set BAD_STATE "\u26a0\ufe0f"     ;# Warning sign
# set BAD_STATE "\u2622\ufe0f"     ;# Radioactive sign
# set VICTORY_STATE "\u2747\ufe0f"
set VICTORY_STATE ""
set FINISHED_STATE "SOLVED!"

set COLOR(bg) darkgreen
set COLOR(grid) white
set COLOR(sums,normal) gray75
set COLOR(sums,done) springgreen
set COLOR(sums,need0) cyan
set COLOR(sums,almost) royalblue1
set COLOR(sums,active) lightseagreen
set COLOR(sums,bad) red
set COLOR(small) gray25
set COLOR(hintBox) seashell2
set COLOR(title) brown1
set COLOR(game,over) gray75
set COLOR(target,highlight) yellow
set COLOR(target,highlight,blob) magenta
set COLOR(blobs) {gold cyan orange green pink sienna1 yellow red blue springgreen}

set BRD(active) 0
set BRD(move,count) 0

proc DoDisplay {} {
    global S COLOR

    wm title . $S(title)

    ::ttk::frame .buttons
    pack .buttons -side bottom -fill x

    canvas .c -width $S(canvas,width) -height $S(canvas,height) \
        -highlightthickness 0 -bd 0 -bg $COLOR(bg)
    pack .c -side top -fill both -expand 1
    bind all <Escape> DoAllForced
    bind all <F4> StartGame
    bind all <Control-Key-z> ::Undo::UndoMove
    bind all <Control-Key-f> ::Hint::BestSlice
    bind all <Key-space> ::Hint::DoIt
    DoIconPhoto
    DoButtons
}
proc DoIconPhoto {} {
    # set iname icon_numberSums.png
    # set iname icon_numberSums2.png
    # set iname out.png
    # set iname myIcon.png
    set iname myIcon_64.png

    set homeDir [file dirname [file normalize $::argv0]]
    set iname [file join $homeDir $iname]
    if {[file exists $iname]} {
        image create photo ::img::app_icon -file $iname
        wm iconphoto . -default ::img::app_icon
    }
}
proc DrawBoard {size} {
    global S B COLOR
    .c delete all
    SetUpBoardParams $size

    # Target buttons
    set radius 10  ;# KPV magic constant
    lassign [GridXY $size $size] _ grid_y1 _ _ _ _

    for {set whichSlice 0} {$whichSlice < $size} {incr whichSlice} {
        set tagBox sum_row_$whichSlice
        set tagBg bg_row_$whichSlice
        set tagText text_row_$whichSlice
        set tagHintSelected hint1_row_$whichSlice
        set tagHintUnselected hint2_row_$whichSlice
        set tagFocus focus_row_$whichSlice
        set tagArrow arrow_row_$whichSlice

        lassign [GridSumsXY row $whichSlice] x0 y0 x1 y1 x y
        set x1a [expr {$x1 - 5}]
        roundRect .c $x0 $y0 $x1 $y1 $radius -tag [list bg2 $tagBox $tagBg] -fill $COLOR(sums,normal) -outline black -width 2
        .c create text $x $y -tag [list $tagBox $tagText] -font $B(font,sums) -anchor c -text 13
        .c create text $x1a $y0 -tag [list $tagBox $tagHintUnselected] -font $B(font,hints) -anchor ne
        .c create text $x $y1 -tag [list $tagBox $tagHintSelected] -font $B(font,hints) -anchor s
        .c create text $x0 $y0 -tag [list $tagBox $tagFocus focus] -font $B(font,active) -anchor nw
        .c create line 0 $y $x0 $y -tag [list $tagArrow arrow] -arrow last \
            -fill $COLOR(bg) -width $B(arrow,width) -arrowshape $B(arrow,shape)

        .c bind $tagBox <Double-Button-1> [list DoForced row $whichSlice]
        .c bind $tagBox <Button-${S(button,right)}> [list ::Hint::Down row $whichSlice False]
        .c bind $tagBox <Control-Button-${S(button,right)}> [list ::Hint::Down row $whichSlice True]
        .c bind $tagBox <ButtonRelease-${S(button,right)}> [list ::Hint::Up row $whichSlice]
        .c bind $tagBox <Button-${S(button,middle)}> ::Hint::DoIt

        set tagBox sum_col_$whichSlice
        set tagBg bg_col_$whichSlice
        set tagText text_col_$whichSlice
        set tagHintSelected hint1_col_$whichSlice
        set tagHintUnselected hint2_col_$whichSlice
        set tagFocus focus_col_$whichSlice
        set tagArrow arrow_col_$whichSlice

        lassign [GridSumsXY column $whichSlice] x0 y0 x1 y1 x y
        set x1a [expr {$x1 - 5}]
        roundRect .c $x0 $y0 $x1 $y1 $radius -tag [list bg2 $tagBox $tagBg] -fill $COLOR(sums,normal) -outline black -width 2
        .c create text $x $y -tag [list $tagBox $tagText] -font $B(font,sums) -anchor c -text 13
        .c create text $x1a $y0 -tag [list $tagBox $tagHintUnselected] -font $B(font,hints) -anchor ne
        .c create text $x $y1 -tag [list $tagBox $tagHintSelected] -font $B(font,hints) -anchor s
        .c create text $x0 $y0 -tag [list $tagBox $tagFocus focus] -font $B(font,active) -anchor nw
        .c create line $x 10000 $x $grid_y1 -tag [list $tagArrow arrow] -arrow last \
            -fill $COLOR(bg) -width $B(arrow,width) -arrowshape $B(arrow,shape)

        .c bind $tagBox <Double-Button-1> [list DoForced col $whichSlice]
        .c bind $tagBox <Button-${S(button,right)}> [list ::Hint::Down col $whichSlice False]
        .c bind $tagBox <Control-Button-${S(button,right)}> [list ::Hint::Down col $whichSlice True]
        .c bind $tagBox <ButtonRelease-${S(button,right)}> [list ::Hint::Up col $whichSlice]
        .c bind $tagBox <Button-${S(button,middle)}> ::Hint::DoIt
    }

    # Grid
    for {set row 0} {$row < $size} {incr row} {
        for {set col 0} {$col < $size} {incr col} {
            set tagBox grid_${row}_$col
            set tagBg bg_${row}_$col
            set tagText text_${row}_$col
            set tagCircle circle_${row}_$col
            set tagSmall small_${row}_$col
            set tagBlob blob_${row}_$col
            set tagBlobText btext_${row}_$col

            lassign [GridXY $row $col] x0 y0 x1 y1 x y
            lassign [GrowBox [list $x0 $y0 $x1 $y1] -5] xx0 yy0 xx1 yy1
            set blobX1 [expr {$x0 + $B(blobSize)}]
            set blobY1 [expr {$y0 + $B(blobSize)}]
            set blobX [expr {$x0 + $B(blobSize) / 2}]
            set blobY [expr {$y0 + $B(blobSize) / 2}]

            .c create rect $x0 $y0 $x1 $y1 -tag [list bg $tagBox $tagBg] -fill $COLOR(grid) \
                -outline black -width 2
            .c create oval $xx0 $yy0 $xx1 $yy1 -tag [list bg $tagCircle] \
                -width 3 -fill {} -outline black
            .c lower $tagCircle $tagBox
            .c create text $x $y -tag [list $tagBox $tagText] -font $B(font,grid) -anchor c
            .c create text $xx1 $y1 -tag [list $tagBox $tagSmall] -font $B(font,hints) -anchor se \
                -fill $COLOR(small)
            .c lower $tagSmall $tagBox
            .c create rect $x0 $y0 $blobX1 $blobY1 -tag [list blob blobBox $tagBlob] -outline ""
            .c create text $blobX $blobY -tag [list blob blobText $tagBlobText] -font $B(font,blob)

            .c bind $tagBox <ButtonRelease-1> [list ButtonAction "select" $row $col]
            .c bind $tagBox <ButtonRelease-${S(button,right)}> [list ButtonAction "kill" $row $col]
            .c bind $tagBox <ButtonRelease-${S(button,middle)}> \
                [list ButtonAction "normal" $row $col]
        }
    }
    .c move blob 1 1

    .c create text $B(center,grid) -tag tagVictory -font $B(font,victory) -fill black \
        -anchor c -justify c
    .c move tagVictory -6 -9

    .c create text $B(center,grid) -tag tagVictory -font $B(font,victory) -fill red \
        -anchor c -justify c

    .c create text 10 $B(height) -tag hint -anchor sw -fill cyan
    .c create text $B(width2) $B(height) -tag finished -anchor s -font $B(font,state) -fill magenta
    .c create text $B(width) $B(height) -tag state -anchor se -font $B(font,state) -fill red
    .c bind state <1> ::Hint::ShowBad
    .c bind state <Double-Button-1> ::Hint::FixBad

    .c create image 10 10 -tag settings -image ::img::settings -anchor nw
    .c bind settings <1> ::Settings::Settings
    .c create image [expr {$B(width) - 10}] 10 -tag help -image ::img::help -anchor ne
    .c bind help <1> Help

    DrawFancyTitle
}
proc DrawFancyTitle {{color ""}} {
    global B COLOR S

    if {$color eq {}} { set color $COLOR(title) }
    set color1 [::tk::Darken $color 25]
    set color2 [::tk::Darken $color 50]
    set color3 $color

    .c delete a1 a2 a3

    set shadow 3
    set x $B(width2) ; set y 0
    .c create text $x $y -anchor n -font $B(font,grid) -text $S(title) -tag a1 -fill $color1
    incr x -$shadow ; incr y $shadow
    .c create text $x $y -anchor n -font $B(font,grid) -text $S(title) -tag a2 -fill $color2
    incr x -$shadow ; incr y $shadow
    .c create text $x $y -anchor n -font $B(font,grid) -text $S(title) -tag a3 -fill $color3
}
namespace eval ::Undo {
    variable undoStack {}

    "proc" Clear {} {
        variable undoStack {}
    }

    "proc" PushMoves {undoItems} {
        variable undoStack
        if {$undoItems ne {}} {
            lappend undoStack $undoItems
        }
    }

    "proc" UndoMove {} {
        variable undoStack

        if {! $::BRD(active)} return
        if {$undoStack eq {}} return

        set lastMove [lindex $undoStack end]
        set undoStack [lrange $undoStack 0 end-1]

        foreach {oldState row col} $lastMove {
            MakeMove $oldState $row $col
        }
    }

    "proc" UndoToGoodState {} {
        variable undoStack

        set count 0
        if {! $::BRD(active)} {return $count}
        while {True} {
            if {$undoStack eq {}} break
            if {[::Hint::IsOk]} break
            ::Undo::UndoMove
            incr count
        }
        return $count
    }
}
proc DoForced {sliceType whichSlice} {
    set undoItems [DoOneForced $sliceType $whichSlice]
    ::Undo::PushMoves $undoItems
}
proc DoOneForced {sliceType whichSlice} {
    global BRD
    if {! $BRD(active)} return

    set undoItems {}
    lassign $BRD($sliceType,$whichSlice,meta) target selectedTotal needed unselectedTotal
    if {$needed == 0 || $needed == $unselectedTotal} {
        set action [expr {$needed == 0 ? "kill" : "select"}]
        for {set i 0} {$i < $BRD(size)} {incr i} {
            if {$sliceType eq "row"} { set row $whichSlice ; set col $i }
            if {$sliceType eq "col"} { set col $whichSlice ; set row $i }
            if {[lindex $BRD($row,$col) 1] eq "normal"} {
                lappend undoItems [lindex $BRD($row,$col) 1] $row $col
                MakeMove $action $row $col
            }
        }
    }
    return $undoItems
}
proc DoAllForced {} {
    global BRD
    if {! $BRD(active)} {return 0}

    # Do one pass to determine who's forced then do another pass forcing just those slices

    set whoIsForced {}
    set cnt 0
    foreach sliceType {row col} {
        for {set whichSlice 0} {$whichSlice < $BRD(size)} {incr whichSlice} {
            lassign $BRD($sliceType,$whichSlice,meta) target selectedTotal needed unselectedTotal
            if {$unselectedTotal == 0} continue
            if {$needed == 0 || $needed == $unselectedTotal} {
                lappend whoIsForced $sliceType $whichSlice
                incr cnt
            }
        }
    }
    set allUndoItems {}
    foreach {sliceType whichSlice} $whoIsForced {
        set undoItems [DoOneForced $sliceType $whichSlice]
        lappend allUndoItems {*}$undoItems
    }
    ::Undo::PushMoves $allUndoItems
    return $cnt
}
proc KPVBlob {action {row ?} {col ?}} {
    global kpvBlobId kpvBlobCells

    if {$action eq "init"} {
        set kpvBlobId 0
        array unset kpvBlobCells
        set size $::BRD(size)
        for {set row 0} {$row < $size} {incr row} {
            set kpvBlobCells($row) {}
            for {set col 0} {$col < $size} {incr col} {
                set tagBox grid_${row}_$col

                .c bind $tagBox <ButtonRelease-${::S(button,middle)}> \
                    [list KPVBlob "add" $row $col]
            }
        }
        return
    }
    if {$action eq "next"} {
        incr kpvBlobId
        set kpvBlobCells($kpvBlobId) {}
        return
    }
    if {$action eq "data"} {
        set result [join $::BB "\n"]
        append result "\n\n"

        foreach id [lsort -dictionary [array names kpvBlobCells]] {
            set target 0
            foreach cell $kpvBlobCells($id) {
                lassign $cell row col
                if {"$row,$col" in [::NewBoard::GetSolution]} {
                    incr target [lindex $::BRD($row,$col) 0]
                }
            }
            set line "blob $target $kpvBlobCells($id)\n"
            append result $line
        }
        return $result
    }
    set cell [list $row $col]
    if {$cell in $kpvBlobCells($kpvBlobId)} {
        puts "KPV: duplicate cell $cell"
        return
    }
    lappend kpvBlobCells($kpvBlobId) [list $row $col]
    set tagBg bg_${row}_$col
    .c itemconfig $tagBg -fill [lindex $::COLOR(blobs) $kpvBlobId]
    if {[llength $kpvBlobCells($kpvBlobId)] == $::BRD(size)} {
        puts "KPV: blob is full-sized -- moving to next"
        incr kpvBlobId
        set kpvBlobCells($kpvBlobId) {}
    }
}
proc ButtonAction {newState row col} {
    global BRD
    focus -force .

    if {! $BRD(active)} return

    set oldState [lindex $BRD($row,$col) 1]
    ::Undo::PushMoves [list $oldState $row $col]

    MakeMove $newState $row $col
}
proc MakeMove {newState row col} {
    global BRD
    if {! $BRD(active)} return

    incr BRD(move,count)
    set oldState [ChangeGridState $row $col $newState]
    if {$oldState eq $newState} return
    ShowGridState $row $col $newState
    UpdateTargetCellColor $row $col
    ShowState
}
proc ShowState {} {
    if {[CheckForVictory]} {
        set ::BRD(active) False
        .c itemconfig state -text $::VICTORY_STATE
        ShowVictory
        return
    }
    set msg $::BAD_STATE
    if {! $::Settings::HINTS(health)} {
        set msg ""
    } elseif {! $::BRD(solvable)} {
        set msg $::UNKNOWN_STATE
    } elseif {[::Hint::IsOk]} {
        set msg $::GOOD_STATE
    }
    .c itemconfig state -text $msg
}

proc ShowVictory {} {
    ::Explode::Stop
    ::Victory::Victory
}
proc CheckForVictory {} {
    global BRD

    set isDone True
    foreach sliceType {row col} {
        if {! $isDone} break
        for {set whichSlice 0} {$whichSlice < $BRD(size)} {incr whichSlice} {
            lassign $BRD($sliceType,$whichSlice,meta) _ _ needed unselectedTotal
            if {$needed != 0 || $unselectedTotal != 0} {
                set isDone False
                break
            }
        }
    }
    return $isDone

}
proc UpdateTargetCellColor {row col} {
    global BRD COLOR

    foreach sliceType {row col} whichSlice [list $row $col] {
        lassign $BRD($sliceType,$whichSlice,meta) _ _ needed unselectedTotal
        set color $COLOR(sums,normal)
        if {$needed < 0} {
            set color $COLOR(sums,bad)
        } elseif {$needed == 0} {
            if {$unselectedTotal == 0} {
                set color $COLOR(sums,done)
            } else {
                if {$::Settings::HINTS(coloring)} {
                    set color $COLOR(sums,need0)
                }
            }
        } elseif {$needed == $unselectedTotal} {
            if {$::Settings::HINTS(coloring)} {
                set color $COLOR(sums,almost)
            }
        } elseif {! [::Hint::IsNullHint $sliceType $whichSlice]} {
            if {$::Settings::HINTS(coloring)} {
                set color $COLOR(sums,active)
            }
        }

        set tagBg bg_${sliceType}_$whichSlice
        .c itemconfig $tagBg -fill $color
    }
}

proc ShowGridState {row col newState} {
    .c lower cross_${row}_$col
    .c lower circle_${row}_$col
    .c lower small_${row}_$col
    .c raise text_${row}_$col

    if {$newState eq "kill"} {
        .c lower text_${row}_$col
        .c raise small_${row}_$col
        ::Explode::Implode $row $col
    } elseif {$newState eq "select"} {
        ::Explode::Explode $row $col
    } elseif {$newState eq "normal"} {
        .c raise text_${row}_$col
        .c lower small_${row}_$col
        ::Explode::Implode $row $col
    }

}
proc ChangeGridState {row col newState} {
    global BRD

    set oldState [lindex $BRD($row,$col) 1]
    lset BRD($row,$col) 1 $newState

    _ComputeHint row $row
    _ComputeHint col $col
    return $oldState
}

proc SetUpBoardParams {size} {
    global S B

    if {[winfo width .c] == 0} update
    set width [winfo width .c]
    set height [winfo height .c]
    set B(width) $width
    set B(width2) [expr {$width / 2}]
    set B(height) $height
    set B(height2) [expr {$height / 2}]

    set n [expr {$size + 1 + $S(gulley) + 2 * $S(margins)}]
    set cellWidth [expr {$width / $n}]
    set cellHeight [expr {$height / $n}]

    set B(size) $size
    set B(cellSize) [expr {min($cellWidth, $cellHeight)}]
    set B(left,sums) [expr {$B(cellSize) * $S(margins)}]
    set B(left,grid) [expr {$B(left,sums) + $B(cellSize) + $B(cellSize) * $S(gulley)}]
    set B(right,grid) [expr {$B(left,grid) + $size * $B(cellSize)}]

    set gridWidth [expr {$B(right,grid) - $B(left,sums)}]
    set mid [expr {($B(left,sums) + $B(right,grid)) / 2}]
    set B(center,grid) [list $mid $mid]

    set B(cellSize3) [expr {$B(cellSize) / 3}]
    set cellSize5 [expr {$B(cellSize) / 5}]
    set B(arrow,width) $B(cellSize3)
    set B(arrow,shape) [list $B(cellSize3) $B(cellSize3) $B(cellSize3)]
    set B(arrow,shape) [list $B(cellSize3) $B(cellSize3) $cellSize5]

    set B(blobSize) [expr {$B(cellSize3) - 5}]

    set B(font,grid) [FitFont "88" $B(cellSize)]
    set B(font,sums) [FitFont "888" $B(cellSize)]
    set B(font,hints) [FitFont "12 34 56 78" $B(cellSize)]
    set B(font,active) [FitFont "34 56 78" $B(cellSize)]
    set B(font,victory) [FitFont "Solved!" [expr {$B(width) - $S(margins)}]]
    set B(font,state) [FitFont "888" $B(cellSize) Times]
    set B(font,blob) [FitFont "88" $B(blobSize)]

}
proc GridSumsXY {sliceType whichSlice} {
    global B

    if {$sliceType eq "row"} {
        set x0 $B(left,sums)
        set y0 [expr {$B(left,grid) + $whichSlice * $B(cellSize)}]
    } else {
        set x0 [expr {$B(left,grid) + $whichSlice * $B(cellSize)}]
        set y0 $B(left,sums)
    }

    set x1 [expr {$x0 + $B(cellSize)}]
    set y1 [expr {$y0 + $B(cellSize)}]

    set padding 5 ;# KPV
    set x0 [expr {$x0 + $padding}]
    set y0 [expr {$y0 + $padding}]
    set x1 [expr {$x1 - $padding}]
    set y1 [expr {$y1 - $padding}]

    set x [expr {($x0 + $x1) / 2}]
    set y [expr {($y0 + $y1) / 2}]
    return [list $x0 $y0 $x1 $y1 $x $y]
}
proc GridXY {row col} {
    global B

    set x0 [expr {$B(left,grid) + $col * $B(cellSize)}]
    set y0 [expr {$B(left,grid) + $row * $B(cellSize)}]
    set x1 [expr {$x0 + $B(cellSize)}]
    set y1 [expr {$y0 + $B(cellSize)}]
    set x [expr {($x0 + $x1) / 2}]
    set y [expr {($y0 + $y1) / 2}]
    return [list $x0 $y0 $x1 $y1 $x $y]
}

proc FitFont {text space {baseFont TkDefaultFont}} {
    # Binary search to find font size to best fit text into space
    set size 512
    set delta 256

    while {True} {
        set font [concat [font actual $baseFont] -size $size -weight bold]
        set width [font measure $font $text]

        if {$delta == 1 && $width < $space} break

        if {$width < $space} {
            incr size $delta
        } else {
            incr size -$delta
        }
        set delta [expr {$delta / 2}]
        if {$delta == 0} { set delta 1}
    }
    return [font actual $font]
}
proc HorizontalBar {font line1} {
    # The horizontal bar character is wider than other characters even in a fixed font

    set points [font measure $font $line1]
    set oneBarWidth [font measure $font $::ONEBAR]
    set count [expr {int($points / $oneBarWidth)}]
    incr count
    set bar [string repeat $::ONEBAR $count]
    return $bar
}


proc roundRect { w x0 y0 x3 y3 radius args } {
    set r [winfo pixels $w $radius]
    set d [expr { 2 * $r }]

    # Make sure that the radius of the curve is less than 3/8
    # size of the box!

    set maxr 0.75

    if { $d > $maxr * ( $x3 - $x0 ) } {
        set d [expr { $maxr * ( $x3 - $x0 ) }]
    }
    if { $d > $maxr * ( $y3 - $y0 ) } {
        set d [expr { $maxr * ( $y3 - $y0 ) }]
    }

    set x1 [expr { $x0 + $d }]
    set x2 [expr { $x3 - $d }]
    set y1 [expr { $y0 + $d }]
    set y2 [expr { $y3 - $d }]

    set cmd [list $w create polygon]
    lappend cmd $x0 $y0 $x1 $y0 $x2 $y0
    lappend cmd $x3 $y0 $x3 $y1 $x3 $y2
    lappend cmd $x3 $y3 $x2 $y3 $x1 $y3
    lappend cmd $x0 $y3 $x0 $y2 $x0 $y1
    lappend cmd -smooth 1
    return [eval $cmd $args]
}
proc FillInBlobs {} {
    global BB BRD

    set colors $::COLOR(blobs)
    foreach line $BB {
        if {! [string match blob* $line]} continue
        set cells [lassign $line _ id target]
        set BRD(blob,$id) $target
        set BRD(blob,$id,cells) $cells
        set BRD(blob,$id,color) [lindex $colors $id]
    }
    set BRD(hasBlobs) [info exists BRD(blob,0)]
}
proc ColorizeBlobs {} {
    global BRD

    if {! [info exists BRD(blob,0)]} return

    for {set id 0} {$id < $BRD(size)} {incr id} {
        lassign [lindex $BRD(blob,$id,cells) 0] row col
        set tagBlob blob_${row}_$col
        set tagBlobText btext_${row}_$col
        .c itemconfig $tagBlob -fill $::COLOR(grid) -outline black
        .c itemconfig $tagBlobText -text $BRD(blob,$id)

        foreach cell $BRD(blob,$id,cells) {
            lassign $cell row col
            set tagBg bg_${row}_$col
            .c itemconfig $tagBg -fill $BRD(blob,$id,color)
        }
    }
}
proc FillInBoard {size} {
    # TODO: change BB
    global BB BRD

    unset -nocomplain BRD

    set BRD(size) $size

    # Grid
    for {set row 0} {$row < $size} {incr row} {
        for {set col 0} {$col < $size} {incr col} {
            set tagText text_${row}_$col
            set tagSmall small_${row}_$col
            set value [lindex $BB $row+1 $col+1]
            set BRD($row,$col) [list $value normal]

            .c itemconfig $tagText -text $value
            .c itemconfig $tagSmall -text $value
        }
    }

    # Sums
    for {set whichSlice 0} {$whichSlice < $size} {incr whichSlice} {
        set tagText text_col_$whichSlice
        set BRD(col,$whichSlice) [lindex $BB 0 $whichSlice+1]
        .c itemconfig $tagText -text $BRD(col,$whichSlice)
        _ComputeHint col $whichSlice

        set tagText text_row_$whichSlice
        set BRD(row,$whichSlice) [lindex $BB $whichSlice+1 0]
        .c itemconfig $tagText -text $BRD(row,$whichSlice)
        _ComputeHint row $whichSlice
    }

}
proc _ComputeHint {sliceType whichSlice} {
    global BRD

    set selectedTotal 0
    set unselectedTotal 0

    for {set index 0} {$index < $BRD(size)} {incr index} {
        set cell [expr {$sliceType eq "row" ? $BRD($whichSlice,$index) : $BRD($index,$whichSlice)}]
        lassign $cell value state
        if {$state eq "normal"} {
            incr unselectedTotal $value
        } elseif {$state eq "select"} {
            incr selectedTotal $value
        }

    }
    set needed [expr {$BRD($sliceType,$whichSlice) - $selectedTotal}]
    set excess [expr {$unselectedTotal - $needed}]
    set BRD($sliceType,$whichSlice,meta) [list \
                                        $BRD($sliceType,$whichSlice) \
                                        $selectedTotal $needed $unselectedTotal]

    lassign [::Solve::SingleSlice BRD $sliceType $whichSlice] keep delete sets

    set BRD($sliceType,$whichSlice,sets) $sets
    set BRD($sliceType,$whichSlice,hint) [join [PrettyKeepDelete $BRD(size) $keep $delete] " "]

    HighlightHints $sliceType $whichSlice $needed $excess
}
proc HighlightHints {sliceType whichSlice needed excess} {
    set tagText text_${sliceType}_$whichSlice
    set tagHintSelected hint1_${sliceType}_$whichSlice
    set tagHintUnselected hint2_${sliceType}_$whichSlice

    set hintSelected $needed
    set hintUnselected $excess
    if {! $::Settings::HINTS(partial)} {
        .c itemconfig $tagHintSelected -text ""
        .c itemconfig $tagHintUnselected -text ""
        if {$::Settings::HINTS(countdown)} {
            CounterAnimation $tagText $hintSelected
        }
    } else {
        if {$::Settings::HINTS(countdown)} {
            .c itemconfig $tagHintSelected -text ""
            CounterAnimation $tagText $hintSelected
            CounterAnimation $tagHintUnselected $hintUnselected
        } else {
            CounterAnimation $tagHintSelected $hintSelected
            CounterAnimation $tagHintUnselected $hintUnselected
        }
    }
    .c itemconfig focus -text ""
    .c itemconfig arrow -fill $::COLOR(bg)
}
proc CounterAnimation {tag last} {
    global AID

    set delay 30
    if {[info exists AID(counter,$tag)]} {
        after cancel $AID(counter,$tag)
    }

    set first [.c itemcget $tag -text]
    if {$first eq {}} {
        .c itemconfig $tag -text $last
        return
    }

    set delta [expr {$first < $last ? 1 : -1}]
    set values {}
    for {set i $first} {$i != $last + $delta} {incr i $delta} {
        lappend values $i
    }
    set AID(counter,$tag) [after $delay [list _CounterAnimation $tag $values $delay]]
}
proc _CounterAnimation {tag values delay} {
    global AID
    if {$values eq {}} { array unset AID counter,$tag ; return }

    set values [lassign $values first]
    .c itemconfig $tag -text $first
    set AID(counter,$tag) [after $delay [list _CounterAnimation $tag $values $delay]]
}
proc IntersectionSets {set1 otherSets} {
    set result {}
    foreach item $set1 {
        set found True
        foreach setN $otherSets {
            if {$item ni $setN} {
                set found False
                break
            }
        }
        if {$found} {
            lappend result $item
        }
    }
    return $result
}
proc SubtractSets {set1 otherSets} {
    set result {}
    foreach item $set1 {
        set found False
        foreach setN $otherSets {
            if {$item in $setN} {
                set found True
                break
            }
        }
        if {! $found} {
            lappend result $item
        }
    }
    return $result
}

proc PrettyKeepDelete {size keep delete} {
    set result [string repeat "$::MIDDLE_DOT " $size]
    foreach item $keep {
        lassign $item value index
        lset result $index "$value"
    }

    foreach item $delete {
        lassign $item value index
        lset result $index "$value$::STRIKETHROUGH"
    }

    return $result
}
proc NumberToCircle {number} {
    if {$number == 0} {
        set base 0x24EA
    } elseif {$number <= 20} {
        set base [expr {0x2460 - 1}]
    } elseif {$number <= 35} {
        set base [expr {0x3251 - 21}]
    } elseif {$number <= 50} {
        set base [expr {0x32b1 - 36}]
    } else {
        error "cannot create circle number for $number"
    }
    set codePoint [expr {$base + $number}]
    set circle [format %c $codePoint]
    return $circle
}


proc GrowBox {xy delta} {
    lassign $xy x0 y0 x1 y1
    set x0 [expr {$x0 - $delta}]
    set y0 [expr {$y0 - $delta}]
    set x1 [expr {$x1 + $delta}]
    set y1 [expr {$y1 + $delta}]

    return [list $x0 $y0 $x1 $y1]
}

proc RandomTriangular {low high mode} {
    # Returns an random integer between [low, high) with triangular distribution with mode at $mode

    # # Insure mode within our range
    # set mode [expr {min($high, max($mode, $low))}]

    set u [expr {rand()}]
    set F [expr {double($mode - $low) / ($high - $low)}]

    if {$u <= $F} {
        set x [expr {$low + sqrt($u * ($high - $low) * ($mode - $low))}]
    } else {
        set x [expr {$high - sqrt((1 - $u) * ($high - $low) * ($high - $mode))}]
    }

    set x [expr {int($x)}]
    return $x
}

proc StartGame {{sizeOverride ?} {seed ?} {fname ?}} {
    global S BB BRD

    if {$BRD(active) && $BRD(move,count) > 0} {
        set yesno [tk_messageBox -icon question -type okcancel -parent . \
                       -message "Game still active, really quit?"]
        if {$yesno ne "ok"} return
    }
    ::Victory::Stop all
    ::Explode::Stop
    if {$fname ne "?"} {
        set n [::NewBoard::FromFile $fname]
        if {! $n} {
            set n [tk_messageBox -icon warning -type yesno \
                       -message "Cannot find a solution to this puzzle\n\nPlay anyway?"]
            if {$n eq "no"} return
        }
    } else {
        set size [::Settings::GetBoardSize $sizeOverride]
        set defaultBias 8
        ::NewBoard::Create $size $defaultBias $seed
    }

    set BB [::NewBoard::GetBoard]

    Restart
}
proc Restart {} {
    global BRD BB

    # TODO: remove BB as global variable

    set size [expr {[llength [lindex $BB 0]] - 1}]
    DrawBoard $size
    FillInBoard $size
    FillInBlobs
    ColorizeBlobs
    for {set whichSlice 0} {$whichSlice < $size} {incr whichSlice} {
        UpdateTargetCellColor $whichSlice $whichSlice
    }

    set BRD(active) True
    set BRD(move,count) 0
    set BRD(solvable) [::Solve::IsSolvable BRD]

    ::Undo::Clear
    .c itemconfig tagVictory -text ""
    ShowState
    ::Settings::ShowSolution 0
}

################################################################
image create photo ::img::hint -data {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAAEEfUpiAAABcElEQVRYhe1VMU7FMAx9rf5MByYqcQMO
    gFQWunFZRk5ARwZAQpyg25coI0IyC4nSxHbttojlvymNnecX145BRCAifDxefBERKiLCNLSEX9TIkRyh
    eCRFDQDT0FLgKTiKjciRhg5ourEqZUiUTTdW+WkAOKSbT3Qf132uQUJkyEWGEDVnTPdst8hvUIRgcBkW
    s1uEuCkjm4c+2WPzwN0q1xZQaNQOc/ZaM1pIFvO8hP1zwDlp+wfOEQC+r94l0wxiDs6bs0r7DlD7YRra
    WwDHphtfJB9XErkcuAqJs7kLSa3ENTgRZARSD2g+hQKNxFRInsMigeUqAZvbWSR4fn2bffc316yf2M7H
    6TMapLdAJZBgaThPDk0CrONijZilF3F1YKsQsY73DK7xbX4LtuIkQBTgaSUL3EW4pwiNx/oO3AF42DOw
    S0AixOxszZ6rCK2knl/3710gjkMJ1jn7ZwLyOc1Bmt0c3OM4IJ33Adrcl/ADyZ3SsEDisa4AAAAASUVO
    RK5CYII=}
image create photo ::img::undo -data {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAAEEfUpiAAAChUlEQVRYhb1XS24UMRSsGibjDr8N3ANO
    kNkEcQ8Q5+AAOQicgE2Q0ETiAuyBJQs2oAhN90ygWLTtsd12t5uJKKmlTLddr/x+fqEkRJAEbYwA9I8k
    3FlAdqXotpCUNgZMOWj3Oj7Crmgc+cJ+3JLUway14FcGT2/kqknUWoPrLlZBkk5wVmb7vlGzCijOWg7O
    kcKphledYAkAuGr06CGjRZLoPaONyfOftd5TMie9x/1jQ7J0dCUNi+DvjqTcE4t0wgItXHc9c84PlqGR
    1OXV5yWApN68Xsmc9D+nNgPoQ+XiVgsn3xM4646kOe/Q7fObUz94J3nGgwdPJbUD64naZbrAEVUfpxCF
    dntpTJS66ZqJMH4H8Li0OVQ5WQ9TWORelvK2imDO5oiA5MXchAJsGJ3VKEkKStIw+15Ya5nrLiIaJNIU
    nCHbArl03YLr7vBxXa7igdKwD6FvYOpfxz066N/SxijqWQFZsXeVvg/yYG4xZTOxRJJTl43C6DECR0ti
    MYy1eTE7D9JEGmvreWVpKs/pBySvJT2o3lCBKheEJyLZ5Jr1vyKbRqFhZ9xedreOgQeiISPIpObc1/cP
    crRWbgA8l/SxRkB0seYMh+j2wFTK7PbA05c7fP02XJgr0CXJawD3xww71IShWQFf3g7v01cXN4fGn7sV
    azxw+qyb9IBZAT/flQ/y5MUOnz77KXl4r5P8BeAuAPz+YLCwaRrMO9mRJdi/AhBdCLkDuYaSG23uBWRe
    XW0VSNohGA3TyyrFaBlKootXado7FlWNKJgc/f8i/1VAgD8TPSCLseqqFkCyBYDtpcHY1DrJEwwso/fp
    bSM17N/XhtR6YN7cmSDXCY8ez4/FX4gku4UNWl/cAAAAAElFTkSuQmCC}
image create photo ::img::play -data {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAAEEfUpiAAADh0lEQVRYha1XQWsTQRT+JuZQcKqimCq2
    B7VietJC1kMtxLIXMYik9ZqD3oX+jZ4rngQPQvUmVQK1UEoOHqSF0IN1IaGnlKZgQegrCNWOh+ybzOxM
    tmn1gyWbmTfvfW/mzfcSKKUAQAFQSikIAIqIYELFgyp+734hIiX0qFICgMeHsVYRkcrGg3aUYrmqiEg7
    V0qBH+2zVKlht7WF9dVn1movcTyZ6nwurkLEqWocHBzogY1CAQCwySyT8ZVS3TSYZD1qWkbetDhMo9VG
    BgCklChVavAh4xvc29uDlBIA7BBSStSjJi49f+r3UCxXdf6al8mYMyEiRWGg6lFTCQCbRDTmZRij0Wrj
    7u2bwjeXBTDG/Ey+SZgnYDrWORARiAhSShSm3uDw8DCNlIZVDMm9rn0ogYjQaLVxa/iKN7WsOVB9W4SU
    EvlgPi47Ix2uMAAb2/u4s74OALYDTgXo7gkA1KMm5MoaKAw6n8Y+ZQA89OXGe0JEqH5c7CyKz1dKqQM4
    9W7Ct/MmGq12x4EQItWQ77wPWSGEeyUN/P5zBCGE6uVEX5fC1Btr4xgXzp9LIwctTQwfGyllz/GMuSgt
    Fd9iAHYpA8DVkXFvKknMzc0BSCllLuO+UjApMfLBfH+5wJA8AGqi9M5Sc1PdfeOWJBERhDij3625MACF
    AX4+KFhsHVX8/P6R90IxvrXJuUyYmZlxDEuVGi4OTWFhYaHjbGUNG9v7uB9Flp0upCRlKSUGzo7gx+73
    1FPwtgZzrLm9613I89lel4RvKGuCtTgMjteD424pO+tLD/pFmm70QtZMlVkxfAfD40m7Rqudqjs9CSQD
    cH/dbW05p+97Z32uR00AOPFuesuwV9mlodFqYzw/6vgBgMnJSSwtLTmdajw/6ra1JBnT0UlJOXLgOWbv
    DyQzcKlSQ7FcRbFc1W2DtfS0cKQkieXlZaseGEPDNzB27yVevf7al+j3Ay+B6elpJzgjd+06Lg8//i/B
    GZbGm8/s7KzuAflgvtMvJia8tvWo2fETBorCoNs7wkB9yeedGGzfU4wZvq322epbEAbOnNkFeC3be2/B
    ccGSpEybX0dHGMh0T9YX3IQjRP3otylW0doLa37gU80imMvlUn06O+CT28HBQezs7FhZpGnDifTC/OP6
    r4+vOK2/rEZBchFmYxInaiBmq03WQ9rOyJU111fa7/vjSJxqYQJ/AUeA744T2b/XAAAAAElFTkSuQmCC}
image create photo ::img::settings -data {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAAEEfUpiAAAEA0lEQVRYha1Wz28bRRh9602L1YXmQKQm
    lVrfUMFC5MKhh152BRx7KSdulZB8ssD/AAfOa2i55JReyM09o4pupVZqLyFSpGapRVRVNjQJdRAK7Dhu
    afI4zM56ZvaHS8UnWV6v55v35n2/BiRBEn5IkoRDEvFQEKnVgi4IAJsDFwDyKxwye9ZcxoIYCwZdEBQJ
    v793yK96L0iRSLitQUKKhH6YctB5UCTM8QIAjAXjfUlnuXGEn5+6+PRi3akp9J3JnMHmxcv0YRZEtiB9
    ueuH3NDfGd7HSSJPUCUeADQXgHgfaJ73JMl2z4P6bvc8xPvTdw5JxkMBXfHlxhGaC8DahqtxSJXTn6dC
    pSLp+IDkkNegSgf7o4L2+0g6FX2yUARdMB4KxkOZB0EXVHRGY/m/WnO/P6ZKNTsSWapsDaYfRV39zo5E
    wvFD7kYdLMZDYQjQ7nm4+uEkC87qeh3XrwgjWGsbLuYA7ABYBKbOVdZckN9qrVEUQReMWqJwI92x3fMQ
    deAYGvghyckkO6Ouh54EW4OEa/cOma+YIhvLJFWJWbSkcgMVqoxukZUliF39MxNJIQZd9HXhdEFVMhUe
    4cFjcP6EjLOqNRV39VtF6IubHn78Uh5L1yCrSxv5zRNAY376bnPg4rNLdQeAUQv95nkv5wzknVfX60vq
    v2yDqIN3dad2z8PmwMXmwEWw4hkbRh3sZRuoCvt1TxBjecbtkWvUwaXGP9nzcuMIevfOGJw7PaX53d06
    bFNC2rVQKxLtdkvAtutXROasm52JxFg6BysePlh6id2/a3iW1PDD5wInXVnCKgLGBkEXjDqA0sE2hb62
    4WJ1vd5Xos+lzhdexTnelyJexeQCUJ9qEHXQ/+Sa2Y100YIVzwjl6romsl1AfshFfRjoxeSHfGQXljEV
    i8pWP5KdbIaI/8XsipxFotKqBlNZH7HbpRoZRev9kPNV/WiuiFTQBb++LJM3HoJpQLejDt5Ra+yKKFMp
    agncHzr46JtTPGZeodxUSWWEak22zQJ+723A0SD0dWknQoqR64eKxCNA1oVOYhawvqZonQa+pHez0iTM
    KhuAag/6ptsj12hat1sCTgnw04Mabv1ysjBBHZKlWR218sCqwPV2q0zJq19BbL8cAT9kLu5lctv3Hdu2
    n7l48qeL3/6q5UjYnTjtiWYVvEqcZ9nBc1NlG/iPQ2BP41YZAvs2ByDrqbYSJHDjp2kIdODkOXD5RkkI
    XjcJATOuRWQBKfXBxMHNh2+UJ6ENDMicKAMuM1vukh7Q12dCaSMqAn+44+L9s0czge88qeHMW8e5dUWN
    qHQGfPwtORwZ1+XFqllg30HV6NSv00Uz4bWHkQ1eNoyq9pl9vy+x/3Mc/wsSUe2xpmtt4QAAAABJRU5E
    rkJggg==}
image create photo ::img::help -data {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAAEEfUpiAAACEklEQVRYhc1WPU4CQRh9u643MDExHAAS
    JJYWxgZsPMBC5QVMuIDFAt6Ayt6G9QB2VFhYGkKyF6AxgQRqMZ+FzjIzO7+LEl+38/Pe9337zZsBEYGI
    UI17GyICiAitwYQWqzW1BhMKa+3+BhzCLE0ifiAgIggD1bhHlXoTADCfjRG0BhNxSTXu0WK1psVqTdW4
    RzlHrd3Pt7LtWZoEARHh6v5FpOHDkgdG3YYYlZOECZFqN88QAgCbHHUbeQxsTKiMjPlsLGbBM2jTlBFm
    aRLoJrM0CSKmVak30RlOBX3govg/ge+0Taz8t1BpYJs+w6jbEJS36tj+CVWh2WYGmYQRaaskl1MHLYFK
    0YvAFdYiqlAoooxSv1GFWrt/B2CZpcmDbk2BwKRujcBWBz73AoGqmVgvqDqRkYS6zSZU6s082t37wGQZ
    NsxnY0SqieuzI9xcnuTfprZWpvD8ttjfWdidIEuTgDWIDwRnV4E3FJO5GDvRpi4QMBKg5FmQSXTw8gMZ
    NnKTkA42QypM+limS0BWSy17TnUBORmii7CqNW3HVxVIfg5+O2sVeF6mlz8NyorH58d4en332sNXQnCC
    Mpn7iss60c/V64TDgwCPt6faeVcL5xECWLou/vgkdIbTUkLaAEyPjn1A6IEy10oZFJqQN4e/DkL2Ai8j
    kh8bOuh6RGVE/8uKTYH4BLTzZeQTkA6u1/EXzQl821A0/wwAAAAASUVORK5CYII=}
image create photo ::img::solve -data {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAIBElEQVR42r2XC1CU1xWAz7/vZXfZZR/s
    wsIGZGFFIUGIlGC0AoJS2zoSjSa2nUnFRxqjNU1ixykhcTptOg2RJJJqnUQtptpofaaZRAM6vqoBJBQh
    Im82LPvgsbuwy+6//6PnN8YBitpSxjNz9r97H//57r3nnnN/Av4PyczMjBgdHYXGxsahqb6DmMogXaQu
    jKGZ/XK5fJnH47H5fD5zKBSiubYDDWVL4pSWDYN+R/hgWFe/zddxs8/fXt/rbb96Ms9l/+8AqoAHecBM
    rI5C0ev10W0DbaqRvpHPBSDgG41GIEmysK+v77P095TCjLwUW1x4orSbaqQ7qDpaIASQCIUisUDEBryj
    tUKn5kPWJT3092U91OQA1bAWWFiFpR8hRJCryp6XLWtubQoLDAdTRFF8E2GkzZ7BwM+NbmP0pk2bQCaT
    ndi8efNyrm/STiiWGuEZHgFkyA5dBAUSiQ5S1WmQLNWBSCISQmz/3Jq+tv5VBwtvWScDSEeAVDR+gPtr
    SNDHMZGhHK926DHGy/KZTri56vtrbiZbkufm5ub+Pi4uDtxuN9Xb2zsjPz/feq9tS/oVJEfMgZej8mCN
    Okwt0ven1DVcbnnynj6Q+IHCOOL2/yLYDU/4rtD/mEEmV8vFcli3bl3E0qVLYWRkRNDV1XU0MTFRoVKp
    oKGhoTQnJ2fHg/wn+2/wgnER79318gq64szrRf8BkFYl0ZIe9o1gNz975JTwD65r3otykSKi7I9lgAag
    ra0tKj4+nkZfgOvXr29Rq9U/TkhIgKampltZWVmWBwFk/E4iWrBh5nCM2ExUnf/8+XEA2ddkKySM8r2e
    v4xWtO0d2m+KNtEms4nXsq3l7DbttopH9Y+61Ha1Az1ehDOn8QQkXLp0aU9/fz9htVqh6vLZtMaapob7
    ARQcityQWZDypxvBal/PR7yMuwC5X4W/ZhLOKg2OUEXnX7112nFxRJv1VFb0wIsDf26hWuZiF/ak8WRR
    TlROW21trdn7rcDW7VvKCSWT+uzG1fDJqU/e6Tjb+8vJDGftU/AVGsn21MctpS3UZZ7tOLu9fgu8eRvg
    6X8lbFBJI3dHC8x/fT2+cg1Xh3stXL16tea66npeibdkt1lkvrmev76iUFNYe/jwYVVJSYkqLy/PHxGv
    KDxVdeLlFYWrwd7hcLXeaouxdljJscbT90kzjRbtO2qDPKvH/zXpPAXbSRe83boTWGJnw1YlX830+AhP
    +Ggw8NMdCYcPfjfw2LFjUkJNxIqNYsN8w/zWXbt26cvKyqiVK1dCdXW1xeFweIqLi8Xl5eVHkpOTpXgK
    4OiJI0/1dFiPceMtu4VPhOskLxkTtUV+Yojn+tp9zX0FXuwsh5rvbBAft7+bf4n/8RmC4IEyaHxhR9Kh
    98fSHz9+XKHVauUXLlyAoaEhQUVFhUGj0YziSQg/cOBA7IIFC1wor7a2ti7euHEjfFZ/utq7tP20Kla6
    Rh4lzOALgPB9M9rqrad+G3RSB6172XEBjjjSuMdYL/i0pV5wRhbFWhxSj67Y5ur99PgPmu92/F7u48ov
    z9WFLV68GAwGQ3hlZaVi4cKFATyKyZ32DpEl35xT57q6Nj7PACHDMPBkNISJxCzdyaslu9i3fbbA0Z79
    o9RkvnHbB7ZWPlsosgQqXdpWTU+gFUgvz+YbIGt4lOgWQQv7+c5wt6NqVEEIeIr0zHRFu6M9aSTMq+Wb
    +GYX06+h2BAhYYWgl+khktbDYJ33ots1tCVEk1/1HPKw9zsVd0/BwpdmadQxirUak2q5zELMoUWU2EN5
    oMffC34yCFJGAsEhFghKCDKxEoiQEEiGohgn3xHsYL4R2EX0jarm7KL8FdDUfONmzZe1yQ+KCeMAxkrq
    c1FSd5Lvh6FHiNf8hlCiYiCsydQV9aFwQOCz1br45BDjnp2Y4q07X8/qNJF+zIYzFQoFD9PyHgxGPJPJ
    BBgfsm022z+nBHBbTmNGlEETlmai+oCE38ASKCf4IGRp0GAgIrjs2NLSEqZUKvWYEcMHBwc3i0SiNC5U
    o9Pu7ezsXD91gGrQ4O8+VEyo0Au5UDymVYKqSklJ4eMzHk+BBMUUCAQysbyhoKAABgYGPN3d3dFOp9M/
    NYDxMJEI4JxQK+fxeAqLxSLD2ccMDw8bMS3L0WgZ5grZ7Nmz4cqVKz/DMF2J94sc7H8ZrcViprVjpvX9
    bwD3FpVQKJTGxsbqMT9EIcgjeEV7Gss5XOJCnziHOSIXvoCjaGkeqhrHGHEy/dMFwIlGjKLT6eIRIJGm
    aQsu/6/T0tK4NqZ5XvNzZBH5FlrS4X8aV2AJrsAX0wnAuwOhiIiISEKImZglX0HHjE5NTYWrcPUouZas
    YWPYN9E4F+bPIcC+6QTghHNGLUIY0A/S0BmXoy6bM2cOWHutXe4M9wxyE1mK7vwGLIJxgWm6ADgR3VkJ
    C+p8dMpSDNt8jA/Q5exaRLrJqskGTScAJ1JUA8aCJ/H5CmoqxgvARPURbs1PHgYAJwrURIFA8DzLssW4
    Ctz90Y8rEs0wjOdhAHASgVqAcWIvBigFfsAABqiNCLTnYQFw7zWhfoAQeXhx5SLjNQTIelgAnHDH8xnU
    SqlUSlAUxeK2PIaBqvF+ALxJlJigY4Ud85yo3IVGiitwjTsZ+AHjxBtVjt1ub54IwBkRw7cJRnKnzKng
    ThtMeCkzoTxW6UnqZuEKmNEBz+BJcOM2jOszdkb8SXTiKtxr9swESHYS0LHtd8f/GyqrkhEkTQgNAAAA
    AElFTkSuQmCC
}
image create photo ::img::quickpass -data {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAMAAABEpIrGAAADAFBMVEVHcEyXewCUhQLZvQPo1gCKdBGV
    jBCjlgygliGZlgCYgyeAbgl4Zw7iyQ27nwaFggDBqwCQfwDhyQCLggDZxgCgiACUhQCdnQC2swCvrwDE
    uwDjyAyahgDozQCzoACnjQa5pACqlQWojACSfAC6nADewS+lkDqSgjyZeQDq0xLbvhbNvgCukgCIchXG
    tQDw2wCOjwDMugCMdxKUlADPsRndzgDPtQDUuRnMrgDWtQCpkjX/////1ADoeQD/5gD//vT0hQD/xwDr
    fADTZgD/1wD/ygD/vQD/nQD//vH/rQDpegD/ngD/ogD3hgD9jAD//frjdAD/6gH/3QD/83H/kwD/3wDz
    gwD/+9T7jQDufwD/7gD/zQD/+cqySAD+jgDbbgL/+bT/0QD/qgD/vAD/2QD/+sT/6Tj//Nz/+8///OD/
    pQD//ej/81//7y7+9IT/95fxgQD/wwD/yAD///7/4A//4ALLXwD97gH/sQDJXQD76NPDWAD99gD/xgC/
    VgC8UQD//e3/6xH+7Bz/7z7/9o//9H7/1pv/96b/8Wn/9Yj/+r//vwD+tlj/nQz/4bjwhArdcQDneAD8
    6QD/4wD+8Uf/8Ez/+Kv/7db/96D/mQD/6gv/mAD/syLslAD/2X7/4Ar/pin4smLztnL0unrlsQD73gD+
    +fX/8gD/1Eb3iQD/5aT/++/54gDwyQD35mTw0gDWmAD21QDyvQDJfQC/aADQZQDnwQDoiAD57Jf464bl
    tgD883b/8VP/7jT/8Vj6qk366gD56l/62LP9lxv/+bnofQrroFPkfhXynwD5xwD90AD/+LD1yQD/50rr
    owDdewDajwD8nADzzqr4uwD/9tr/8Hn/9tn/5GfingD/1SToqGz/7rz/7rr//vXfl1bup1n/4Yv0wYz/
    xGHks4zLbQD03cj2liLcdxX/3CjUfAD353n/xAj/5YPioWfqwQDXawDwokz/9dj/rC7xxZfswp/GYgD8
    99L463S1SwDCcQDqyQD24WS5XADObQD5zQDZ2AQe7scDAAABAHRSTlMAXyrw9C0OCAswZE9J9NJOy3rv
    SOtuD2K5U1/3avfAuAG6WTdn9VQyT/nw0s5yzfhx03d26Orm6+bxYv//////////////////////////
    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////wAurr
    2AAAAylJREFUOMtjYEACHOpqXFZq6hwMWAEbl6Lq7507duz8rSrPhamG3cj8e0y2hz0YfHtlosuOKs/K
    dzAhNSM92wMEGjLDU9fxsSLLc/Puzm8Hq2hoaMgGyh+ZlqfFgySvmROc1zLjdFdMeHp6enhGV0J7fmew
    NFwFJ2/ulH0drZ0gQ8LDY7oSps1oaQ3OmcLMBHUfX3ljbvPUnODOGHtra+ti+4z8vOCcPc25TToQlwoe
    iAqc1ZTbnAeSBgOPlo6pe5saA9eIguTFmKPsgGBWcDFQyj49/S6Q8vdobQy0swu0AIWHzKTJQUCQ5m9t
    ndmRBgRXs4FKYkpDg4JClzIyMCjI2bnYAEGMtXVGSen8kpKS+WdBLnkBElwqDwxh2SBXIFgBNPdmog0Y
    XF8NVPEGJGrDzM6gvCbaDQgeWFuv6i6sdSwqcnSsfb1i1eqPyUDR2o2sDEpLK9yBoM/a+lFWVlKSp6dn
    UlKWj3fvJ5Bo1j8NBpW1222B4P6iRc9WrowAg5UrHQoinUCi2zcxMqhs2xJbX+k8IWCiU2RBWJiDQ1hY
    QeSHqqrP7523bv27i5FB6dfP2Nj6usf34icE2DpFgoDTxMXW1l8q637E/tmlwaC8fnNsfXXlU+tll44d
    9XICAq+JAVXW1m8rq+tjt2xjZWCT3lBXXeZ8CxTEi8McfH0dwgoWWlsve+5cVl2/2ZIdGFBLnpQ5xx8H
    BmTxQj+/uDg/vx4g+2FAvHPZ1w2KoKBef8E5PsDrEMiIvp4FC3qAPrau6vcCqnj5jhEUWSJLzgd4Fexv
    m24NB9MP+xZ4BUy4YQZOvIIbz3kV+MaF9Lb5Q6T923pD/HwLbOeuFYUkGMMzJ3z9QmZ6+8yZd/vKtTvz
    5vh4zwSqmLtJAJq0OVlOZoXM9vbxTC4ExkVtYbKnj/fskIuXhZhgiZJfP7oCKN/tGJ0IBNGO3UAVSYWy
    wohkzc/iUliR7BhtkxIUlGIT7Zhc4XZKSBg5Y3Bq26W42LgETbazm5wCSkBL9ZjQsp6xaXlgYFTU8uVR
    UYGTJokYsGNmXnEJlvIaIChnkRDHkcE5OCWlpCQ5UTQDAKNSNkklgTOkAAAAAElFTkSuQmCC}


proc DoButtons {} {
    global S COLOR

    # Buttons in lower pane
    button .buttons.play -text "New" -image ::img::play -compound top -command StartGame
    bind .buttons.play <$::S(button,right)> Restart
    button .buttons.undo -text "Undo" -image ::img::undo -compound top -command ::Undo::UndoMove
    button .buttons.automove -text "Forced" -image ::img::solve -compound top -command DoAllForced
    button .buttons.quick -text "Quick Pass" -image ::img::quickpass -compound top -command ::Hint::QuickPass
    bind .buttons.quick <$::S(button,right)> ::Hint::BestSlice

    grid x .buttons.play .buttons.undo .buttons.automove .buttons.quick \
        -padx .1i -pady .2i -sticky ew
    grid columnconfigure .buttons {1 2 3 4} -uniform a
    grid columnconfigure .buttons {0 100} -weight 1
}
namespace eval ::Settings {
    variable solutionFrame ""
    variable SIZES
    variable HINTS
    variable HINT_NAMES {partial coloring health sets solve}
    variable HINT_DESCRIPTIONS

    array set HINT_DESCRIPTIONS {
        partial "Partial slice sums"
        coloring "Slice coloring"
        health "Health indicator"
        sets "Show valid combinations"
        solve "Show slice solution in hint"
    }

    set SIZES(all) {"2 squares" "3 squares" "4 squares" "5 squares" \
                        "6 squares" "7 squares" "8 squares" "9 squares"}

    "proc" AllOnOff {who how} {
        variable SIZES
        variable HINTS
        variable HINT_NAMES

        if {$who eq "sizes"} {
            foreach size $SIZES(all) {
                set SIZES($size) $how
            }
        } elseif {$who eq "hints"} {
            foreach x $HINT_NAMES {
                set HINTS($x) $how
            }
        } else {
            error "unknown option: $who"
        }
    }

    unset -nocomplain HINTS
    AllOnOff sizes 1
    AllOnOff hints 1
    set HINTS(explode) 1
    set HINTS(countdown) 1
}

proc ::Settings::Settings {} {
    variable SIZES
    variable HINTS
    variable HINT_NAMES
    variable solutionFrame
    variable HINT_DESCRIPTIONS
    global S

    destroy .settings
    toplevel .settings

    wm title .settings "$S(title) Settings"

    global WHINTS WSIZE
    set WSIZE .settings.f.lsize
    set WHINTS .settings.f.cas
    set WAID .settings.f.aid
    set WCLOSE .settings.f.close

    pack [::ttk::frame .settings.f] -fill both -expand 1
    ::ttk::label .settings.f.title -text "$S(title) Settings" -font $::B(font,settings,title)
    ::ttk::frame $WSIZE -borderwidth 2 -relief ridge -pad .1i
    ::ttk::frame $WHINTS -borderwidth 2 -relief ridge -pad .1i
    ::ttk::frame $WAID -borderwidth 2 -relief ridge -pad .1i
    ::ttk::frame $WCLOSE -borderwidth 2 -relief ridge -pad .1i

    grid .settings.f.title - - -padx .5i -pady .25i
    grid $WSIZE $WHINTS $WAID -sticky news
    grid $WCLOSE - - -sticky news
    grid columnconfigure [winfo parent $WSIZE] {0 1 2} -weight 1

    ################################################################
    # Size panel
    #
    ::ttk::label $WSIZE.title -text "Puzzle Sizes" -font $::B(font,settings,heading)
    grid $WSIZE.title -

    set row 1
    set col 0

    foreach size $SIZES(all) {
        set w $WSIZE.rb_$size
        ::ttk::checkbutton $w -variable ::Settings::SIZES($size) -text $size
        bind $w <$::S(button,right)> [list StartGame [lindex $size 0]]
        grid $w -row $row -column $col -sticky w
        if {[incr col] > 1} {
            incr row
            set col 0
        }
    }
    ::ttk::button $WSIZE.all0 -text "All on" -command {::Settings::AllOnOff sizes 1}
    ::ttk::button $WSIZE.all1 -text "All off" -command {::Settings::AllOnOff sizes 0}
    ::ttk::button $WSIZE.go -text "New Board" -command StartGame
    grid $WSIZE.all0 $WSIZE.all1 -pady {.2i 0}
    grid $WSIZE.go - -pady .2i

    ################################################################
    # Computer Assistance
    #
    ::ttk::label $WHINTS.title -text "Computer Aid" -font $::B(font,settings,heading)
    grid $WHINTS.title -

    foreach w $HINT_NAMES {
        ::ttk::checkbutton $WHINTS.$w -text $HINT_DESCRIPTIONS($w) -variable ::Settings::HINTS($w) \
            -command ::Settings::Apply
        grid $WHINTS.$w - -padx {.1i 0} -sticky w
    }
    ::ttk::button $WHINTS.all0 -text "Hard mode" -command {::Settings::AllOnOff hints 0 ; ::Settings::Apply }
    ::ttk::button $WHINTS.all1 -text "Default" -command {::Settings::AllOnOff hints 1 ; ::Settings::Apply }
    grid $WHINTS.all0 $WHINTS.all1 -pady {.2i 0}

    ################################################################
    # Reveal
    #
    ::ttk::label $WAID.title -text "Reveal" -font $::B(font,settings,heading)
    grid $WAID.title

    ::ttk::button $WAID.cell -text "Random cell" -command {::Hint::Cheat cell}
    ::ttk::button $WAID.row -text "Random slice" -command {::Hint::Cheat slice}
    ::ttk::button $WAID.fix -text "Fix bad cells" -command ::Hint::FixBad
    ::ttk::button $WAID.best -text "Best slice" -command ::Hint::BestSlice
    ::ttk::button $WAID.show -text "Show Solution" -command {::Settings::ShowSolution 1}
    set solutionFrame $WAID.sol

    grid $WAID.cell -sticky ew
    grid $WAID.row -sticky ew
    grid $WAID.fix -sticky ew
    grid $WAID.best -sticky ew
    grid $WAID.show -sticky ew

    ################################################################
    # Close
    #
    ::ttk::button $WCLOSE.close -text Close -command {destroy .settings}
    pack $WCLOSE.close -pady .2i
}
proc ::Settings::GetBoardSize {{sizeOverride ?}} {
    variable SIZES

    if {$sizeOverride ne "?"} { return $sizeOverride }

    set choices [lmap {k v} [array get SIZES *sq*] { if {! $v} continue ; lindex $k 0}]
    if {[llength $choices] == 0 || [llength $choices] == 8} {
        set size [RandomTriangular 2 10 7]
    } else {
        set size [lpick $choices]
    }
    return $size
}
proc ::Settings::ShowSolution {forced} {
    variable solutionFrame
    if {! $forced && ! [winfo exists $solutionFrame]} return

    destroy $solutionFrame
    ::ttk::frame $solutionFrame -borderwidth 2 -relief solid
    grid $solutionFrame -pady {.1i 0}
    ::NewBoard::ShowInFrame $solutionFrame
}
proc ::Settings::Apply {} {
    if {! $::BRD(active)} return
    ShowState
    for {set whichSlice 0} {$whichSlice < $::BRD(size)} {incr whichSlice} {
        UpdateTargetCellColor $whichSlice $whichSlice
        _ComputeHint row $whichSlice
        _ComputeHint col $whichSlice
    }
}

proc Help {} {
    global S

    destroy .help
    toplevel .help

    wm title .help "$S(title) Help"

    pack [::ttk::frame .help.f] -fill both -expand 1

    ::ttk::scrollbar .help.sb -command {.help.t yview}
    text .help.t -wrap word -yscrollcommand ".help.sb set" -height 35
    ::ttk::button .help.close -text Close -command {destroy .help}

    pack .help.close -in .help.f  -side bottom -fill none -expand 0 -pady .2i
    pack .help.sb -in .help.f -side right -fill y
    pack .help.t -in .help.f -side left -fill both -expand 1

    .help.t tag configure head -font {{} 20 bold} -justify center
    .help.t tag configure sub -justify center -font {{} 16 italic}
    .help.t tag configure h2 -font {{} 11 bold}
    .help.t tag configure normal -lmargin2 .3i

    "proc" T {args} { .help.t insert end {*}$args }
    "proc" Bullet {line} {
        set BULLET " \u2022 "
        T $BULLET bullet "$line" normal "\n"
    }
    "proc" Coloring {color title text} {
        set BULLET " \u2022 "
        set tag tag_$color
        set title2 [format %-6s $title]
        .help.t tag configure $tag -background $color
        T $BULLET bullet " $title2 " $tag " $text\n"
    }

    T "$S(title) Help\n" head
    T "Version $S(version)\n" sub
    T "By Keith Vetter\n\n" sub

    T "$S(title) is a numbers logic game. You are given a matrix of numbers "
    T "with an array of slice sums for every row "
    T "and column. The goal is to select some numbers and kill other numbers "
    T "so that the sum of the selected numbers match the slice sum for "
    T "that row and column -- aka 'slice'.\n\n"

    T "Game Play\n" h2

    Bullet "Clicking on a number will select it (by drawing a circle around it)"
    Bullet "Right clicking on a number will kill it"
    Bullet "Middle clicking on a number will restore it"
    Bullet "Play starts a new game with a random size (changeable in settings)"

    T "\n"
    T "Slice Sums Hints\n" h2
    Bullet "The small number below the slice sum is total still needed to reach the goal"
    Bullet "The small number above the slice sum is the excess above the goal\n"

    T "Slice Sums Colors\n" h2
    T "As an aid in solving this puzzle, the slice sum squares "
    T "are displayed in various colors.\n"

    # Normal, Done, Bad, Active, Almost, Need0
    Coloring $::COLOR(sums,normal) "Normal" "default state"
    Coloring $::COLOR(sums,active) "Active" "progress can be made on this slice"
    Coloring $::COLOR(sums,done) "Done" "the slice has been solved"
    Coloring $::COLOR(sums,bad) "Bad" "the slice is in an illegal state"
    Coloring $::COLOR(sums,almost) "Forced" "all unselected numbers add to the slice sum"
    Coloring $::COLOR(sums,need0) "Forced" "slice sum matched, all unselected numbers can be killed"

    T "\n"
    T "Solving Hints\n" h2
    Bullet "FORCED SELECT ALL: with a sum of \"6\" and digits \"1 2 3\", all digits must be selected"
    Bullet "FORCED KILL ALL: with a sum of \"6\" and selected digits \"1 2 3\" and unselected digit \"4\", the \"4\" must be killed"
    Bullet "FORCED SELECT: with a sum of \"6\" and digits \"2 2 4\", the \"4\" must be selected"
    Bullet "FORCED KILL: with a sum of \"3\" and digits \"1 2 3 4\", the \"4\" must be killed"

    T "\n"
    T "Keyboard Shortcuts\n" h2
    Bullet "Escape: do all forced moves"
    Bullet "Ctrl-z: undo"
    Bullet "Ctrl-q: quick pass removing items larger than their slice target"

    T "\n"
    T "Quick Pass\n" h2
    T "Quick pass runs through all the slices and kills any item that is greater "
    T "the slice's target.\n"

    T "\n"
    T "Cheats\n" h2
    Bullet "Health Marker: either a heart shape or stop sign in the lower right corner indicates correctness"
    Bullet "Right Button on slice sum square: show all ways of making the sum"
    Bullet "Ctrl-Right Button on slice sum square: also show all forced moves"
    Bullet "Space bar & Right button on slice sum square: if space is pressed when the right button is down, do all the forced moves"
    Bullet "\"Best slice\": highlights slice that solving would yield the most information"
    Bullet "\"Fix bad cells\": undoes moves until the board is solvable"

}
proc lpick {myList} {
    set idx [expr {int(rand() * [llength $myList])}]
    return [lindex $myList $idx]
}
proc Plural {count single {many ""}} {
    if {$count == 1} { return "1 $single" }
    if {$many eq ""} { set many "${single}s" }
    return "$count $many"
}
proc Pause {milliseconds} {
    set w .__busy
    destroy $w
    toplevel $w
    wm geom $w +10000+10000
    wm withdraw $w
    grab $w

    after $milliseconds [list destroy $w]
    tkwait window $w
}
namespace eval Explode {
    variable AIDS
    variable STATIC
    set STATIC(explode,delay) 50
    set STATIC(explode,totalTime) 300
    set STATIC(implode,delay) 50
    set STATIC(implode,totalTime) 300

    array set AIDS {}
}
proc ::Explode::Explode {row col} {
    variable AIDS
    variable STATIC
    global B

    set steps [expr {$STATIC(explode,totalTime) / $STATIC(explode,delay)}]

    lassign [GridXY $row $col] x0 y0 x1 y1 x y
    set smallest 5
    set biggest [expr {$x - $x0 - 5}]

    set coords {}
    set tag explode_${row}_$col

    .c create oval [list $x $y $x $y] -tag $tag -fill white -outline black -width 15
    .c raise text_${row}_$col

    for {set i 0} {$i < $steps} {incr i} {
        set boxSize [expr {$smallest + ($biggest - $smallest) * $i / $steps}]
        set xy [GrowBox [list $x $y $x $y] $boxSize]
        lappend coords $xy
    }

    set AIDS($tag) [after 10 [list ::Explode::ExplodeAnim $tag $STATIC(explode,delay) $coords]]
}
proc ::Explode::ExplodeAnim {tag delay coords} {
    variable AIDS
    variable STATIC

    if {! $::Settings::HINTS(explode) || $coords eq {}} {
        ::Explode::Stop $tag
        return
    }
    set newCoords [lassign $coords xy]
    .c coords $tag $xy
    set AIDS($tag) [after $delay [list ::Explode::ExplodeAnim $tag $delay $newCoords]]
}
proc ::Explode::Implode {row col} {
    global B
    variable STATIC

    set steps [expr {$STATIC(implode,totalTime) / $STATIC(implode,delay)}]
    set colors {}
    for {set i 0} {$i < $steps} {incr i} {
        set n [expr {100 * $i / $steps}]
        set color "gray$n"
        lappend colors $color
    }

    set tag bg_${row}_$col
    set lastColor [.c itemcget $tag -fill]
    set AIDS($tag) [after 10 \
                        [list ::Explode::ImplodeAnim $tag $STATIC(implode,delay) $colors $lastColor]]
}
proc ::Explode::ImplodeAnim {tag delay colors lastColor} {
    variable AIDS

    if {! $::Settings::HINTS(explode) || $colors eq {}} {
        ::Explode::Stop $tag $lastColor
        return
    }
    set newColors [lassign $colors color]
    .c itemconfig $tag -fill $color
    set AIDS($tag) [after $delay [list ::Explode::ImplodeAnim $tag $delay $newColors $lastColor]]
}
proc ::Explode::Stop {{who *} {lastColor ""}} {
    variable AIDS

    foreach {tag aid} [array get AIDS $who] {
        after cancel $aid
        lassign [split $tag "_"] type row col
        if {$type eq "explode"} {
            .c delete $tag
            .c raise circle_${row}_$col
            .c raise text_${row}_$col
        } else {
            .c itemconfig $tag -fill $lastColor
        }
    }
    array unset AIDS $who
}

################################################################

DoDisplay
update

if {0} {
    set size 8
    set seed 1028907424
    StartGame $size $seed

    set size 9
    set seed 1418909994
    StartGame $size $seed

}
proc blob {{fname puzzles/color_0.txt}} {
    StartGame ? ? $fname
}
StartGame

return

Another deadly pattern:
=======================

set size 8; set seed 1598439930
8 7 5 6
. . . .
8 7 5 6

set size 8
set seed 1598439930
set solution {0,0 0,2 0,3 0,5 1,1 1,2 1,3 1,4 1,5 1,7 2,0 3,1 3,3 3,4 4,1 4,2 4,5 4,7 5,5 6,0 6,1 6,2 6,4 6,5 6,7 7,3 7,4 7,5 7,6}
set BB {
    {-  20 20 23 25 20 31  6 21}
    {26  5  8  7  8  5  6  7  6}
    {34  4  3  7  8  6  3  5  7}
    { 6  6  4  9  9  8  8  7  6}
    {17  8  8  7  4  5  6  6  8}
    {17  3  2  3  9  4  5  6  7}
    { 4  6  8  2  7  8  4  3  7}
    {40  9  7  6  8  3  8  7  7}
    {22  5  6  6  5  6  5  6  6}
}



################################################################
# Multiple solutions
set BB {
    { - 6 7 2 5 19 5 11}
    { 9 8 6 2 6  7 6  7}
    {15 6 1 6 5  4 5  6}
    { 7 7 7 3 6  6 8  2}
    { 5 6 7 7 2  3 8  6}
    { 3 4 6 8 3  6 7  3}
    { 9 7 6 8 8  5 8  4}
    { 7 2 7 1 4  7 2  7}
}
set BB {
    { - 11 11 15  9 10 24  8}
    {11  3  9  7  4  8  8  9}
    { 3  8  8  7  2  3  7  8}
    {19  4  7  4  3  4  7  8}
    {23  7  4  5  5  7  7  5}
    { 9  7  8  2  5  4  9  9}
    { 8  3  7  8  5  8  6  4}
    {15  7  7  5  4  4  8  3}
} ;# Deadly pattern w/ 7 in row 6, col 5 and 3,1 & 4,0}



# Unsolvable
set BB {
    { - 17 16 26 23 17 11 11 15}
    {16  7  4  6  5  7  5  1  6}
    {25  5  9  3  5  6  4  7  3}
    {15  4  3  4  5  8  3  7  7}
    {17  4  3  5  4  5  3  6  2}
    {22  7  8  8  7  4  8  7  7}
    {17  5  2  7  7  3  8  2  5}
    {16  5  7  7  2  3  8  3  8}
    { 8  1  6  7  6  8  8  3  8}
}

# Unsolvable
set BB {
    { - 28 20 17 25 27 19 30 13}
    {14  8  5  1  4  5  3  9  4}
    {25  7  5  6  9  4  7  2  8}
    {17  7  6  9  8  5  5  8  6}
    {18  6  7  6  5  7  5  7  1}
    {25  5  8  7  7  8  7  6  4}
    {30  5  5  8  5  7  6  8  7}
    {29  8  8  7  8  6  6  6  7}
    {21  7  7  7  6  8  8  3  8}
}

set BB {
    {- 13 7 27 8 3 14 20}
    {14 7 4 7 1 3 7 2}
    {19 7 1 7 8 5 5 4}
    { 7 2 1 3 2 8 4 4}
    {21 4 4 6 2 5 9 8}
    { 8 8 1 7 8 2 8 1}
    {14 9 5 1 6 9 9 8}
    { 9 2 1 6 5 6 4 6}
} ;# Aug 26  19/49 circles 39%

set BB {
    {- 24 1 16 11 31 20}
    {24 9 1 7 4 8 2}
    { 6 1 1 1 1 1 4}
    {25 8 5 9 3 9 7}
    {16 6 3 1 7 8 2}
    {12 3 3 7 2 2 7}
    {20 6 6 6 9 5 6}
} ;# 18/36 circles 50%

set BB {
    {- 13 20 9 4 1 20}
    {14 5 6 5 3 9 5}
    {16 9 9 5 4 1 6}
    { 7 5 1 5 1 6 7}
    {10 1 9 9 9 7 4}
    { 9 2 2 8 4 4 7}
    {11 5 4 8 3 6 2}
} ;# July 7 15/36 circles 42%

set BB3 {
    {- 10 16 23 5 8 12 10 8}
    {14 2 6 8 2 6 2 1 5}
    { 8 7 9 9 5 3 6 1 3}
    {15 6 4 5 6 5 8 9 3}
    { 9 6 3 6 4 2 7 1 8}
    {16 3 7 9 3 4 2 9 9}
    {12 4 4 5 6 7 9 6 8}
    { 8 5 3 4 6 6 5 2 1}
    {10 7 8 9 9 3 7 4 5}
} ;# June 20  17/64 circles 27%

set BB {
    {- 11 2 19 19 19 27 11 23}
    {10 6 8 1 7 7 4 2 9}
    {20 6 3 1 2 3 4 3 9}
    {18 7 4 1 9 8 7 1 1}
    {13 6 2 3 8 2 8 4 4}
    {19 9 7 3 1 5 6 9 8}
    {14 5 3 3 7 1 1 4 2}
    {21 1 3 8 7 2 6 9 7}
    {16 1 2 3 6 1 6 7 7}
} ;# May 19  27/64 42%

set BB_TOUGH {
    {-  7 9 4 6 14 9 7 9}
    {12 8 6 4 3  8 6 8 2}
    {15 8 6 7 2  8 7 7 8}
    { 4 4 8 5 3  8 4 4 6}
    {16 2 3 6 8  6 5 5 5}
    { 6 5 7 3 4  2 2 4 2}
    { 5 6 3 8 5  8 7 3 5}
    { 5 5 5 5 7  2 3 8 7}
    { 2 8 6 7 2  7 6 5 8}
}

set BB_NOSOLVE {
    {- 21 17 12 31 7 7 29 14 6 6}
    {18 6 8 6 3 2 4 6 7 5 6}
    {10 5 7 5 5 7 4 5 4 4 7}
    {17 1 8 8 5 4 5 1 5 2 7}
    {6 6 5 2 6 6 3 4 8 5 6}
    {11 8 7 4 6 5 6 7 4 6 5}
    {15 7 2 7 7 7 5 6 8 3 7}
    {21 4 8 8 6 5 2 7 9 8 5}
    {16 6 9 4 8 2 6 8 7 1 8}
    {17 4 6 6 7 7 5 7 8 3 5}
    {19 3 3 2 9 5 8 5 4 5 8}
}


set BB_ambiguous {
    {- 17  9 12 26 17 19 28}
    {11 3  6  5  5  8  8  8}
    {20 8  4  8  7  7  5  7}
    {24 2  7  1  7  6  7  8}
    {26 4  8  8  5  6  7  4}
    {13 7  5  9  3  5  2  5}
    {28 4  9  3  5  6  7  7}
    { 6 8  6  5  6  5  3  3}
} ;# 7's in row 1,2,5 & columns 3,5,6 form a deadly pattern
