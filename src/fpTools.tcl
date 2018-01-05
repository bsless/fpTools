# -*- mode: Tcl -*-
# fpTools.tcl --
#
# Description:
#     This package provides some basic functional programming tools for Tcl
#
# Copyright:
#
# License:
#
# Revision: 1
#
# $Id$

package provide fpTools 0.1

namespace eval fpTools {

    namespace export *

    proc head {l} {return [lindex $l 0]}
    proc tail {l} {return [lrange $l 1 end]}
    proc identity {x} {return $x}

    # memoize a function call
    # http://wiki.tcl.tk/10779
    proc memo args {
        if {[info exists ::MEMO($args)]} {
            set ::MEMO($args)
        } else {
            set ::MEMO($args) [uplevel 1 $args]
        }
    }

    # auto-memoize a function -- it should not use return
    # http://wiki.tcl.tk/10779
    proc memoproc {name argv body} {
        set b "set _k_ \[list [list $name]\]; "
        foreach pair $argv {
            append b "lappend _k_ \$[list [lindex $pair 0]]; "
        }

        append b "
        if {\[info exists ::MEMO(\$_k_)\]} {
            set ::MEMO(\$_k_)
        } else {
            set ::MEMO(\$_k_) \[ $body \]
        }
    "
        proc $name $argv $b
    }

    ### proc lmap
    ### USAGE:
    ##        lmap varname list body
    ##        lmap varlist1 list1 ?varlist2 list2 ...? body
    ## See: https://wiki.tcl-lang.org/13920

    if {[info tclversion] < 8.6} {
        proc lmap args {
            set body [lindex $args end]
            set args [lrange $args 0 end-1]
            set n 0
            set pairs [list]
            foreach {varnames listval} $args {
                set varlist [list]
                foreach varname $varnames {
                    upvar 1 $varname var$n
                    lappend varlist var$n
                    incr n
                }
                lappend pairs $varlist $listval
            }
            set temp [list]
            foreach {*}$pairs {
                lappend temp [uplevel 1 $body]
            }
            set temp
        }
    }

    proc fmap {functions x}  {lmap f $functions {$f $x}}

    ### proc let
    ### USAGE:
    ##        let {var1 {body1}} ?{var2 {body2}}? body
    ##        Similar to Scheme's let

    proc let args {
        set body [lindex $args end]
        set args [lrange $args 0 end-1]
        set pairs [list]
        foreach pair $args {
            lassign $pair varname expression
            set h [head [split $expression]]
            set cmd_q [info commands $h]
            set proc_q [info procs $h]
            set $varname [expr {( $cmd_q != {} ) || ( $proc_q != {} ) ? [eval $expression] : $expression }]
        }
        return [eval $body]
    }

    ### lcomp:
    ### USAGE:
    ##     set l {1 2 3 4 5 6}
    ##     puts "A copy of the list: [lcomp {$i} for i in $l]"
    ##     puts "Double values from list: [lcomp {$n * 2} for n in $l]"
    ##     puts "Only even numbers: [lcomp {$i} for i in $l if {$i % 2 == 0}]"
    ##     proc digits {str} {
    ##         lcomp {$d} for d in [split $str ""] if {[string is digit $d]}
    ##     }
    ##     puts "Just digits from (703)-999-0012= [digits (703)-999-0012]"
    ##     set names1 {Todd Coram Bob Jones Tim Druid}
    ##     puts "From ($names1): Last,first = [lcomp {"$l,$f"} for {f l} in $names1]"
    ##     puts "From ($names1): Only names starting with 't':\
    ##         [lcomp {$f} for {f l} in $names1 if {[string match T* $f]}]"
    ##     puts "Create a matrix pairing {a b c} and {1 2 3}:\
    ##         [lcomp {[list $n1 $n2]} for n1 in {a b c} for n2 in {1 2 3}]"
    ##     lcomp {$x} for x in {0 1 2 3}                         ;# 0 1 2 3
    ##     lcomp {[list $y $x]} for {x y} in {0 1 2 3}           ;# {1 0} {3 2}
    ##     lcomp {$x ** 2} for x in {0 1 2 3}                    ;# 0 1 4 9
    ##     lcomp {$x + $y} for x in {0 1 2 3} for y in {0 1 2 3} ;# 0 1 2 3 1 2 3 4 2 3 4 5 3 4 5 6
    ##     lcomp {$x} for x in {0 1 2 3} if {$x % 2 == 0}        ;# 0 2
    ##     image delete {*}[lcomp {$val} for {key val} in [array get images]]
    ##     set scale 2
    ##     lcomp {$x * $scale} with scale for x in {1 2 3 4}            ;# 2 4 6 8
    ##     lcomp {$key} {$val} for key in {a b c} and val in {1 2 3}    ;# a 1 b 2 c 3
    ##     lcomp {"$key=$val"} for {key val} inside {{a 1} {b 2} {c 3}} ;# a=1 b=2 c=3
    ##
    ## See: http://wiki.tcl.tk/12574

