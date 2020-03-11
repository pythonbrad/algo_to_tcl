#!/usr/bin/tclsh
source algo.tcl

set VAR(a,type) integer
set VAR(a,value) 12
set VAR(b,type) alnum
set VAR(b,value) "helloe"
set VAR(c,type) double
set VAR(c,value) 1.1

# We write a test
if {[GET_ARG {string, int   ,   integer,   234,11} ,] == "string int integer 234 11"} {puts GET_ARG.OK} else {error GET_ARG.FAILED}
if {[GET_ARG {string,int,integer,234,11} ,] == "string int integer 234 11"} {puts GET_ARG.OK} else {error GET_ARG.FAILED}
if {[GET_EXPR {1+2/9  -  3   +4    *   0.5 * a * b - #STRING1#}] == {integer 1 operator + integer 2 operator / integer 9 operator - integer 3 operator + integer 4 operator * double 0.5 operator * integer {$a} operator * alnum {$b} operator - ascii #STRING1#}} {puts GET_EXPR.OK} else {puts GET_EXPR.FAILED}
if {[GET_EXPR {1+2/9-3+4*5*c*b-#STRING1#}] == {integer 1 operator + integer 2 operator / integer 9 operator - integer 3 operator + integer 4 operator * integer 5 operator * double {$c} operator * alnum {$b} operator - ascii #STRING1#}} {puts GET_EXPR.OK} else {puts GET_EXPR.FAILED}
if {[GET_CALCUL {1.0+2/     9-3+4*5*c}] == {[expr 1.0+2/9-3+4*5*$c]}} {puts GET_CALCUL.OK} else {puts GET_CALCUL.FAILED}
if {[DEL_COMMENT "#hello\n#hi\nhow"] == "\n\nhow"} {puts DEL_COMMENT.OK} else {puts DEL_COMMENT.FAILED}


puts "TEST FINISHED"