;set @ [package  require Tk];proc refresh {{args {}}} {;set @ [.label  configure -text [clock  format [clock  seconds]]];set @ [after  [expr 1000] refresh];};proc main {} {;global ;
	set _ "[label  .label]"
	if [string is ascii $_] {
		set lb $_
	} else {
		error "Error in line 16, \"ascii\" expected"
	}
;set @ [pack  $lb];set @ [refresh ];};if [catch {main} err] {puts $err}
