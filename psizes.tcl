#!/bin/sh
# Restart with tcl: -*- mode: tcl; tab-width: 8; -*- \
exec tclsh $0 ${1+"$@"}

##+##########################################################################
#
# psizes.tcl -- <description>
# by Keith Vetter 2025-11-20
#

#package require Tk
catch {wm withdraw .}

proc DoSizes {WSIZE} {
    ::ttk::label $WSIZE.title -text "Puzzle Sizes" -font $::B(font,settings,heading)
    grid $WSIZE.title -

    set row 1
    set col 0

    foreach size $::Settings::BOARD_SIZES(all) {
        set w $WSIZE.rb_$size
        ::ttk::checkbutton $w -variable ::Settings::BOARD_SIZES($size) -text $size
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
    grid $WSIZE.all0 $WSIZE.all1 -pady .2i
    grid $WSIZE.go -
}

namespace eval ::Settings {
    variable BOARD_SIZES
    set BOARD_SIZES(all) {"2 squares" "3 squares" "4 squares" "5 squares" \
                              "6 squares" "7 squares" "8 squares" "9 squares"}
}

set S(button,right) 3
set B(font,settings,heading) {-family .AppleSystemUIFont -size 10 -weight normal -slant roman -underline 0 -overstrike 0 -size 24 -weight bold}
set WSIZE .top
destroy $WSIZE
toplevel $WSIZE
DoSizes $WSIZE
