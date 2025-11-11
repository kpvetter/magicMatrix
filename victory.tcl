#!/bin/sh
# Restart with tcl: -*- mode: tcl; tab-width: 8; -*- \
exec tclsh $0 ${1+"$@"}

##+##########################################################################
#
# victory.tcl -- animation when you solve the puzzle
# by Keith Vetter 2025-09-10
#

namespace eval ::Victory {
    variable config
    set config(after,delay) 100
    set config(duration,milliseconds) 2000
    set config(aid) ""
    set config(aid,stop) ""
    set config(aid,finished) ""
    set config(message,growthRate) 20
    set config(sparkle,types) [list random randomOneColor black&white swoopR swoopL brw]
    set config(sparkle,type) "?"
    set config(sparkle,colors) [list white black]
    set config(counter) 0

}

proc ::Victory::Victory {{type ?}} {
    variable config

    .c lower canvas_bg
    ::Cutthroat::Display True
    ::Victory::SetupColors $type
    set msg [::Victory::Message]
    set tags [lmap x [::NewBoard::GetSolution] {regsub {(.),(.)} $x {circle_\1_\2}}]
    foreach row $::BRD(indices) {
        lappend tags "bg_row_$row"
        lappend tags "bg_col_$row"
        foreach col $::BRD(indices) {
            lappend tags "bg_${row}_$col"
        }
    }
    set config(counter) 0
    set config(aid,stop) [after $config(duration,milliseconds) ::Victory::Stop some]
    set config(aid,finished) [after $config(duration,milliseconds) .c itemconfig finished -text $msg]

    ::Victory::Sparkle $tags
    return $config(sparkle,type)
}
proc ::Victory::GetColor {tag} {
    variable config
    if {$config(sparkle,type) eq "random"} {
        set r [expr {int (255 * rand())}]
        set g [expr {int (255 * rand())}]
        set b [expr {int (255 * rand())}]
        return [format "\#%02x%02x%02x" $r $g $b]
    }
    if {$config(sparkle,type) eq "randomOneColor"} {
        return [lpick $config(sparkle,colors)]
    }
    set dir -1
    set dir [expr {$config(sparkle,type) eq "swoopL" ? 1 : -1}]

    set modulus [llength $config(sparkle,colors)]
    lassign [split $tag "_"] _ row col
    if {$row in {"row" "col"}} {
        set n [expr {($col + $dir * $config(counter) + 1) % $modulus}]
    } else {
        set n [expr {($row + $col + $dir * $config(counter)) % $modulus}]
    }
    set color [lindex $config(sparkle,colors) $n]
    return $color
}
proc ::Victory::Sparkle {tags} {
    variable config
    incr config(counter)

    foreach tag $tags {
        # set color [::Victory::RandomColor $tag]
        set color [::Victory::GetColor $tag]
        .c itemconfig $tag -fill $color
    }

    # Increase the font size of the victory message
    set size [font actual [.c itemcget victory -font] -size]
    set targetSize [font actual $::B(font,victory) -size]
    set newSize [expr {min($targetSize, $size + $config(message,growthRate))}]
    .c itemconfig victory -font "$::B(font,victory) -size $newSize"
    .c raise victory

    set config(aid) [after $config(after,delay) [list ::Victory::Sparkle $tags]]
}
proc ::Victory::Message {} {
    # Display a big banner showing success
    variable config
    global B

    set text " Solved! "
    if {$::BRD(lives,remaining) == $::BRD(lives,total)} {
        set text " Perfect! "
    }
    set font "$::B(font,victory) -size 30"

    .c create text $B(width2) $B(height2) -text $text -fill black \
        -anchor c -font $font -tag victory
    .c create text $B(width2) $B(height2) -text $text -fill red \
        -anchor c -font $font -tag {victory victory2}
    .c move victory2 6 9
    return [string trim $text]
}
proc ::Victory::Stop {what} {
    # Force victory sequence to stop
    variable config

    after cancel $config(aid,stop)
    after cancel $config(aid)
    .c itemconfig bg -fill $::COLOR(game,over)
    .c itemconfig bg2 -fill $::COLOR(TSTATE_DONE)
    .c itemconfig victory2 -fill red
    .c itemconfig blobBox -fill $::COLOR(game,over)
    .c lower blob
    after 500 .c delete victory

    if {$what eq "all"} {
        after cancel $config(aid,finished)
        .c itemconfig finished -text ""
    }
}
proc ::Victory::SetupColors {{type ?}} {
    variable config

    if {$type ni $config(sparkle,types)} {
        set config(sparkle,type) [lpick $config(sparkle,types)]
    } else {
        set config(sparkle,type) $type
    }

    if {$config(sparkle,type) eq "random"} return
    if {$config(sparkle,type) eq "black&white"} {
        set config(sparkle,colors) [list black white]
        return
    }
    if {$config(sparkle,type) eq "brw"} {
        set config(sparkle,colors) [list red white blue]
        return
    }
    if {$config(sparkle,type) eq "randomOneColor"} {
        set steps [expr {$config(duration,milliseconds) / $config(after,delay) / 2}]
    } else {
        set steps [expr {$config(duration,milliseconds) / $config(after,delay)}]
    }
    set baseColor [lpick [list black yellow red blue green magenta]]
    set config(sparkle,colors) {}
    for {set i 0} {$i < $steps} {incr i} {
        set percent [expr {0 + 200 * $i / ($steps - 1)}]
        set color [::tk::Darken $baseColor $percent]
        lappend config(sparkle,colors) $color
    }
}
