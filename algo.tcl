#!/usr/bin/tclsh
# Should be compatible with tclsh and jimsh for the console
#mettre int a get calcul pour les arrray
#ou bien laisser et creer un algo etudiant de ges de not comme a iht avec pour exploiter ca
# This var contains the list of operator valid, by other of priority
set OPERATORS "+ - / * == != <= >= < > % && & || |"
set TYPES "alnum alpha ascii control boolean digit double entier false integer list lower print punct space true upper wordchar xdigit"
set INTEGERS "integer entier digit"
set DOUBLES "$INTEGERS double"
# This var permit to know if verify data or not
set ignore 0

# This function remove comment
proc DEL_COMMENT code {
	set _code ""
	# We get line by line
	foreach c [split $code \n] {
		# We remove space left and right
		set c [string trim $c]
		if {[string index $c 0] == "#"} {
			set _code "$_code\n"
		} else {
			set _code "$_code\n$c"
		}
	}
	return [string range $_code 1 end]
}

# This function get sring in text
proc GET_STRING code {
	set open_quote 0
	set open_quote_id 0
	set count 0
	set data ""
	for {set i 0} {$i < [string length $code]} {incr i} {
		set char [string index $code $i]
		if {$char == "\""} {
			if $open_quote {
				incr count
				set open_quote 0
				lappend data [string range $code $open_quote_id $i] "#STRING$count#"
			} else {
				set open_quote 1
				set open_quote_id $i
			}
		} else {
			continue;
		}
	}
	foreach "value var" $data {
		# \"\" beetwen var to evit error if contains \n#
		set code [string map [list $value \"$var\"] $code]
	}
	return [list $code $data]
}

# This function get data in bracket
proc GET_CONTAINS {code open_tag close_tag} {
	set open_quote 0
	set open_quote_id 0
	set count 0
	set data ""
	for {set i 0} {$i < [string length $code]} {incr i} {
		set char [string index $code $i]
		if {$char == $open_tag} {
			if !$open_quote {
				set open_quote_id $i
			}
			incr open_quote
		} elseif {$char == $close_tag} {
			incr open_quote -1
			if !$open_quote {
				# We save the length of each data to sort after
				# We do it to evit any error, with a(1),a(a(1)) where we have a(#DATA1#),a(a(#DATA1#))
				set d [list [string range $code $open_quote_id $i] "#DATA$count#"]
				set _data([string length $d]) $d
				incr count
			}
		} else {
			continue;
		}
	}
	# We sort by length
	foreach e [lreverse [lsort [array names _data]]] {
		lappend data [lindex [array get _data $e] 1]
	}
	# We concat to remove sublist
	set data [eval concat $data]
	foreach "value var" $data {
		# like value contains open tag and close tag and this funtion should get only the contains
		# we add the open and close tag in var
		# it should be remove in the restore
		set code [string map [list $value "$open_tag$var$close_tag"] $code]
	}
	return [list $code $data]
}

proc REVERSE_GET_CONTAINS {c map} {
	# We restore the data
	foreach "value var" $map {
		set c [string map [list $var [string range $value 1 end-1]] $c]
	}
	return $c
}

# This function permit to get argument in an expression
# eg: GET_ARG {string, int   ,   integer,   234,11} --> {string int integer 234 11}
# eg: GET_ARG {a:  int} --> {a int}
proc GET_ARG {c sep} {
	# We modify the text before
	set c [string map "{ } {}" $c]
	set data [GET_CONTAINS $c "(" ")"]
	set c [eval concat [split [eval concat [split [lindex $data 0] $sep]]]]
	# We do it to evit error in the using as list
	set c [string map [list "\"" "\\\""] $c]
	return [REVERSE_GET_CONTAINS $c [lindex $data 1]]
}

# This function, verify if a var exist
proc IS_VAR {varname {line none}} {
	global VAR ignore
	if {[lsearch -exact [array names VAR] $varname,type] != -1 || $ignore & [string is wordchar $varname] & ![string is double $varname]} {
		set type [lindex [array get VAR $varname,type] 1]
		if {$ignore && $type == ""} {set type ascii}
		return $type
	} else {
		return
	}	
}

# This function, verify if an array exist
proc IS_ARRAY {varname {line none}} {
	global ARRAY INTEGERS ignore
	# We get contains in the bracket, to evit error in the continuous
	set data [GET_CONTAINS $varname "\[" "\]"]
	# We space the bracket
	set _data [string map "\[ { \[ } \] { \] }" [lindex $data 0]]
	set arrayname [lindex $_data 0]
	set index ""
	if {[lsearch -exact [array names ARRAY] $arrayname,type] != -1 || $ignore} {
		set type [lindex [array get ARRAY $arrayname,type] 1]
		if {$ignore && $type == ""} {set type ascii}
		set args [lrange $_data 1 end]
		if {$args != ""} {
			foreach "token1 id token3" [lrange $_data 1 end] {
				if {$token1 == "\[" && $token3 == "\]"} {
					# We restore the data save before
					set id [REVERSE_GET_CONTAINS $id [lindex $data 1]]
					if {$id != ""} {
						# index maybe an expression (var, array, calcul, ...)
						# We add in the list after the operation
						set index "$index,[GET_CALCUL $id $line]"
					} else {
						error "Error in the line $line, index empty"
					}
				} elseif $ignore {
					return
				} else {
					error "Error in line $line, syntax error"
				}
			}
		} else {
			return
		}
		# We construct the tcl name
		set arrayname $arrayname\([string range $index 1 end]\)
		return [list $arrayname $type]
	}
	return
}

# This function, verify if an function exist
proc IS_FUNCTION {function_name {line none}} {
	global FUNCTION ignore
	# We get contains in the bracket, to evit error in the continuous
	set data [GET_CONTAINS $function_name "(" ")"]
	# We space the bracket
	set _data [string map "( { ( } ) { ) }" [lindex $data 0]]
	set function_name [lindex $_data 0]
	set args ""
	if {[lsearch -exact [array names FUNCTION] $function_name,type] != -1 || $ignore} {
		set type [lindex [array get FUNCTION $function_name,type] 1]
		if {$ignore && $type == ""} {set type ascii}
		set token1 [lindex $_data 1]
		set arg [lindex $_data 2]
		set token3 [lindex $_data 3]
		if {$token1 == "(" && $token3 == ")"} {
			# We restore the data save before
			set arg [REVERSE_GET_CONTAINS $arg [lindex $data 1]]
			if {$arg != ""} {
				# arg maybe an expression (var, array, calcul, ...)
				# We add in the list after the operation
				foreach e [GET_ARG $arg ,] {
					set args "$args [GET_CALCUL $e $line]"
				}
			}
		} elseif $ignore {
			return
		} else {
			error "Error in line $line, syntax error"
		}
		# We construct the tcl name
		set function "\[$function_name $args\]"
		return [list $function $type]
	}
	return
}

# This function just conatins the structure tcl of the function read
proc READ_STRUCT {} {
	gets stdin _
	if {[string is %s $_] && [string length $_]} {
		set %s $_
	} else {
		error "Error in line %s, \"%s\" expected"
	}
}

# This function just contains the structure tcl of a affectation
proc AFFECTATION_STRUCT {} {
	set _ "%s"
	if [string is %s $_] {
		set %s $_
	} else {
		error "Error in line %s, \"%s\" expected"
	}
}

# This function just contains the structure tcl of the function VAR
proc VAR_STRUCT {} {
	set %s {}
}

# This function just contains the structure tcl of the function ARRAY
proc ARRAY_STRUCT {} {
	array set %s {}
}

# This function just contains the structure tcl of the function WRITE
proc WRITE_STRUCT {} {
	puts "%s"
}

# This function permit get all element in an expression
# And define the type
proc GET_EXPR {c {line none}} {
	global OPERATORS
	global TYPES
	set result ""
	set operator_map ""
	# We save the contains of bracket to evit error in the following
	set data1 [GET_CONTAINS $c "(" ")"]
	set data2 [GET_CONTAINS [lindex $data1 0] "\[" "\]"]
	set c [lindex $data2 0]
	set c [string map [list "\[" "\\\[" "\]" "\\\]"] "$c"]
	# We create the map
	foreach operator $OPERATORS {
		lappend operator_map $operator " $operator "
	}
	set c [eval concat [string map $operator_map "$c"]]
	# We restore the data save before
	set c [REVERSE_GET_CONTAINS $c [lindex $data2 1]]
	set c [REVERSE_GET_CONTAINS $c [lindex $data1 1]]
	foreach e $c {
		# We verify if is var or array or function
		set is_var 0
		set is_array 0
		set is_function 0
		set data [IS_VAR $e $line]
		if {$data != ""} {set is_var 1;set var_type $data}
		set data [IS_ARRAY $e $line]
		if {$data != ""} {
			set arrayname [lindex $data 0]
			set type [lindex $data 1]
			set is_array 1
		}
		set data [IS_FUNCTION $e $line]
		if {$data != ""} {
			set function [lindex $data 0]
			set type [lindex $data 1]
			set is_function 1
		}
		if [string is integer $e] {
			lappend result integer $e
		} elseif [string is double $e] {
			lappend result double $e
		} elseif {[string index $e 0] == "#"} {
			lappend result ascii $e
		} elseif {$is_var} {
			# We use -exact because without it, * can be considered like * in glob (* for all)
			if {[lsearch $TYPES $var_type] != -1} {
				lappend result $var_type $$e
			} else {
				error "Error in line $line, var \"$e\" detected but type \"$var_type\" unknowed"
			}
		} elseif {$is_array} {
			lappend result $type $$arrayname
		} elseif {$is_function} {
			lappend result $type $function
		} elseif {[lsearch $OPERATORS $e] != -1} {
			lappend result operator $e
		} else {
			error "Error in line $line, type of \"$e\" unknowed"
		}
	}
	return $result
}

# This function return a tcl calcul expression
proc GET_CALCUL {c {line none} {primary_type ""}} {
	global INTEGERS DOUBLES
	# We get info of each data
	set data [GET_EXPR $c $line]
	if ![string length $primary_type] {
		set primary_type [lindex $data 0]
	}
	# We verify the master type of primary type
	if {[lsearch $DOUBLES $primary_type] != -1} {
		set is_decimal 1
	} else {
		set is_decimal 0
	}
	set result ""
	foreach "type value" $data {
		set result "$result$value"
	}
	if {$is_decimal} {
		return "\[expr $result\]"
	} else {
		return $result
	}
}

# This function eval the algo
proc EVAL {code} {
	global VAR TYPES ARRAY FUNCTION ignore
	set line 0
	set new_code ""
	set d [GET_STRING $code]
	set code [lindex $d 0]
	# This var contains the number of open
	set bracket_open 0
	foreach c [split $code \n] {
		incr line;
		# We delete space in begin and in end
		set c [string trim $c]
		# if is empty
		if {[string index $c 0] == ""} {
			continue;
		} elseif {[lsearch "BEGIN END" $c] != -1} {
			# We pass
		}
		# We do it to evit error in the using as list
		set c [string map [list "\"" "\\\""] $c]
		set _c [lindex [split $c] 0]
		# We get the argument part
		set args [eval concat [lrange [split $c] 1 end]]
		switch -- $_c {
			ALGO {
				set new_code "$new_code;puts \{ALGO [lrange $c 1 end]\}"
			}
			VAR {
				set args [string map ": { : }" $args]
				set varname [lindex $args 0]
				set token [lindex $args 1]
				set vartype [lindex $args 2]
				if {$varname != "" && $token == ":" && $vartype != ""} {
					# We verify, if the type is allow
					if {[lsearch $TYPES $vartype] == -1 && $vartype != ""} {
						error "Error in line $line, type \"$vartype\" unknowed\n types allow: $TYPES"
					} else {
						set VAR($varname,type) $vartype
						set VAR($varname,value) none
						set new_code "$new_code;[format [info body VAR_STRUCT] $varname]"
					}
				} else {
					error "Error in line $line, syntax error"
				}
			}
			ARRAY {
				set args [string map ": { : }" $args]
				set arrayname [lindex $args 0]
				set token [lindex $args 1]
				set arraytype [lindex $args 2]
				if {$arrayname != "" && $token == ":" && $arraytype != ""} {
					# We verify, if the type is allow
					if {[lsearch $TYPES $arraytype] == -1 && $arraytype != ""} {
						error "Error in line $line, type \"$arraytype\" unknowed\n types allow: $TYPES"
					} else {
						set ARRAY($arrayname,value) none
						set ARRAY($arrayname,type) $arraytype
						set new_code "$new_code;[format [info body ARRAY_STRUCT] $arrayname]"	
					}
				} else {
					error "Error in line $line, syntax error"
				}
			}
			BEGIN {
				incr bracket_open
				set new_code "$new_code;proc main \{\} \{"
				set varnames ""
				foreach var [array names VAR] {
					set varname [lindex [GET_ARG $var ,] 0]
					set varnames "$varnames $varname"
				}
				set new_code "$new_code;global $varnames"
			}
			WRITE {
				set _args [GET_ARG $args ,]
				set result ""
				foreach arg $_args {
					# We get the calcul
					set _ [GET_CALCUL $arg $line]
					set result "$result$_"
				}
				set new_code "$new_code;[format [info body WRITE_STRUCT] $result]"
			}
			END {
				incr bracket_open -1
				set new_code "$new_code;\}"
			}
			READ {
				set varname [GET_ARG $args ,]
				# We verify if var or array
				set data_var [IS_VAR $varname $line]
				set data_array [IS_ARRAY $varname $line]
				if {$data_array != ""} {
					set varname [lindex $data_array 0]
					set type [lindex $data_array 1]
					set is_array 1
				} elseif {$data_var != ""} {
					set type $data_var
					set is_var 1
				} else {
					error "Error in line $line, data \"$varname\" unknowed"
				}
				set new_code "$new_code;[format [info body READ_STRUCT] $type $varname $line $type]"
			}
			IF {
				incr bracket_open
				# We get the calcul
				set _ [GET_CALCUL $args $line]
				set new_code "$new_code;if \{$_\} \{"
			}
			ELSEIF {
				# We get the calcul
				set _ [GET_CALCUL $args $line]
				set new_code "$new_code \} elseif \{$_\} \{"
			}
			ELSE {
				set new_code "$new_code; \} else \{"
			}
			WHILE {
				incr bracket_open
				# We get the calcul
				set _ [GET_CALCUL $args $line]
				set new_code "$new_code;while \{$_\} \{"
			}
			FOR {
				incr bracket_open
				# We space each tag
				set args [string map "<- { <- } TO { TO }" $args]
				foreach "counter token1 begin token2 end" $args {
					if {$counter != "" && $token1 == "<-" && $begin != "" && $token2 == "TO" && $end != ""} {
						set begin [GET_CALCUL $begin $line integer]
						set end [GET_CALCUL $end $line integer]
						set new_code "$new_code;for \{set $counter\ $begin\} \{$$counter < $end\} \{incr $counter\} \{"
					} else {
						error "Error in line $line, syntax error"
					}
				}
			}
			FUNCTION {
				incr bracket_open
				set args [string map [list ( " ( { " ) " } ) " : " : "] $args]
				set function_name [lindex $args 0]
				set token1 [lindex $args 1]
				set declaration [lindex $args 2]
				set token2 [lindex $args 3]
				set token3 [lindex $args 4]
				set function_type [lindex $args 5]
				if {$function_name != "" && $token1 == "(" && $token2 == ")" && $token3 == ":" && $function_type != ""} {
					if {[lsearch $TYPES $function_type] != -1} {
						set FUNCTION($function_name,type) $function_type
						set new_code "$new_code;proc $function_name \{\{args \{\}\}\} \{"
						set count 0
						foreach varname [GET_ARG $declaration ,] {
							set data [IS_VAR $varname]
							if {$data != ""} {
								set type $data
								set new_code "$new_code;set $varname \[lindex \$args $count\];if !\[string is $type $$varname\] {error \"Error in line $line, $type expected\"}"
							} else {
								error "Error in line $line, var $varname unknowed"
							}
							incr count
						}
					} else {
						error "Error in line $line, type \"$function_type\" unknowed\n types allow: $TYPES"
					}
				} else {
					error "Error ine line $line, syntax error"
				}
			}
			RETURN {
				set new_code "$new_code;return [GET_CALCUL $args]"
			}
			default {
				# Default, affectation
				set is_array 0
				set is_var 0
				# We space the token
				set c [string map "{ } {}" $c]
				set c [string map "<- { <- }" $c]
				# We verify if token present
				if {[lindex $c 1] == "<-"} {
					# We remove the token
					set c [lreplace $c 1 1]
					set varname [lindex $c 0]
					set args [GET_ARG [lrange $c 1 end] ,]
					# We verify if var or array
					set data_var [IS_VAR $varname $line]
					set data_array [IS_ARRAY $varname $line]
					if {$data_array != ""} {
						set varname [lindex $data_array 0]
						set type [lindex $data_array 1]
						set is_array 1
					} elseif {$data_var != ""} {
						set type $data_var
						set is_var 1
					} else {
						error "Error in line $line, data \"$varname\" unknowed"
					}
					# We get the calcul
					set result ""
					foreach e $args {
						set result "$result[GET_CALCUL $e $line $type]"
					}
					set new_code "$new_code;[format [info body AFFECTATION_STRUCT] $result $type $varname $line $type]"
				} else {
					set new_code "$new_code;set @ [GET_CALCUL $c $line]"
				}
			}
		}
	}
	if {$bracket_open > 0} {
		error "END expected"
	}
	if {$bracket_open < 0} {
		error "END unexpected"
	}
	# We restore the string
	foreach "value var" [lindex $d 1] {
		set new_code [string map [list $var [string range $value 1 end-1]] $new_code]
	}
	return $new_code
}

proc COMPILE {code} {
	global ignore
	if {[lindex [split $code \n] 0] == "#strict=0"} {
		set ignore 1
	} else {
		set ignore 0
	}
	set code [DEL_COMMENT $code]
	set result [EVAL $code]
	set f [open "out.tcl" w]
	puts $f "$result;if \[catch \{main\} err\] \{puts \$err\}"
	close $f
	puts "Compile success"
}