    proc lcomp {expression args} {
        set __0__ "lappend __1__ \[expr [list $expression]\]"
        while {[llength $args] && [lindex $args 0] ni {for if with}} {
            append __0__ " \[expr [list [lindex $args 0]]\]"
            set args [lrange $args 1 end]
        }
        set tmpvar 2
        set structure {}
        set upvars {}
        while {[llength $args]} {
            set prefix ""
            switch [lindex $args 0] {
                for {
                    set nest [list foreach]
                    while {[llength $nest] == 1 || [lindex $args 0] eq "and"} {
                        if {[llength $args] < 4 || [lindex $args 2] ni {in inside}} {
                            error "wrong # operands: must be \"for\" vars \"in?side?\"\
                                    vals ?\"and\" vars \"in?side?\" vals? ?...?"
                        }
                        switch [lindex $args 2] {
                            in {
                                lappend nest [lindex $args 1] [lindex $args 3]
                            } inside {
                                lappend nest __${tmpvar}__ [lindex $args 3]
                                append prefix "lassign \$__${tmpvar}__ [lindex $args 1]\n"
                                incr tmpvar
                            }}
                        set args [lrange $args 4 end]
                    }
                    lappend structure $nest $prefix
                } if {
                      if {[llength $args] < 2} {
                          error "wrong # operands: must be \"if\" condition"
                      }
                      lappend structure [list if [lindex $args 1]] $prefix
                      set args [lrange $args 2 end]
                  } with {
                      if {[llength $args] < 2} {
                          error "wrong # operands: must be \"with\" varlist"
                      }
                      foreach var [lindex $args 1] {
                          lappend upvars $var $var
                      }
                      set args [lrange $args 2 end]
                  } default {
                      error "bad opcode \"[lindex $args 0]\": must be for, if, or with"
                  }}
        }
        foreach {prefix nest} [lreverse $structure] {
            set __0__ [concat $nest [list \n$prefix$__0__]]
        }
        if {[llength $upvars]} {
            set __0__ "upvar 1 $upvars; $__0__"
        }
        unset -nocomplain expression args tmpvar prefix nest structure var upvars
        set __1__ ""
        eval $__0__
        return $__1__
    }

    # http://wiki.tcl.tk/3307
    proc lzip {args} {
        if {[llength $args]} {
            for {set i 0} {$i < [llength $args]} {incr i} {
                append expression " \$$i"
                lappend operations and $i in [lindex $args $i]
            }
            lset operations 0 for
            lcomp \[list$expression\] {*}$operations
        }
    }

    # http://wiki.tcl.tk/17983
    proc foldl {lambda args} {
        set argc [llength $args]
        if {($argc > 2) || ($argc < 1)} {error {wrong # args: should be "foldl lambda ?init? ls"}}
        if {$argc == 2} \
            then {
                foreach {init ls} $args break
            } \
            else {
                set ls   [lindex $args 0]
                set init [lindex $ls 0]
                set ls   [lrange $ls 1 end]
            }
        foreach el $ls {set init [eval apply [list $lambda] [list $init] [list $el]]}
        return $init
    }

    proc lpad {llist length {pad {}}} {
        return [expr {[llength $llist] < $length ? \
                          [ concat $llist [ lrepeat [expr $length - [llength $llist]] $pad ] ] : \
                          $llist}]
    }


    proc groupby {xs {keyfunc identity}} {
        set pkey [eval $keyfunc [head $xs]]
        set res [list]
        lappend res $pkey
        set group [list]
        foreach x $xs {
            set key [eval $keyfunc $x]
            if {$key != $pkey} {
                lappend res $group
                lappend res $key
                set group [list]
            }
            lappend group $x
            set pkey $key
        }
        lappend res $group
        return $res
    }

    proc hashby {xs {keyfunc identity}} {
        foreach x $xs {dict append d [$keyfunc $x] $x}
        return $d
    }

}
