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

namespace eval ::KPV {
    variable KBRD

    variable KTOP .kpv
    variable currentBlob
    variable blobSelected {}
    variable messages ""

}
proc ::KPV::Layout {{size ?}} {
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
        # bind $w <Key-space> [list event generate $w <<NextWindow>> ]
        bindtags $w [list Entry $w all]
        bind $w <Key> [list ::KPV::KeyBinding $w col $col %K]

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
        bind $w <Key> [list ::KPV::KeyBinding $w row $row %K]

        foreach col $KBRD(indices) {
            incr gcol
            set w $KTOP.$row,$col
            entry $w -textvariable ::KPV::KBRD($row,$col) -width 2 -justify c -bd 4 -relief flat -exportselection 0
            grid $w -row $grow -column $gcol

            bindtags $w [list Entry $w all]
            bind $w <Key> [list ::KPV::KeyBinding $w $row $col %K]
        }
    }
    ::ttk::frame $KTOP.blobsums
    grid $KTOP.blobsums -row 100 -columnspan $size2 -pady {.2i 0}

    label $KTOP.blobsums.m1 -text "Current blob #0"
    grid $KTOP.blobsums.m1 -columnspan $size -sticky ew -row 101
    foreach id $KBRD(indices) {
        set w $KTOP.blobsums.bs$id
        entry $w -textvariable ::KPV::KBRD(blob,$id) -width 2 -justify c -exportselection 0
        grid $w -row 102 -column $id
    }


    ::ttk::frame $KTOP.bottom
    grid $KTOP.bottom -row 200 -columnspan $size2 -pady {.2i 0}

    label $KTOP.msgs -textvariable ::KPV::messages -height 2
    grid $KTOP.msgs -in $KTOP.bottom -columnspan 2 -sticky ew

    ::ttk::button $KTOP.sums -text "Compute Sums" -command ::KPV::ComputeSums
    grid $KTOP.sums -in $KTOP.bottom -columnspan 2 -sticky ew

    ::ttk::button $KTOP.data -text "Copy to Clipboard" -command ::KPV::GetBoard
    grid $KTOP.data -in $KTOP.bottom -columnspan 2 -sticky ew

    ::tk::TabToWindow $KTOP.col,0
}
proc ::KPV::KeyBinding {w row col key} {
    # Handle key presses in our matrix
    #  * arrow keys move up down left and right
    #  * single digits entry
    variable KTOP
    variable KBRD
    if {$key eq "space"} {
        event generate $w <<NextWindow>>
    }
    if {$key in {1 2 3 4 5 6 7 8 9}} {
        if {[string is integer -strict $row]} {
            event generate $w <<NextWindow>>
            return
        }
        if {[string length $KBRD($row,$col)] >= 2} {
            event generate $w <<NextWindow>>
            return
        }
        return
    }
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
proc ::KPV::GetBoard {} {
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

    clipboard clear
    clipboard append $result
    return $result
}
proc ::KPV::Blob {size} {
    variable KBRD
    variable KTOP
    variable currentBlob
    variable blobSelected

    ::KPV::Layout $size

    set currentBlob 0
    ::KPV::ChangeCurrentBlob $currentBlob

    array unset KBRD blob,*,cells
    set blobSelected {}

    foreach row $KBRD(indices) {
        set KBRD(blob,$row) 0
        set KBRD(blob,$row,cells) {}
        foreach col $KBRD(indices) {
            set w $KTOP.$row,$col
            bind $w <Shift-Button-1> [list ::KPV::MouseDownBlob $row $col]
            bind $w <Shift-Button-$::S(button,right)> [list ::KPV::MouseDownUnBlob $row $col]
            # bind $w <Shift-Button-$::S(button,right)> [list ::KPV::MouseDownSelect $w $row $col]
        }
    }
}
proc ::KPV::MouseDownSelect {w row col} {
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
proc ::KPV::MouseDownUnBlob {row col} {
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
proc ::KPV::MouseDownBlob {row col} {
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
        ::KPV::GetBoard
        set messages "board copied\nto clipboard"
        set currentBlob 0
    }
    ::KPV::ChangeCurrentBlob $currentBlob
}
proc ::KPV::ChangeCurrentBlob {whichBlob} {
    variable KTOP
    variable KBRD

    set color [lindex $::COLOR(blobs) $whichBlob]
    $KTOP.blobsums.m1 config -bg $color -text "Current Blob #$whichBlob"

    set bg [lindex [$KTOP.blobsums.bs0 config -bg] 3]
    foreach id $KBRD(indices) {
        $KTOP.blobsums.bs$id config -bg $bg
    }
    if {$whichBlob < $KBRD(size)} {
        $KTOP.blobsums.bs$whichBlob config -bg $color
    }

}
proc ::KPV::GetCellsInSlice {sliceType whichSlice} {
    variable KBRD

    if {$sliceType eq "row"} {
        set result [lmap x $KBRD(indices) { list $whichSlice $x}]
    } elseif {$sliceType eq "col"} {
        set result [lmap x $KBRD(indices) { list $x $whichSlice}]
    } else {
        set result $KBRD(blob,$whichSlice,cells)
    }


}
proc ::KPV::ComputeSums {} {
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
            foreach cell [::KPV::GetCellsInSlice $sliceType $whichSlice] {
                if {$cell in $blobSelected} {
                    lassign $cell row col
                    incr KBRD($sliceType,$whichSlice) $KBRD($row,$col)
                }
            }
            puts "KPV: KBRD($sliceType,$whichSlice) -> $KBRD($sliceType,$whichSlice)"
        }
    }
}

