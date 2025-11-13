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

    variable kpvBlobId
    variable kpvBlobCells
    variable kpvBlobTargets

}
proc ::KPV::Layout {{size ?}} {
    variable KBRD

    set TOP .kpv
    destroy $TOP
    toplevel $TOP
    wm geom $TOP +200+200

    if {$size eq "?"} {
        set size $::BRD(size)
    }

    unset -nocomplain KBRD
    set KBRD(size) $size
    for {set i 0} {$i < $size} {incr i} { lappend KBRD(indices) $i }
    puts "KPV: [array names KBRD]"

    set grow 0
    set gcol 1
    foreach col $KBRD(indices) {
        set w $TOP.col,$gcol
        entry $w -textvariable ::KPV::KBRD(col,$col) -width 2 -justify c
        bind $w <Key-space> [list event generate $w <<NextWindow>> ]
        grid $w -row $grow -column $gcol -pady {0 .1i}
        incr gcol
    }
    foreach row $KBRD(indices) {
        incr grow
        set gcol 0
        set w $TOP.row,$grow
        entry $w -textvariable ::KPV::KBRD(row,$row) -width 2 -justify c
        bind $w <Key-space> [list event generate $w <<NextWindow>> ]
        grid $w -row $grow -column $gcol -padx {0 .1i}
        foreach col $KBRD(indices) {
            incr gcol
            set w $TOP.$row,$col
            entry $w -textvariable ::KPV::KBRD($row,$col) -width 2 -justify c
            grid $w -row $grow -column $gcol
            bind $w <Key-space> [list event generate $w <<NextWindow>> ]
        }
    }

    ::ttk::button $TOP.data -text "Copy to Clipboard" -command ::KPV::GetBoard
    grid $TOP.data -row 100 -columnspan [expr {$size + 1}] -pady .2i
}
proc ::KPV::GetBoard {} {
    variable KBRD

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
    clipboard clear
    clipboard append $result
    return $result
}
proc ::KPV::Blob {{action init} {row ?} {col ?}} {
    # Manual way to create blobs for an existing board
    #   % ::KPV::Blob init
    #   left click to form blobs (it will detect when to start new blob)
    #   % ::KPV::Blob data -> data for the board
    #   manually fill in the blob targets
    global BRD
    variable kpvBlobId
    variable kpvBlobCells
    variable kpvBlobTargets

    if {$action eq "init"} {
        destroy .blob
        entry .blob -font $::B(font,grid) -width 2 -relief solid -justify c
        place .blob -x 50 -y 50 -anchor nw

        set kpvBlobId -1
        array unset kpvBlobCells
        array unset kpvBlobTargets
        foreach row $BRD(indices) {
            set kpvBlobCells($row) {}
            foreach col $BRD(indices) {
                set tagBox grid_${row}_$col
                .c bind $tagBox <ButtonRelease-1> \
                    [list ::KPV::Blob "add" $row $col]
                if {"$row,$col" in [::NewBoard::GetSolution]} {
                    ::Explode::Explode $row $col
                }
            }
        }
        ::KPV::Blob next
        return
    }
    if {$action eq "next"} {
        incr kpvBlobId
        if {$kpvBlobId < $BRD(size)} {
            set kpvBlobTargets($kpvBlobId) $kpvBlobId
            if {$BRD(solvable)} {
                set kpvBlobTargets($kpvBlobId) 0
            }
            .blob config -bg [lindex $::COLOR(blobs) $kpvBlobId]
            .blob config -textvariable kpvBlobTargets($kpvBlobId)
        } else {
            set data [::KPV::Blob data]
            clipboard clear ; clipboard append $data
            puts $data
            puts "KPV: complete board -- data copied to the clipboard"
        }
        return
    }
    if {$action eq "data"} {
        set result [join $::BB "\n"]
        append result "\n\n"

        foreach id $BRD(indices) {
            if {$kpvBlobCells($id) eq {}} continue
            set cells [lsort $kpvBlobCells($id)]
            set line "blob $kpvBlobTargets($id) $cells\n"
            append result $line
        }
        destroy .blob
        return $result
    }
    if {$action eq "add"} {
        set cell [list $row $col]
        if {$cell in $kpvBlobCells($kpvBlobId)} {
            puts "KPV: duplicate cell $cell"
            return
        }
        lappend kpvBlobCells($kpvBlobId) [list $row $col]
        if {"$row,$col" in [::NewBoard::GetSolution]} {
            incr kpvBlobTargets($kpvBlobId) [lindex $BRD($row,$col) 0]
        }

        set tagBg bg_${row}_$col
        .c itemconfig $tagBg -fill [lindex $::COLOR(blobs) $kpvBlobId]
        if {[llength $kpvBlobCells($kpvBlobId)] == $::BRD(size)} {
            puts "KPV: blob is full-sized -- moving to next"
            ::KPV::Blob next
        }
        return
    }
    error "unknown ::KPV::Blob action: '$action'"
}

# ::KPV::Layout 8
return
