#!/usr/bin/tclsh
source algo.tcl

set VAR(a,type) integer
set VAR(a,value) 12
set VAR(b,type) alnum
set VAR(b,value) "helloe"
set VAR(c,type) double
set VAR(c,value) 1.1

set ARRAY(table,type) double
set ARRAY(table,value) 1.1
set ARRAY(table,type) double
set ARRAY(table,value) 1.1

set FUNCTION(square,type) double

# We write a test
if {[REMOVE_SPACE {    0  1   2    3         4                 5           6   78 9}] == "0123456789"} {puts REMOVE_SPACE.OK} else {error REMOVE_SPACE.FAILED}

if {[GET_ARG {string, int   ,   integer,   234,11} ,] == "string int integer 234 11"} {puts GET_ARG.OK} else {error GET_ARG.FAILED}

if {[GET_ARG {string,int,integer,234,11} ,] == "string int integer 234 11"} {puts GET_ARG.OK} else {error GET_ARG.FAILED}

if {[GET_EXPR {1+2/9  -  3   +4    *   0.5 * a * b - #STRING1#}] == {integer 1 operator + integer 2 operator / integer 9 operator - integer 3 operator + integer 4 operator * double 0.5 operator * integer {$a} operator * alnum {$b} operator - ascii #STRING1#}} {puts GET_EXPR.OK} else {puts GET_EXPR.FAILED}

if {[GET_EXPR {1+2/9-3+4*5*c*b-#STRING1#}] == {integer 1 operator + integer 2 operator / integer 9 operator - integer 3 operator + integer 4 operator * integer 5 operator * double {$c} operator * alnum {$b} operator - ascii #STRING1#}} {puts GET_EXPR.OK} else {puts GET_EXPR.FAILED}

if {[GET_CALCUL {1.0+2/     9-3+4*5*c}] == {[expr 1.0+2/9-3+4*5*$c]}} {puts GET_CALCUL.OK} else {puts GET_CALCUL.FAILED}

if {[DEL_COMMENT "#hello\n#hi\nhow"] == "\n\nhow"} {puts DEL_COMMENT.OK} else {puts DEL_COMMENT.FAILED}

set text {hello "bonjour" "toto" jean "hi"}
set data [GET_STRING $text]
if {[lindex $data 0] == {hello "#STRING1#" "#STRING2#" jean "#STRING3#"}} {puts GET_STRING.OK} else {GET_STRING.FAILED}
if {[REVERSE_GET_CONTAINS [lindex $data 0] [lindex $data 1]] == $text} {puts REVERSE_GET_CONTAINS.OK} else {REVERSE_GET_CONTAINS.FAILED}

if {[IS_VAR a] != ""} {puts IS_VAR.OK} else {puts IS_VAR.FAILED}
if {[IS_VAR nnnnn] == ""} {puts IS_VAR.OK} else {puts IS_VAR.FAILED}

if {[IS_ARRAY {table[1]}] != ""} {puts IS_ARRAY.OK} else {puts IS_ARRAY.FAILED}
if {[IS_ARRAY {table[0*1*2*3][0+1+2+3][0-1-2-3][0/1/2/3][0+1*2/3-4]}] != ""} {puts IS_ARRAY.OK} else {puts IS_ARRAY.FAILED}
if {[IS_ARRAY {table[1][1]}] != ""} {puts IS_ARRAY.OK} else {puts IS_ARRAY.FAILED}
if {[IS_ARRAY {table[1][table[1]][table[1]]}] != ""} {puts IS_ARRAY.OK} else {puts IS_ARRAY.FAILED}
# In this test, we use REMOVE_SPACE because this function is called before some operating
if {[IS_ARRAY [REMOVE_SPACE {table[1+2+3][table[1*2   *     4   ]][table[1/2*4]]}]] != ""} {puts IS_ARRAY.OK} else {puts IS_ARRAY.FAILED}
if {[IS_ARRAY a] == ""} {puts IS_ARRAY.OK} else {puts IS_ARRAY.FAILED}

if {[IS_FUNCTION square()] != ""} {puts IS_FUNCTION.OK} else {puts IS_FUNCTION.FAILED}
if {[IS_FUNCTION square(2)] != ""} {puts IS_FUNCTION.OK} else {puts IS_FUNCTION.FAILED}
if {[IS_FUNCTION square(1,2,3,4)] != ""} {puts IS_FUNCTION.OK} else {puts IS_FUNCTION.FAILED}
if {[IS_FUNCTION square(2,square(2,square(2,2),square(3,3),square(3,3,square(3,3))),2)] != ""} {puts IS_FUNCTION.OK} else {puts IS_FUNCTION.FAILED}
if {[IS_FUNCTION a] == ""} {puts IS_FUNCTION.OK} else {puts IS_FUNCTION.FAILED}

puts "TOOLS TEST FINISHED"