# proc ::KPV::xBlob {{action init} {row ?} {col ?}} {
#     # Manual way to create blobs for an existing board
#     #   % ::KPV::Blob init
#     #   left click to form blobs (it will detect when to start new blob)
#     #   % ::KPV::Blob data -> data for the board
#     #   manually fill in the blob targets
#     global BRD
#     global kpvBlobId
#     global kpvBlobCells
#     global kpvBlobTargets

#     if {$action eq "init"} {
#         destroy .blob
#         entry .blob -font $::B(font,grid) -width 2 -relief solid -justify c
#         place .blob -x 50 -y 50 -anchor nw

#         set kpvBlobId -1
#         array unset kpvBlobCells
#         array unset kpvBlobTargets
#         foreach row $BRD(indices) {
#             set kpvBlobCells($row) {}
#             foreach col $BRD(indices) {
#                 set tagBox grid_${row}_$col
#                 .c bind $tagBox <ButtonRelease-1> \
#                     [list ::KPV::Blob "add" $row $col]
#                 if {"$row,$col" in [::NewBoard::GetSolution]} {
#                     ::Explode::Explode $row $col
#                 }
#             }
#         }
#         ::KPV::Blob next
#         return
#     }
#     if {$action eq "next"} {
#         incr kpvBlobId
#         if {$kpvBlobId < $BRD(size)} {
#             set kpvBlobTargets($kpvBlobId) $kpvBlobId
#             if {$BRD(solvable)} {
#                 set kpvBlobTargets($kpvBlobId) 0
#             }
#             .blob config -bg [lindex $::COLOR(blobs) $kpvBlobId]
#             .blob config -textvariable kpvBlobTargets($kpvBlobId)
#         } else {
#             set data [::KPV::Blob data]
#             clipboard clear ; clipboard append $data
#             puts $data
#             puts "KPV: complete board -- data copied to the clipboard"
#         }
#         return
#     }
#     if {$action eq "data"} {
#         set result [join $::BB "\n"]
#         append result "\n\n"

#         foreach id $BRD(indices) {
#             if {$kpvBlobCells($id) eq {}} continue
#             set cells [lsort $kpvBlobCells($id)]
#             set line "blob $kpvBlobTargets($id) $cells\n"
#             append result $line
#         }
#         destroy .blob
#         return $result
#     }
#     if {$action eq "add"} {
#         set cell [list $row $col]
#         if {$cell in $kpvBlobCells($kpvBlobId)} {
#             puts "KPV: duplicate cell $cell"
#             return
#         }
#         lappend kpvBlobCells($kpvBlobId) [list $row $col]
#         if {"$row,$col" in [::NewBoard::GetSolution]} {
#             incr kpvBlobTargets($kpvBlobId) [lindex $BRD($row,$col) 0]
#         }

#         set tagBg bg_${row}_$col
#         .c itemconfig $tagBg -fill [lindex $::COLOR(blobs) $kpvBlobId]
#         if {[llength $kpvBlobCells($kpvBlobId)] == $::BRD(size)} {
#             puts "KPV: blob is full-sized -- moving to next"
#             ::KPV::Blob next
#         }
#         return
#     }
#     error "unknown ::KPV::Blob action: '$action'"
# }

# ::KPV::Layout 8

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
