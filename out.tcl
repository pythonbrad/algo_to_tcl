;
	array set d {}
;proc main {} {;global ;
	puts "Should return 1234, else error"
;
	set _ "[expr 1]"
	if [string is integer $_] {
		set d(a,a) $_
	} else {
		error "Error in line 5, \"integer\" expected"
	}
;
	set _ "[expr 2]"
	if [string is integer $_] {
		set d([expr 0],[expr 1]) $_
	} else {
		error "Error in line 6, \"integer\" expected"
	}
;
	set _ "[expr 3]"
	if [string is integer $_] {
		set d([expr 1],[expr 0]) $_
	} else {
		error "Error in line 7, \"integer\" expected"
	}
;
	set _ "[expr 4]"
	if [string is integer $_] {
		set d([expr 1],[expr 1]) $_
	} else {
		error "Error in line 8, \"integer\" expected"
	}
;
	puts "[expr $d(a,a)][expr $d([expr 0],[expr 1])][expr $d([expr 1],[expr 0])][expr $d([expr 1],[expr 1])]"
;};if [catch {main} err] {puts $err}
