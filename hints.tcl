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
    variable MAX_LINES 7
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
    variable MAX_LINES
    global BRD

    set poppedUpItem [list $sliceType $whichSlice]
    set tag sum_${sliceType}_$whichSlice
    lassign [.c bbox $tag] x0 y0 x1 y1
    if {$sliceType eq "row"} {
        set x $x1
        set y [expr {$y0 - 10}]
        set anchor se
    } elseif {$sliceType eq "col"} {
        set x [expr {$x0 - 10}]
        set y $y1
        set anchor se
    } elseif {$sliceType eq "blob"} {
        set x $x1
        set y [expr {$y0 - 10}]
        set anchor se
    }

    .c delete hintPopup
    set text [::Hint::PrettyText $sliceType $whichSlice $MAX_LINES $verbose]
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
    global BRD

    set hints $BRD($sliceType,$whichSlice,hint)
    set cells [GetAllCellsForSlice BRD $sliceType $whichSlice]
    foreach key $hints cell $cells {
        if {$key eq $::MIDDLE_DOT} continue
        lassign [split $key ""] digit backspace
        set action [expr {$backspace eq "" ? "select" : "kill"}]
        lassign $cell row col
        MakeMove $action $row $col
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
    .c raise $tagArrow
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
    foreach solutionSet $sets {
        set line {}
        foreach other $BRD(indices) {
            set n [lsearch -index 1 -integer -exact $solutionSet $other]
            if {$n > -1} {
                # This cell is part of this solution set so just display it
                lappend line [lindex $solutionSet $n 0]
            } else {
                # This cell is NOT part of the solution set, show its state properly
                set coords [GetNthCellInSlice BRD $sliceType $whichSlice $other]
                lassign $BRD([join $coords ","]) value status

                if {$status eq "select"} {
                    lappend line [NumberToCircle $value]
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

    .c lower arrow

    set bestSlices {}
    foreach {k v} [array get BRD *,hint] {
        set raw [string map [list $::MIDDLE_DOT "" \u0336 "" " " ""] $v]
        set count [string length $raw]
        if {$count > 0} {
            lassign [split $k ","] sliceType whichSlice _
            lappend bestSlices [list $count $sliceType $whichSlice]
        }
    }
    set bestSlices [lsort -integer -index 0 -decreasing $bestSlices]
    foreach item $bestSlices {
        lassign $item count sliceType whichSlice
        if {$count < [lindex $bestSlices 0 0]} break

        if {$sliceType eq "blob"} {
            lassign [lindex $BRD(blob,$whichSlice,cells) 0] row col
            set tagArrow arrow_${row}_$col
        } else {
            set tagArrow arrow_${sliceType}_$whichSlice
        }
        .c raise $tagArrow
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
proc ::Hint::QuickPass {} {
    global BRD

    .c lower arrow
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
        .c raise $tag
        Pause $highlightPauseMS
        .c lower $tag
    }

    foreach col $BRD(indices) {
        set cells [::Hint::QuickPassSlice col $col]
        foreach cell $cells {
            MakeMove kill {*}$cell
            lappend undoItems normal {*}$cell
        }
        set tag arrow_col_$col
        .c raise $tag
        Pause $highlightPauseMS
        .c lower $tag
    }
    if {$BRD(hasBlobs)} {
        foreach blob $BRD(indices) {
            lassign [lindex $BRD(blob,$blob,cells) 0] row col
            set tag blob_${row}_$col
            set tagBlobArrow arrow_${row}_$col

            set cells [::Hint::QuickPassSlice blob $blob]
            foreach cell $cells {
                MakeMove kill {*}$cell
                lappend undoItems normal {*}$cell
            }
            set oldColor [.c itemcget $tag -fill]
            .c raise $tagBlobArrow
            Pause $highlightPauseMS
            .c lower $tagBlobArrow
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
