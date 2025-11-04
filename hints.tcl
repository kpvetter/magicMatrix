#!/bin/sh
# Restart with tcl: -*- mode: tcl; tab-width: 8; -*- \
exec tclsh $0 ${1+"$@"}

##+##########################################################################
#
# hints.tcl -- <description>
# by Keith Vetter 2025-09-04
#

# TODO:
# replace global BRD with upvar

namespace eval ::Hint {
    variable poppedUpItem {}
    variable pausing 0
}

proc ::Hint::Down {sliceType whichSlice verbose} {
    focus -force .
    if {! $::BRD(active)} return
    if {! $::Settings::HINTS(sets)} return
    if {$verbose && ! $::Settings::HINTS(solve)} return

    ::Hint::Popup $sliceType $whichSlice $verbose
}
proc ::Hint::Up {sliceType whichSlice} {
    .c delete hintPopup
}
proc ::Hint::Popup {sliceType whichSlice verbose} {
    variable poppedUpItem
    global BRD

    set poppedUpItem [list $sliceType $whichSlice]
    set tag sum_${sliceType}_$whichSlice
    lassign [.c bbox $tag] x0 y0 x1 y1
    if {$sliceType eq "row"} {
        set x $x1
        set y [expr {$y0 - 10}]
        set anchor se
    } else {
        set x [expr {$x0 - 10}]
        set y $y1
        set anchor se

    }

    .c delete hintPopup
    set text [::Hint::PrettyText $sliceType $whichSlice 7 $verbose]
    .c create text $x $y -tag {hintPopup hintText} -anchor $anchor -text $text -justify c \
        -font $::B(font,hintBox)
    set xy [GrowBox [.c bbox hintText] 5]
    .c create rect $xy -tag {hintPopup hintBox} -fill $::COLOR(hintBox) -outline black -width 3
    .c raise hintText

    lassign [.c bbox hintPopup] x0 y0 x1 y1
    if {$x0 < 0} {
        .c move hintPopup [expr {abs($x0)}] 0
    }
    if {$y0 < 0} {
        .c move hintPopup 0 [expr {abs($y0)}]
    }
}
proc ::Hint::DoIt {} {
    # Do all the hinted moves
    variable poppedUpItem

    if {[.c find withtag hintPopup] eq {}} return
    lassign $poppedUpItem sliceType whichSlice
    ::Hint::_Doit $sliceType $whichSlice
}
proc ::Hint::_Doit {sliceType whichSlice} {
    set idx -1
    foreach key $::BRD($sliceType,$whichSlice,hint) {
        incr idx
        if {$key eq $::MIDDLE_DOT} continue
        lassign [split $key ""] digit backspace
        set action [expr {$backspace eq "" ? "select" : "kill"}]
        if {$sliceType eq "row"} {
            MakeMove $action $whichSlice $idx
        } else {
            MakeMove $action $idx $whichSlice
        }
    }
    ::Hint::Up $sliceType $whichSlice
}
proc ::Hint::Cheat {} {
    global BRD

    if {! $BRD(active)} return
    if {! [::Hint::IsOk]} {return [::Hint::FixBad]}
    if {[DoAllForced]} return

    set candidates {}
    foreach sliceType {row col blob} {
        if {$sliceType eq "blob" && ! $BRD(hasBlobs)} continue
        foreach i $BRD(indices) {
            if {[string trim $BRD($sliceType,$i,hint) " $::MIDDLE_DOT"] ne ""} {
                lappend candidates [list $sliceType $i]
            }
        }
    }
    set who [lpick $candidates]
    lassign $who sliceType whichSlice
    set tagArrow arrow_${sliceType}_$whichSlice
    .c itemconfig $tagArrow -fill $::COLOR(target,highlight)
    ::Hint::_Doit $sliceType $whichSlice
}
proc ::Hint::PrettyText {sliceType whichSlice maxLines verbose} {
    global BRD
    set size $BRD(size)
    set sets $BRD($sliceType,$whichSlice,sets)
    set unselected "\u2717"

    set excess [expr {[llength $sets] - $maxLines}]
    if {$excess == 1} {
        set excess 0
    } elseif {$excess > 0} {
        set sets [lrange $sets 0 $maxLines-1]
    }

    set lines {}
    foreach set $sets {
        set line {}
        for {set other 0} {$other < $size} {incr other} {
            set n [lsearch -index 1 -integer -exact $set $other]
            if {$n > -1} {
                lappend line [lindex $set $n 0]
            } else {
                set what [expr {$sliceType eq "row" ? $BRD($whichSlice,$other) : $BRD($other,$whichSlice)}]
                set status [lindex $what 1]
                if {$status eq "select"} {
                    lappend line [NumberToCircle [lindex $what 0]]
                } elseif {$status eq "kill"} {
                    lappend line $unselected
                } else {
                    lappend line $::MIDDLE_DOT
                }
            }
        }
        lappend lines [join $line " "]
    }
    if {$excess > 0} { lappend lines "($excess more)" }
    if {$verbose} {
        set bar [HorizontalBar $::B(font,hintBox) [lindex $lines 0]]
        lappend lines $bar
        lappend lines [join $BRD($sliceType,$whichSlice,hint) " "]
    }
    set text [join $lines "\n"]

    return $text
}
proc ::Hint::BestSlice {} {
    global BRD
    global focus

    .c itemconfig arrow -fill $::COLOR(bg)

    set focus {}
    foreach {k v} [array get BRD *,hint] {
        # TODO: figure out how to indicate a blob being the best slice
        if {[string match blob,* $k]} continue
        set raw [string map [list $::MIDDLE_DOT "" \u0336 "" " " ""] $v]
        set count [string length $raw]
        if {$count > 0} {
            lassign [split $k ","] sliceType whichSlice _
            lappend focus [list $count $sliceType $whichSlice]
        }
    }
    set focus [lsort -integer -index 0 -decreasing $focus]

    if {$focus ne {}} {
        foreach item $focus {
            lassign $item count sliceType whichSlice
            if {$count < [lindex $focus 0 0]} break
            set tagArrow arrow_${sliceType}_$whichSlice
            .c itemconfig $tagArrow -fill $::COLOR(target,highlight)
        }
    }
}
proc ::Hint::IsNullHint {sliceType whichSlice} {
    global BRD

    set hint $BRD($sliceType,$whichSlice,hint)
    set raw [string map [list $::MIDDLE_DOT "" \u0336 "" " " ""] $hint]
    return [expr {$raw eq ""}]
}
proc ::Hint::IsOk {} {
    set bad [::Hint::FindBad]
    if {$bad eq {}} { return True }
    return False
}
proc ::Hint::Message {msg} {
    if {[.c find withtag hint] eq {}} {
        puts "MISSING HINT"
        puts $msg
        return
    }
    .c itemconfig hint -text $msg
    after 5000 {.c itemconfig hint -text ""}
}
proc ::Hint::FixBad {} {
    set bad [::Hint::FindBad]
    if {$bad eq {}} {
        set msg "All good"
    } else {
        set count [::Undo::UndoToGoodState]
        set msg "Undid [Plural $count move] to fix [Plural [llength $bad] {bad cells}]"
    }
    ::Hint::Message $msg
}
proc ::Hint::FindBad {} {
    global BRD

    set solution [::NewBoard::GetSolution]

    set bad {}
    foreach row $BRD(indices) {
        foreach col $BRD(indices) {
            set key "$row,$col"
            set state [lindex $BRD($key) 1]
            if {$state eq "normal"} continue
            if {$state eq "select" && $key ni $solution} {
                lappend bad [list $row $col "bad select"]
            }
            if {$state eq "kill" && $key in $solution} {
                lappend bad [list $row $col "bad kill"]
            }
        }
    }
    return $bad
}
proc ::Hint::FindUnfinishedCells {} {
    global BRD

    set solution [::NewBoard::GetSolution]
    set unfinished {}

    foreach row $BRD(indices) {
        foreach col $BRD(indices) {
            set key "$row,$col"
            set state [lindex $BRD($key) 1]
            if {$state ne "normal"} continue
            if {$key in $solution} {
                lappend unfinished [list select $key]
            } else {
                lappend unfinished [list kill $key]
            }
        }
    }
    return $unfinished
}
proc ::Hint::QuickPass {} {
    global BRD

    if {! $BRD(active)} return
    set undoItems {}

    set highlightPauseMS 200
    foreach row $BRD(indices) {
        set cells [::Hint::QuickPassSlice row $row]
        foreach cell $cells {
            MakeMove kill {*}$cell
            lappend undoItems normal {*}$cell
        }
        set tag arrow_row_$row
        .c itemconfig $tag -fill $::COLOR(target,highlight)
        Pause $highlightPauseMS
        .c itemconfig $tag -fill $::COLOR(bg)
    }

    foreach col $BRD(indices) {
        set cells [::Hint::QuickPassSlice col $col]
        foreach cell $cells {
            MakeMove kill {*}$cell
            lappend undoItems normal {*}$cell
        }
        set tag arrow_col_$col
        .c itemconfig $tag -fill $::COLOR(target,highlight)
        Pause $highlightPauseMS
        .c itemconfig $tag -fill $::COLOR(bg)
    }
    if {$BRD(hasBlobs)} {
        foreach blob $BRD(indices) {
            lassign [lindex $BRD(blob,$blob,cells) 0] row col

            set cells [::Hint::QuickPassSlice blob $blob]
            foreach cell $cells {
                MakeMove kill {*}$cell
                lappend undoItems normal {*}$cell
            }
            set tag blob_${row}_$col
            set oldColor [.c itemcget $tag -fill]
            .c itemconfig $tag -fill $::COLOR(target,highlight,blob)
            Pause $highlightPauseMS
            .c itemconfig $tag -fill $oldColor
        }
    }
    ::Undo::PushMoves $undoItems
}

