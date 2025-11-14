#!/bin/sh
# Restart with tcl: -*- mode: tcl; tab-width: 8; -*- \
exec tclsh $0 ${1+"$@"}

##+##########################################################################
#
# kpv.tcl -- code to create magic matrices from existing sources
# by Keith Vetter 2025-11-12
#

namespace eval ::KPV {
    variable KBRD

    variable KTOP .kpv
    variable blobId
    variable blobCells
    variable blobSumValues
    variable messages "-"

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

    unset -nocomplain KBRD
    set KBRD(size) $size
    for {set i 0} {$i < $size} {incr i} { lappend KBRD(indices) $i }

    set grow 0
    set gcol 1
    foreach col $KBRD(indices) {
        set w $KTOP.col,$col
        entry $w -textvariable ::KPV::KBRD(col,$col) -width 2 -justify c
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
        entry $w -textvariable ::KPV::KBRD(row,$row) -width 2 -justify c
        grid $w -row $grow -column $gcol -padx {0 .1i}

        bindtags $w [list Entry $w all]
        bind $w <Key> [list ::KPV::KeyBinding $w row $row %K]

        foreach col $KBRD(indices) {
            incr gcol
            set w $KTOP.$row,$col
            entry $w -textvariable ::KPV::KBRD($row,$col) -width 2 -justify c
            grid $w -row $grow -column $gcol

            # bindtags $w [list Entry $w all]
            # foreach digit {1 2 3 4 5 6 7 8 9} {
            #     bind $w $digit [list event generate $w <<NextWindow>>]
            # }
            bindtags $w [list Entry $w all]
            bind $w <Key> [list ::KPV::KeyBinding $w $row $col %K]
        }
    }
    ::ttk::frame $KTOP.bottom
    grid $KTOP.bottom -row 100 -columnspan [expr {$size + 1}] -pady {.2i 0}

    label $KTOP.m1 -text "Current blob #0"
    entry $KTOP.m2 -textvariable ::KPV::blobSumValue(0) -width 2 -justify c
    grid $KTOP.m1 $KTOP.m2 -in $KTOP.bottom -sticky ew

    label $KTOP.msgs -textvariable ::KPV::messages -height 2
    grid $KTOP.msgs -in $KTOP.bottom -columnspan 2 -sticky ew

    ::ttk::button $KTOP.data -text "Copy to Clipboard" -command ::KPV::GetBoard
    grid $KTOP.data -in $KTOP.bottom -columnspan 2

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
    variable blobCells
    variable blobSumValues

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
        set line "blob $blobSumValues($id) $blobCells($id)\n"
        append result $line
    }

    clipboard clear
    clipboard append $result
    return $result
}
proc ::KPV::Blob {size} {
    variable KBRD
    variable KTOP
    variable blobId
    variable blobCells
    variable blobSumValues

    ::KPV::Layout $size

    set blobId 0
    ::KPV::ShowCurrentBlob

    array unset blobCells
    array unset blobSumValues

    foreach row $KBRD(indices) {
        set blobCells($row) {}
        set blobSumValues($row) 0
        foreach col $KBRD(indices) {
            set w $KTOP.$row,$col
            bind $w <ButtonRelease-1> [list ::KPV::MouseDown $row $col]
        }
    }
}
proc ::KPV::MouseDown {row col} {
    variable KBRD
    variable KTOP
    variable blobId
    variable blobCells
    variable messages

    set w $KTOP.$row,$col
    set cell [list $row $col]
    if {$cell in $blobCells($blobId)} {
        set messages "duplicate cell $cell\nignoring"
        return
    }
    lappend blobCells($blobId) $cell
    set color [lindex $::COLOR(blobs) $blobId]
    $w config -bg $color

    if {[llength $blobCells($blobId)] < $KBRD(size)} return
    set messages "blob is full-sized\nmoving to next"

    incr blobId
    ::KPV::ShowCurrentBlob

    if {$blobId == $KBRD(size)} {
        ::KPV::GetBoard
        set messages "board copied\nto clipboard"
    }
}
proc ::KPV::ShowCurrentBlob {} {
    variable KTOP
    variable blobId
    variable blobSumValues

    set color [lindex $::COLOR(blobs) $blobId]
    $KTOP.m1 config -bg $color -text "Current Blob #$blobId"
    $KTOP.m2 config -textvariable ::KPV::blobSumValues($blobId)
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
return
proc foo {args} {
    puts ""
    foreach {a b} $args { puts -nonewline "$a: '$b' "}
    puts ""
}
bind .top <Key> [list foo %%K %K %%k %k %%A %A %%N %N]
