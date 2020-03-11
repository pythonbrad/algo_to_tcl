;puts "ALGO {CARREE}";
	set a {}
;
	set b {}
;
	set c {}
;
	set d {}
;proc main {} {;global  c b d c d a b a;
	puts "9**3=[expr [expr int(9**3)]]"
;
	puts "Entrer un nombre eg ([expr [expr int(5)]], [expr [expr int(5*2)]]): "
;
	gets stdin _
	if {[string is double $_] && [string length $_]} {
		set a $_
	} else {
		error "Error in line 67, \"double\" expected"
	}
;
	puts "Tu as entrer: [expr $a]"
;
	set _ "[expr $a*$a*2/2+2-2]"
	if [string is double $_] {
		set b $_
	} else {
		error "Error in line 73, \"double\" expected"
	}
;
	set _ "[expr $a*$a]"
	if [string is double $_] {
		set b $_
	} else {
		error "Error in line 74, \"double\" expected"
	}
;
	set _ "[expr $a*$a]"
	if [string is double $_] {
		set b $_
	} else {
		error "Error in line 75, \"double\" expected"
	}
;
	set _ "[expr $a*$a]"
	if [string is double $_] {
		set b $_
	} else {
		error "Error in line 76, \"double\" expected"
	}
;
	set _ "[expr $a*$a]"
	if [string is double $_] {
		set b $_
	} else {
		error "Error in line 77, \"double\" expected"
	}
;
	set _ "Son carree est +$b"
	if [string is ascii $_] {
		set c $_
	} else {
		error "Error in line 78, \"ascii\" expected"
	}
;
	puts "$c"
;
	puts "Le double de son carree est [expr $b*2]"
;
	puts "WE BEGIN THE SECOND TEST"
;
	puts "Je te salut? "
;
	gets stdin _
	if {[string is boolean $_] && [string length $_]} {
		set d $_
	} else {
		error "Error in line 83, \"boolean\" expected"
	}
;if {$d} {;
	puts "Hello World!"
;};
	puts "Entre un nombre: "
;
	gets stdin _
	if {[string is double $_] && [string length $_]} {
		set b $_
	} else {
		error "Error in line 88, \"double\" expected"
	}
;if {[expr $b**2>10]} {;
	puts "Son carre est superieur a 10"
 } elseif {[expr $b**2<10]} {;
	puts "Son carre est inferieur a 10"
; } else {;
	puts "Son carree est egale a 10"
;};};if [catch {main} error] {puts $error}