proc ::Hint::QuickPassSlice {sliceType whichSlice} {
    # Find all cells in given slice that are greater than the target
    global BRD

    set all {}
    foreach index $BRD(indices) {
        if {$sliceType eq "row"} {
            set key "$whichSlice,$index"
        } elseif {$sliceType eq "col"} {
            set key "$index,$whichSlice"
        } else {
            lassign [lindex $BRD(blob,$whichSlice,cells) $index] row col
            set key "$row,$col"
        }
        lassign $BRD($key) value state
        if {$state ne "normal"} continue
        if {$value > $BRD($sliceType,$whichSlice)} {
            lappend all [split $key ","]
        }
    }
    return $all
}

proc ::Hint::QuickPassFast {} {
    # Quick pass over grid removing all cells greater than the slice target
    global BRD

    foreach row $BRD(indices) {
        foreach col $BRD(indices) {
            lassign $BRD($row,$col) value state
            if {$state ne "normal"} continue

            if {$value > $BRD(row,$row) || $value > $BRD(col,$col)} {
                MakeMove kill $row $col
                incr cnt
            }
        }
    }

    return $cnt
}
proc ::Hint::QuickPassTooGood {} {
    # Quick pass over grid removing all cells greater than needed or excess
    global BRD

    set cnt 0
    foreach row $BRD(indices) {
        lassign $BRD(row,$row,meta) rowTarget rowSelectedTotal rowNeeded rowUnselectedTotal
        set rowExcess [expr {$rowUnselectedTotal - $rowNeeded}]

        foreach col $BRD(indices) {
            lassign $BRD($row,$col) value state
            if {$state ne "normal"} continue

            lassign $BRD(col,$col,meta) colTarget colSelectedTotal colNeeded colUnselectedTotal
            set colExcess [expr {$colUnselectedTotal - $colNeeded}]
            if {$value > $rowNeeded || $value > $colNeeded} {
                MakeMove kill $row $col
                incr cnt
            } elseif {$value > $rowExcess || $value > $colExcess} {
                MakeMove select $row $col
                incr cnt
            }
        }
    }

    return $cnt
}
proc ::Hint::ShowBad {} {
    set bad [::Hint::FindBad]
    if {$bad eq ""} {
        set msg "All good"
    } else {
        set msg [Plural [llength $bad] "bad cell"]
    }
    ::Hint::Message $msg
}
