;puts "ALGO {Perimetre}";
	set longueur {}
;
	set largeur {}
;proc perimetre {{args {}}} {;set longueur [lindex $args 0];set largeur [lindex $args 1];return ($longueur+$largeur)*2;};proc main {} {;global  largeur longueur largeur longueur;
	puts "Enter la longueur: "
;
	gets stdin _
	if {[string is double $_] && [string length $_]} {
		set longueur $_
	} else {
		error "Error in line 13, \"double\" expected"
	}
;
	puts "Enter la largeur: "
;
	gets stdin _
	if {[string is double $_] && [string length $_]} {
		set largeur $_
	} else {
		error "Error in line 15, \"double\" expected"
	}
;
	puts "le perimetre est [expr [perimetre  [expr $longueur] [expr $largeur]]]"
;};if [catch {main} error] {puts $error}
