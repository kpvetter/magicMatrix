#!/bin/sh
# Restart with tcl: -*- mode: tcl; tab-width: 8; -*- \
exec tclsh $0 ${1+"$@"}

##+##########################################################################
#
# kpv.tcl -- code to create magic matrices from existing sources
# by Keith Vetter 2025-11-12
#

set S(button,middle) "2"
set S(button,right) "3"
if {$::tcl_platform(os) eq "Darwin" && [info tclversion] < 9.0} {
    set S(button,middle) "3"
    set S(button,right) "2"
}

catch {namespace delete ::KPV }
set COLOR(blobs) {#d95d4c #5a9ee0 #bce5d0 #d54782 #936bf3 #9bbc20 #ca7a18 #e68e7b
    #6e82e7 #f42ad7 #7316f2 #49cadb}

namespace eval ::KPV {
    variable KBRD

    variable KTOP .kpv
    variable currentBlob
    variable blobSelected {}
    variable messages ""

}
proc ::KPV::Blob {size} {
    variable KBRD
    variable KTOP
    variable currentBlob
    variable blobSelected

    ::KPV::_Layout $size

    set currentBlob 0

    array unset KBRD blob,*,cells
    set blobSelected {}

    foreach row $KBRD(indices) {
        set KBRD(blob,$row,cells) {}
        foreach col $KBRD(indices) {
            set w $KTOP.$row,$col
            bind $w <Shift-Button-1> [list ::KPV::_MouseDownBlob $row $col]
            bind $w <Shift-Button-$::S(button,right)> [list ::KPV::_MouseDownUnBlob $row $col]

            bind $w <Shift-Button-$::S(button,right)> [list ::KPV::_MouseDownSelect $w $row $col]
        }
    }
}
proc ::KPV::_Layout {{size ?}} {
    variable KBRD
    variable KTOP

    destroy $KTOP
    toplevel $KTOP -padx .1i -pady .1i
    wm title $KTOP "Magic Matrix Entry"
    wm geom $KTOP +200+200

    if {$size eq "?"} {
        set size $::BRD(size)
    }
    set size2 [expr {$size + 1}]

    unset -nocomplain KBRD
    set KBRD(size) $size
    for {set i 0} {$i < $size} {incr i} { lappend KBRD(indices) $i }

    set grow 0
    set gcol 1
    foreach col $KBRD(indices) {
        set w $KTOP.col,$col
        entry $w -textvariable ::KPV::KBRD(col,$col) -width 2 -justify c -bd 4 -relief flat -exportselection 0
        bindtags $w [list Entry $w all]
        bind $w <Key> [list ::KPV::_KeyBinding $w col $col %K]

        grid $w -row $grow -column $gcol -pady {0 .1i}
        incr gcol
    }

    foreach row $KBRD(indices) {
        incr grow
        set gcol 0
        set w $KTOP.row,$row
        entry $w -textvariable ::KPV::KBRD(row,$row) -width 2 -justify c -bd 4 -relief flat -exportselection 0
        grid $w -row $grow -column $gcol -padx {0 .1i}

        bindtags $w [list Entry $w all]
        bind $w <Key> [list ::KPV::_KeyBinding $w row $row %K]

        foreach col $KBRD(indices) {
            incr gcol
            set w $KTOP.$row,$col
            entry $w -textvariable ::KPV::KBRD($row,$col) -width 2 -justify c -bd 4 -relief flat -exportselection 0
            grid $w -row $grow -column $gcol

            bindtags $w [list Entry $w all]
            bind $w <Key> [list ::KPV::_KeyBinding $w $row $col %K]
        }
    }
    ::ttk::frame $KTOP.blobsums
    grid $KTOP.blobsums -row 100 -columnspan $size2 -pady {.2i 0}

    set color [lindex $::COLOR(blobs) 0]
    label $KTOP.blobsums.m1 -text "Current blob #0" -bg $color

    grid $KTOP.blobsums.m1 -columnspan $size -sticky ew -row 101
    foreach id $KBRD(indices) {
        set w $KTOP.blobsums.bs$id
        set color [lindex $::COLOR(blobs) $id]

        unset -nocomplain ::KPV::KBRD(blob,$id)
        entry $w -textvariable ::KPV::KBRD(blob,$id) -width 2 -justify c -exportselection 0
        $w config -bg $color
        grid $w -row 102 -column $id
    }


    ::ttk::frame $KTOP.bottom
    grid $KTOP.bottom -row 200 -columnspan $size2 -pady {.2i 0}

    label $KTOP.msgs -textvariable ::KPV::messages -height 2
    grid $KTOP.msgs -in $KTOP.bottom -columnspan 2 -sticky ew

    ::ttk::button $KTOP.sums -text "Compute Sums" -command ::KPV::_ComputeSums
    grid $KTOP.sums -in $KTOP.bottom -columnspan 2 -sticky ew

    ::ttk::button $KTOP.data -text "Copy to Clipboard" -command ::KPV::_ClipData
    grid $KTOP.data -in $KTOP.bottom -columnspan 2 -sticky ew

    ::ttk::button $KTOP.file -text "Save to File" -command ::KPV::_Save
    grid $KTOP.file -in $KTOP.bottom -columnspan 2 -sticky ew

    ::tk::TabToWindow $KTOP.col,0
}
proc ::KPV::_KeyBinding {w row col key} {
    # Handle key presses in our matrix
    #  * arrow keys move up down left and right
    #  * single digits entry
    variable KTOP
    variable KBRD
    if {$key eq "space"} {
        event generate $w <<NextWindow>>
    }
    if {$key in {0 1 2 3 4 5 6 7 8 9}} {
        if {$row ni {"row" "col"}} {
            event generate $w <<NextWindow>>
            return
        }
        if {[string length $KBRD($row,$col)] >= 2} {
            event generate $w <<NextWindow>>
            return
        }
        return
    }

    # Handle arrow keys
    array set DRC {
        "Up" {-1 0}
        "Down" {1 0}
        "Left" {0 -1}
        "Right" {0 1}
    }
    if {$key in [array names DRC]} {
        lassign $DRC($key) drow dcol
        if {$row ni {"row" "col"}} {
            set row2 [expr {$row + $drow}]
            set col2 [expr {$col + $dcol}]
            if {$row2 == -1} {
                set row2 "col"
            } elseif {$col2 == -1} {
                set col2 $row2
                set row2 "row"
            }
        } elseif {$row eq "row"} {
            if {$key eq "Left"} return
            if {$key eq "Right"} {
                set row2 $col
                set col2 0
            } else {
                set row2 $row
                set col2 [expr {$col + $drow}]
            }
        } elseif {$row eq "col"} {
            if {$key eq "Up"} return
            if {$key eq "Down"} {
                set row2 0
                set col2 $col
            } else {
                set row2 $row
                set col2 [expr {$col + $dcol}]
            }
        }
        if {$row2 ni {"row" "col"}} {
            if {$row2 < 0 || $row2 >= $KBRD(size)} return
        }
        if {$col2 < 0 || $col2 >= $KBRD(size)} return

        set w2 $KTOP.$row2,$col2
        ::tk::TabToWindow $w2
    }
}
proc ::KPV::_Save {} {
    variable KTOP
    set fname [tk_getSaveFile -message "Select file to save to" -parent $KTOP \
                   -title "Save Board" -initialdir [pwd]]
    if {$fname eq {}} return
    set result [::KPV::_GetBoardData]
    set fout [open $fname "w"]
    puts $fout $result
    close $fout

}
proc ::KPV::_ClipData {} {
    set result [::KPV::_GetBoardData]
    clipboard clear
    clipboard append $result
    return $result
}
proc ::KPV::_GetBoardData {} {
    variable KBRD
    variable blobSelected

    set result {}
    set line {-}
    foreach col $KBRD(indices) {
        lappend line $KBRD(col,$col)
    }
    set line [lmap x $line {expr {[string is integer -strict $x] ? $x : "?"}}]
    lset line 0 "-"
    append result [join $line " "] "\n"

    foreach row $KBRD(indices) {
        set line [list $KBRD(row,$row)]
        foreach col $KBRD(indices) {
            lappend line $KBRD($row,$col)
        }
        set line [lmap x $line {expr {[string is integer -strict $x] ? $x : "?"}}]
        append result [join $line " "] "\n"
    }

    append result "\n"
    foreach id $KBRD(indices) {
        # blob 2 {0 0} {0 1} {1 1} {2 1}
        set line "blob $KBRD(blob,$id) $KBRD(blob,$id,cells)\n"
        append result $line
    }
    return $result
}
proc ::KPV::_MouseDownSelect {w row col} {
    variable blobSelected

    set cell [list $row $col]
    set idx [lsearch -exact $blobSelected $cell]
    if {$idx == -1} {
        lappend blobSelected $cell
        $w config -relief solid
    } else {
        set blobSelected [lreplace $blobSelected $idx $idx]
        $w config -relief flat
    }
}
proc ::KPV::_MouseDownUnBlob {row col} {
    variable KBRD
    variable KTOP
    variable messages

    set cell [list $row $col]

    foreach whichBlob $KBRD(indices) {
        set n [lsearch -exact $KBRD(blob,$whichBlob,cells) $cell]
        if {$n == -1} continue

        set messages "removing cell $row,$col from blob #$whichBlob"
        set KBRD(blob,$whichBlob,cells) [lreplace $KBRD(blob,$whichBlob,cells) $n $n]
        set w $KTOP.$row,$col
        set bg [lindex [$w config -bg] 3]
        $w config -bg $bg
        return
    }
}
proc ::KPV::_MouseDownBlob {row col} {
    variable KBRD
    variable KTOP
    variable currentBlob
    variable messages

    if {$currentBlob >= $KBRD(size)} {
        set messages "blobs full"
        return
    }
    if {[llength $KBRD(blob,$currentBlob,cells)] == $KBRD(size)} {
        set message "current blob is already full"
        return
    }


    set w $KTOP.$row,$col
    set cell [list $row $col]
    if {$cell in $KBRD(blob,$currentBlob,cells)} {
        set messages "duplicate cell $cell\nignoring"
        return
    }
    lappend KBRD(blob,$currentBlob,cells) $cell
    set color [lindex $::COLOR(blobs) $currentBlob]
    $w config -bg $color

    if {[llength $KBRD(blob,$currentBlob,cells)] < $KBRD(size)} return
    set messages "blob is full-sized\nmoving to next"

    incr currentBlob
    if {$currentBlob >= $KBRD(size)} {
        set currentBlob 0
    }
    ::KPV::_ChangeCurrentBlob $currentBlob
}
proc ::KPV::_ChangeCurrentBlob {whichBlob} {
    variable KTOP

    set color [lindex $::COLOR(blobs) $whichBlob]
    $KTOP.blobsums.m1 config -bg $color -text "Current Blob #$whichBlob"

    focus $KTOP.blobsums.bs$whichBlob
    $KTOP.blobsums.bs$whichBlob selection range 0 end
}
proc ::KPV::_GetCellsInSlice {sliceType whichSlice} {
    variable KBRD

    if {$sliceType eq "row"} {
        set result [lmap x $KBRD(indices) { list $whichSlice $x}]
    } elseif {$sliceType eq "col"} {
        set result [lmap x $KBRD(indices) { list $x $whichSlice}]
    } else {
        set result $KBRD(blob,$whichSlice,cells)
    }


}
proc ::KPV::_ComputeSums {} {
    variable KBRD
    variable blobSelected
    variable messages

    if {$blobSelected eq {}} {
        set messages "No selected cells"
        return
    }

    foreach sliceType {"row" "col" "blob"} {
        foreach whichSlice $KBRD(indices) {
            set KBRD($sliceType,$whichSlice) 0
            foreach cell [::KPV::_GetCellsInSlice $sliceType $whichSlice] {
                if {$cell in $blobSelected} {
                    lassign $cell row col
                    incr KBRD($sliceType,$whichSlice) $KBRD($row,$col)
                }
            }
        }
    }
}

# ::KPV::_Layout 8

proc Debug {} {
    array set ::KPV::KBRD {
        size 4
        indices {0 1 2 3}
        0,0 6 0,1 3 0,2 8 0,3 9
        1,0 8 1,1 8 1,2 6 1,3 2
        2,0 3 2,1 4 2,2 4 2,3 9
        3,0 5 3,1 3 3,2 8 3,3 9
    }
    # array set ::KPV::KBRD {
    #     size 4
    #     indices {0 1 2 3}
    #     0,0 6 0,1 3 0,2 8 0,3 9
    #     1,0 8 1,1 8 1,2 6 1,3 2
    #     2,0 3 2,1 4 2,2 4 2,3 9
    #     3,0 5 3,1 3 3,2 8 3,3 9
    #     blob,0 11
    #     blob,0,cells {{0 0} {0 1} {0 2} {1 1}}
    #     blob,1 15
    #     blob,1,cells {{0 3} {1 3} {1 2} {2 3}}
    #     blob,2 8
    #     blob,2,cells {{1 0} {2 0} {3 0} {3 1}}
    #     blob,3 13
    #     blob,3,cells {{2 1} {2 2} {3 2} {3 3}}
    #     blob,4 0
    #     col,0 8
    #     col,1 11
    #     col,2 10
    #     col,3 18
    #     row,0 12
    #     row,1 22
    #     row,2 4
    #     row,3 9
    # }
}
return
::KPV::Blob 4
Debug
proc foo {args} {
    puts ""
    foreach {a b} $args { puts -nonewline "$a: '$b' "}
    puts ""
}
bind .top <Key> [list foo %%K %K %%k %k %%A %A %%N %N]
