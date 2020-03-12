;puts "ALGO {Utils}";
	set nb {}
;
	set entry {}
;proc write {{args {}}} {;
	puts "$args"
;};proc rand {{args {}}} {;return rand();};proc read {{args {}}} {;set @ [gets stdin args];return $args;};proc int {{args {}}} {;return int($args);};proc lambda {{args {}}} {;set @ [set function_name [lindex $args 0]];set @ [set args [lrange $args 1 end]];return \[$function_name\ $args\];};proc _if {{args {}}} {;set @ [foreach {cond cmd} $args {
puts $cond.$cmd...
if {$cmd == {}} {
puts else.$cond
} else {
if $cond {
puts if.$cmd
}
}
}];};proc main {} {;global  entry nb nb entry;set @ [_if  [expr 1==1] [lambda  puts true] [lambda  puts false]];set @ [write  Enter a number];
	set _ "[expr [read ]]"
	if [string is integer $_] {
		set entry $_
	} else {
		error "Error in line 36, \"integer\" expected"
	}
;set @ [write  Your are enter [expr $entry]];
	set _ "[expr 0]"
	if [string is integer $_] {
		set entry $_
	} else {
		error "Error in line 38, \"integer\" expected"
	}
;
	set _ "[expr 1+[int  [expr [rand ]*10]]]"
	if [string is integer $_] {
		set nb $_
	} else {
		error "Error in line 39, \"integer\" expected"
	}
;while {[expr $nb!=$entry]} {;set @ [write  Devine le number: ];
	set _ "[expr [read ]]"
	if [string is integer $_] {
		set entry $_
	} else {
		error "Error in line 42, \"integer\" expected"
	}
;if {[expr $nb>$entry]} {;set @ [write  C'est plus] } elseif {[expr $nb==$entry]} {;set @ [write  Tu as trouver]; } else {;set @ [write  C'est moins];};};};if [catch {main} error] {puts $error}
