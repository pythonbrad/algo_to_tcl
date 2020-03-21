
#====================================================================#
#     Editor written in Tcl/Tk for editing TCL source & projects     #
#		(c) Peter Campbell Software; 28-04-2000 	     #
#====================================================================#

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# some features
# ==========
# basic tcl syntax highlighting.
# procedure window, select a procedure to go directly to it.
# right click on a word to have the word "copied" to the "find" window
# multiple windows open simultaneously
# the editor can be invoked with file names on the command line, including wildcards (don't do too many)
# the replace function
# undo/redo
# brace matching - highlight matching braces when cursor is on a brace (also quotes & square brackets)
# goto line number (control-g or "view" menu)
# added "font larger/smaller" to the view menu; 20th June 02 (v1.09)
# changed window system so only opens 1 toplevel window, uses frames & packing for window/file selection

# added a splash screen on startup to show "loading file ..." (v1.10)
# added a "search - grep" function
# don't syntax highlight files at startup, do when they are first viewed
# the most recent find/replace strings weren't being stored at the start of the find/replace history

# todo list
# ======
# reverse searching

# URL = http://fastbase.co.nz/edit/index.html

#====================================================================#

# this program uses a global array editor() to store editor information
# editor(window_number,window) = frame/window
# editor(window_number,file)	 = file name
# editor(window_number,status)	 = "" or "modified" (or "READ ONLY")
# editor(window_number,procs)   = list of procedure names

proc centre_window { w } {
	after idle "
		update idletasks

		# centre
		set xmax \[winfo screenwidth $w\]
		set ymax \[winfo screenheight $w\]
		set x \[expr \{(\$xmax - \[winfo reqwidth $w\]) / 2\}\]
		set y \[expr \{(\$ymax - \[winfo reqheight $w\]) / 2\}\]

		wm geometry $w \"+\$x+\$y\""
}

# to start things rolling display a "splash screen"
# see "Effective Tcl/Tk Programming" book, page 254-247 for reference
wm withdraw .
toplevel .splash -borderwidth 4 -relief raised
wm overrideredirect .splash 1

centre_window .splash

label .splash.info -text "http://www.fastbase.co.nz/edit/index.html" -font {Arial 9}
pack .splash.info -side bottom -fill x

label .splash.title -text "-- ML Editor Tcl/Tk --" -font {Arial 18 bold} -fg blue
pack .splash.title -fill x -padx 8 -pady 8

set splash_status "Loading configuration file ..."
label .splash.status -textvariable splash_status -font {Arial 9} -width 50 -fg darkred
pack .splash.status -fill x -pady 8

update

# note: change this to correct path (should really use "package require" syntax).
if {[catch "source ml/combobox.tcl"]} {
	source /fbase/edit/combobox.tcl
}

if {[catch "source ml/supertext.tcl"]} {
	source /fbase/edit/supertext.tcl
}

# == miscellaneous =================================================#

# temporary procedure for logging debug messages
proc log {message} {
	set fid [open "ml.log" a+]
	set time [clock format [clock seconds] -format "%d-%m-%Y %I:%M:%S %p"]
	puts $fid "$time  $message"
	close $fid
}

#== syntax highlight ================================================#

proc tag_word {editor_no word t line_no startx x {tag_name ""}} {
	global editor
	global syntax
	set ext $editor($editor_no,extension)

	if {$tag_name != ""} {
		$t tag add $tag_name $line_no.$startx $line_no.$x
	} elseif {[array names syntax $ext,$word] != ""} {
		$t tag add command $line_no.$startx $line_no.$x
	} elseif {[string is double -strict $word]} {
		$t tag add number $line_no.$startx $line_no.$x
	} elseif {[string range $word 0 0] == "$"} {
		$t tag add variable $line_no.$startx $line_no.$x
	}
}

proc syntax_highlight { editor_no start_line end_line } {
	global editor

	set t $editor($editor_no,text)

	if {$end_line == "end"} {
		set end $end_line
	} else {
		set end $end_line.end
	}

	# remove all existing tags from the text (excluding the proc tag)
	foreach tag {command comment string number variable} {
		$t tag remove $tag $start_line.0 $end
	}

	set line_no $start_line
	set next_no [expr {$start_line + 1}]

	if {$end_line == "end"} {
		set proc_no 0
		set editor($editor_no,procs) ""
	} else {
		set proc_no $editor($editor_no,proc_no)
	}

	while {[set line [$t get $line_no.0 $next_no.0]] != "" && $line_no <= $end_line} {
		# replace all tabs with spaces for consistency/simpler comparisons
		regsub -all "\t" $line " " line

		set trimmed [string trim $line]
		set we [string wordend $trimmed 0]
		set first_word [string range $trimmed 0 [expr {$we - 1}]]

		if {[string range $trimmed 0 0] == "#"} {
			# comment line, simply colour the whole line
			$t tag add comment $line_no.0 $line_no.end
		} elseif {$first_word == "proc"} {
			# proc statement, colour the whole line and add the proc name to the proc list
			set end [string first " " $trimmed [expr {$we + 1}]]
			if {$end == -1} {
				# provide some extra handling for procedure names ending with semi-colon
				# this to support some other languages besides tcl
				set end [string first ";" $trimmed [expr {$we + 1}]]
			}

			set proc_name [string trim [string range $trimmed [expr {$we + 1}] $end]]
			if {$proc_name != ""} {
				set exists 0
				foreach procs $editor($editor_no,procs) {
					if {[lindex $procs 0] == $proc_name} {
						set exists 1
						break
					}
				}
				if {!$exists} {
					incr proc_no
					$t mark set mark_$proc_no $line_no.0
					lappend editor($editor_no,procs) [list $proc_name $proc_no]
					$t tag add proc $line_no.0 $line_no.end
				}
			}
		} else {
			# general line, review all words within the line and colourise appropriately
			set startx 0
			set word ""
			set length [string length $line]
			set quote 0

			for {set x 0} {$x < $length} {incr x} {
				set c [string range $line $x $x]
				if {$quote != 0} {
					if {$c == $quote} {
						tag_word $editor_no $word $t $line_no $startx [expr {$x + 1}] "string"
						set quote 0
						set word ""
					}
				} elseif {[string first $c "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.$:"] != -1} {
					if {$word == ""} { set startx $x }
					append word $c
				} elseif {$word != ""} {
					tag_word $editor_no $word $t $line_no $startx $x
					set word ""
				} elseif {$c == "\"" || $c == "'"} {
					set startx $x
					set quote $c
				}
				if {$c == "\\"} { incr x }
			}

			if {$word != ""} {
				tag_word $editor_no $word $t $line_no $startx $x
			}
		}

		incr line_no
		incr next_no
	}

	# store the most recent procedure number (proc_no)
	set editor($editor_no,proc_no) $proc_no

	# set "syntax" flag
	set editor($editor_no,syntax) 1
}

#== double-click on braces to select text ==================================#

proc selectClosingBrace {widget} {
    if {[string equal [$widget get insert-1chars] \\ ] } {
	return 0
    }
    set mark [$widget index insert]
    set openingChar [$widget get $mark] 
    switch $openingChar \{ {
	set closingChar \}
    } \" {
	set closingChar \"
    } \[ {
	set closingChar \]
    } default {
	return 0
    }
    set target [$widget index $mark+1chars]
    while {![info complete [$widget get $mark $target+1chars]]} {
	set target [$widget search $closingChar $target+1chars end]
	if {$target == ""} {
	    return 0
	}
    }
    $widget tag add sel $mark $target+1chars
    return 1
}

#== validate procedures =============================================#

# this procedure hasn't been tested to work yet
# the "delete" event needs to be modified to remove all marks within the deleted text
# see "proc $t" the overriding text widget procedure

proc validate_procedures { editor_no } {
	global editor
	set t $editor($editor_no,text)

	# check each procedure mark still exists, if not then delete the procedure name
	set index 0
	foreach procs $editor($editor_no,procs) {
		set no [lindex $procs 1]
		if {[$t index mark_$no] == ""} {
			set editor($editor_no,procs) [lreplace $editor($editor_no,procs) $index $index]
		}
		incr index
	}
}

#== update'status ===================================================#

# this procedure updates the right hand panel which includes the file/directory, status and procedures
# this procedure is normally called after every key/button release to update the cursor position

proc update_status { editor_no } {
	global editor

	set sw $editor($editor_no,status_window)
	set t $editor($editor_no,text)

	$sw configure -state normal
	$sw delete 1.0 end

	$sw insert end "File:\t$editor($editor_no,title)\n"
	$sw insert end "Dir:\t[file dirname $editor($editor_no,file)]\n"

	$sw insert end "Editor:\tVersion $editor(version)\n"
	$sw insert end "Status:\t$editor($editor_no,status)\n"

	$sw insert end "Position:\t[$t index insert]\nFont:\t[$t cget -font]\n\n"

	foreach procs [lsort -index 0 $editor($editor_no,procs)] {
		set proc [lindex $procs 0]
		set no [lindex $procs 1]
		set original_bg [$sw cget -background]
		$sw tag bind proc_$no <Any-Enter> "$sw tag configure proc_$no -background skyblue1"
		$sw tag bind proc_$no <Any-Leave> "$sw tag configure proc_$no -background $original_bg"
		$sw tag bind proc_$no <1> "$t mark set insert mark_$no;$t see insert;update_status $editor_no"
		$sw insert end "$proc\n" proc_$no
	}

	$sw configure -state disabled
}

#== dynamic window menu option for selecting any active editor window ============================#

proc make_window_active { editor_no } {
	global editor

	# find the current window and remove it from the screen
	set current $editor(current)

	# same file? do nothing (return)
	if {$current == $editor_no} { return }

	if {$current != ""} {
		set w $editor($current,window)
		pack forget $w
		destroy .menu
	}

	# get the text widget window
	set t $editor($editor_no,text)

	# the title of the window is "filename" (excluding drive/directory)
	wm title . $editor($editor_no,title)

	# create the main window menus
	menu .menu -tearoff 0

	# add the "file" menu
	set m .menu.file
	menu $m -tearoff 0
	.menu add cascade -label "File" -menu $m -underline 0
	$m add command -label "New" -command make_editor -underline 0
	$m add command -label "Open" -command "open_file $editor_no" -underline 0
	$m add command -label "Save" -command "save_file $editor_no" -underline 0 -accelerator Ctrl+S
	$m add command -label "Save As" -command "save_file_as $editor_no" -underline 5
	# windows? include the "Print" option
	if {$::tcl_platform(platform) == "windows"} {
		$m add command -label "Print" -command "print_file $editor_no" -underline 0 -accelerator Ctrl+P
	}

	# all windows have the close and exit function
	# the close window function closes the window (unless the main window, then clears the window)
	# the exit function closes all windows then exits the application
	$m add separator
	$m add command -label "Close Window" -underline 0 -command "close_window $editor_no"
	$m add separator
	$m add command -label "Exit ML EDITOR" -underline 1 -command "exit_editor"

	# add the "edit" menu
	set m .menu.edit
	menu $m -tearoff 0
	.menu add cascade -label "Edit" -menu $m -underline 0
	$m add command -label "Undo" -command "$t undo" -underline 0 -accelerator Ctrl+Z
	$m add separator
	$m add command -label "Cut" -command "tk_textCut $t" -underline 0 -accelerator Ctrl+X
	$m add command -label "Copy" -command "tk_textCopy $t" -underline 0 -accelerator Ctrl+C
	$m add command -label "Paste" -command "tk_textPaste $t" -underline 0 -accelerator Ctrl+V

	# add the "view" menu
	set m .menu.view
	menu $m -tearoff 0
	.menu add cascade -label "View" -menu $m -underline 0
	$m add check -label "Goto Line" -command "goto_line $editor_no" -underline 0
	$m add check -label "Word Wrap" -command "toggle_word_wrap $editor_no" \
		-underline 0 -variable editor($editor_no,wordwrap) -onvalue 1 -offvalue 0
	$m add separator
	$m add command -label "Refresh Highlighting" -command "syntax_highlight $editor_no 1 end" -underline 0
	$m add separator
	$m add command -label "Font Larger" -command "view_font_size $editor_no 1" -underline 5 -accelerator Ctrl+Plus
	$m add command -label "Font Smaller" -command "view_font_size $editor_no -1" -underline 5 -accelerator Ctrl+Minus

	# add the "Search" menu
	set m .menu.search
	menu $m -tearoff 0
	.menu add cascade -label "Search" -menu $m -underline 0
	# the following commands are duplicated below, see the keyboard/accelerator bindings
	$m add command -label "Find ..." -accelerator Ctrl+F -command "search_find $editor_no" -underline 0
	$m add command -label "Find Next" -accelerator "F3" -command "search_find_next $editor_no" -underline 0
	$m add command -label "Replace ..." -accelerator Ctrl+G -command "search_replace $editor_no" -underline 0
	$m add separator
	$m add command -label "Grep ..." -command "grep_search $editor_no" -underline 0

	# create the "window" menu option
	set m .menu.window
	menu $m -tearoff 0 -postcommand "create_window_menu $m"
	.menu add cascade -label "Window" -menu $m -underline 0

	# create the "window" menu option
	set m .menu.build
	menu $m -tearoff 0
	.menu add cascade -label "Tools" -menu $m -underline 0
	proc _compile file {
		set f [open $file r]
		set data [read $f]
		close $f
		if ![catch {COMPILE $data} err] {
			tk_messageBox -icon info -detail {Compile success} -title Result
		} else {
			tk_messageBox -icon warning -title Result -detail $err
		}
	}
	$m add command -label "Compile" -command "if \[catch {_compile $editor($editor_no,file)} err\] {puts {compiling error}}" -underline 0
	$m add command -label "Execute" -command "if \[catch {exec lxterminal -e bash -c -e \"tclsh out.tcl;echo Process end;read\"} err\] {puts {executing error}}" -underline 0

	# create the "window" menu option
	set m .menu.help
	menu $m -tearoff 0
	.menu add cascade -label "Help" -menu $m -underline 0
	$m add command -label "About ML ..." -command about_window -underline 0

	. configure -menu .menu

	# display the selected window on the screen
	set w $editor($editor_no,window)
	pack $w -expand yes -fill both

	# store the current editor number
	set editor(current) $editor_no

	# has window been opened with syntax highlighting?
	if {!$editor($editor_no,syntax)} {
		syntax_highlight $editor_no 1 end
	}

	# focus on the text widget
	focus -force $t

	update_status $editor_no
}

# dynamically create the "window" menu with a list of all open files

proc about_window {} {
	global editor

	set w .about

	# destroy the find window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# create the new "find" window
	toplevel $w
	wm transient $w .
	wm title $w "About - ML Editor"

	label $w.1 -text "ML Text Editor v$editor(version)" -font {Arial 18 bold} -fg blue
	label $w.2 -text "ML was written by Peter Campbell, pc@acs.co.nz\nWeb Site: http://www.fastbase.co.nz/edit/index.html" -font {Arial 11} -fg darkblue
	label $w.3 -text "Additional credit to Bryan Oakley for combobox.tcl & supertext.tcl (see source)" -font {Arial 10} -fg darkred
	label $w.4 -text "If you have any questions about this software please\nread the source code first and see the web site, then feel free to email me." -font {Arial 9}

	button $w.b -text "Close" -command "destroy $w"

	pack $w.1 $w.2 $w.3 $w.4 $w.b -pady 5
	focus -force $w.b

	centre_window $w
}

proc create_window_menu { m } {
	global editor

	# remove all existing options
	$m delete 0 end

	# starting menu item (1, 2, 3 ... A, B, C ...)
	set number 1

	foreach name [lsort -dictionary [array names editor *,file]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED"} {
			if {$number < 10} {
				set item $number
			} else {
				set item [format "%2X" [expr {$number + 55}]]
				eval "set item \\\x$item"
			}
			if {$item <= "Z"} {
				$m add check -label "$item. $editor($no,title)" -command "make_window_active $no" \
					-underline 0 -variable editor($no,status) -onvalue $editor($no,status) -offvalue $editor($no,status) \
					-indicatoron [expr {$editor($no,status) == "MODIFIED"}]
			} else {
				$m add check -label "$editor($no,title)" -command "make_window_active $no" \
					-variable editor($no,status) -onvalue $editor($no,status) -offvalue $editor($no,status) \
					-indicatoron [expr {$editor($no,status) == "MODIFIED"}]
			}
			incr number
		}
	}
}

#== search_find =====================================================#

proc search_find { editor_no } {
	global editor

	set w .find

	# destroy the find window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# create the new "find" window
	toplevel $w
	wm transient $w .
	wm title $w "Find"

	set f1 [frame $w.f1]
	set f2 [frame $w.f2]

	set ft [frame $f1.top]
	label $ft.text -text "Find What?"
	set entry [combobox::combobox $ft.find -width 30 -value [lindex $editor(find_history) 0]]
	pack $ft.text -side left -anchor nw -padx 4 -pady 4
	pack $entry -side left -anchor nw -padx 4 -pady 4
	pack $ft -side top -anchor nw

	checkbutton $f1.case -text "Match Case?" -variable editor(match_case)
	pack $f1.case -side left -padx 4 -pady 4

	# populate the combobox with the editor find history
	foreach string $editor(find_history) {
		$entry list insert end $string
	}

	button $f2.find -text "Find Next" -command "search_find_command $editor_no $w $entry" -width 10
	button $f2.cancel -text "Cancel" -command "destroy $w" -width 10
	pack $f2.find -side top -padx 8 -pady 4
	pack $f2.cancel -side top -padx 8 -pady 4

	pack $f1 -side left -anchor nw
	pack $f2 -side left -anchor nw

	bind $entry.entry <Return> "+search_find_command $editor_no $w $entry"
	bind $entry.entry <Escape> "destroy $w"

	focus -force $entry
	centre_window $w
}

proc search_find_command { editor_no w entry } {
	global editor
	set editor(find_string) [$entry get]
	destroy $w

	# null string? do nothing
	if {$editor(find_string) == ""} {
		return
	}

	# search "again" (starting from current position)
	search_find_next $editor_no 0
}

proc search_find_next { editor_no {incr 1} } {
	global editor
	set t $editor($editor_no,text)

	# check/add the string to the find history
	set list [lsearch -exact $editor(find_history) $editor(find_string)]
	if {$list != -1} {
		set editor(find_history) [lreplace $editor(find_history) $list $list]
	}
	set editor(find_history) [linsert $editor(find_history) 0 $editor(find_string)]

	set pos [$t index insert]
	set line [lindex [split $pos "."] 0]
	set x [lindex [split $pos "."] 1]
	incr x $incr

	# attempt to find the string
	if {$editor(match_case)} {
		set pos [$t search -- $editor(find_string) $line.$x end]
	} else {
		set pos [$t search -nocase -- $editor(find_string) $line.$x end]
	}

	# if found then move the insert cursor to that position, otherwise beep
	if {$pos != ""} {
		$t mark set insert $pos
		$t see $pos

		# highlight the found word
		set line [lindex [split $pos "."] 0]
		set x [lindex [split $pos "."] 1]
		set x [expr {$x + [string length $editor(find_string)]}]
		$t tag remove sel 1.0 end
		$t tag add sel $pos $line.$x
		focus -force $t
		update_status $editor_no
		return 1
	} else {
		bell
		return 0
	}
}

proc search_replace { editor_no } {
	global editor

	set w .find

	# destroy the find window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# create the new "find" window
	toplevel $w
	wm transient $w .
	wm title $w "Find & Replace"

	set f1 [frame $w.f1]
	set f2 [frame $w.f2]

	set ft [frame $f1.top]
	label $ft.text -text "Find What?" -width 15
	set entry [combobox::combobox $ft.find -width 30 -value [lindex $editor(find_history) 0]]
	pack $ft.text -side left -anchor nw -padx 4 -pady 4
	pack $entry -side left -anchor nw -padx 4 -pady 4
	pack $ft -side top -anchor nw

	set rt [frame $f1.bot]
	label $rt.text -text "Replace with" -width 15
	set replace [combobox::combobox $rt.replace -width 30 -value [lindex $editor(replace_history) 0]]
	pack $rt.text -side left -anchor nw -padx 4 -pady 4
	pack $replace -side left -anchor nw -padx 4 -pady 4
	pack $rt -side top -anchor nw

	checkbutton $f1.case -text "Match Case?" -variable editor(match_case)
	pack $f1.case -side left -padx 4 -pady 4

	# populate the combobox with the editor find history
	foreach string $editor(find_history) {
		$entry list insert end $string
	}

	# populate the combobox with the editor replace history
	foreach string $editor(replace_history) {
		$replace list insert end $string
	}

	button $f2.find -text "Find Next" -command "search_replace_command $editor_no $w $entry $replace find" -width 10 -pady 0
	button $f2.find1 -text "Replace" -command "search_replace_command $editor_no $w $entry $replace replace" -width 10 -pady 0
	button $f2.find2 -text "Replace All" -command "search_replace_command $editor_no $w $entry $replace all" -width 10 -pady 0
	button $f2.cancel -text "Cancel" -command "destroy $w" -width 10 -pady 0
	pack $f2.find -side top -padx 8 -pady 2
	pack $f2.find1 -side top -padx 8 -pady 2
	pack $f2.find2 -side top -padx 8 -pady 2
	pack $f2.cancel -side top -padx 8 -pady 2

	pack $f1 -side left -anchor nw
	pack $f2 -side left -anchor nw

	bind $entry.entry <Escape> "destroy $w"
	bind $replace.entry <Escape> "destroy $w"

	focus -force $entry
	centre_window $w
}

proc search_replace_command { editor_no w entry replace command } {
	global editor
	set editor(find_string) [$entry get]
	set editor(replace_string) [$replace get]

	# check/add the string to the find history
	set list [lsearch -exact $editor(find_history) $editor(find_string)]
	if {$list != -1} {
		set editor(find_history) [lreplace $editor(find_history) $list $list]
	}
	set editor(find_history) [linsert $editor(find_history) 0 $editor(find_string)]

	# check/add the string to the replace history
	set list [lsearch -exact $editor(replace_history) $editor(replace_string)]
	if {$list != -1} {
		set editor(replace_history) [lreplace $editor(replace_history) $list $list]
	}
	set editor(replace_history) [linsert $editor(replace_history) 0 $editor(replace_string)]

	switch -- $command {
		"find" {
			# search "again" (starting from current position)
			search_find_next $editor_no 1
		}
		"replace" {
			if {[replace_one $editor_no 0]} {
				search_find_next $editor_no 1
			}
		}
		"all" {
			set replace_count 0
			if {[replace_one $editor_no 0]} {
				incr replace_count
				while {[replace_one $editor_no 1]} {
					incr replace_count
				}
			}
			tk_messageBox -icon info -title "Replace" -message "$replace_count item(s) replaced."
			destroy $w
		}
	}
}

proc replace_one { editor_no incr } {
	global editor

	if {[search_find_next $editor_no $incr]} {
		set t $editor($editor_no,text)
		set selected [$t tag ranges sel]
		set start [lindex $selected 0]
		set end [lindex $selected 1]
		$t delete $start $end
		$t insert [$t index insert] $editor(replace_string)
		return 1
	} else {
		return 0
	}
}

#== grep search (mulitple files) ===========================================#

proc grep_search { editor_no } {
	global editor

	set w .grep

	# destroy the find window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# create the new "find" window
	toplevel $w
	wm transient $w .
	wm title $w "Grep"

	set f1 [frame $w.f1]
	set f2 [frame $w.f2]

	set ft [frame $f1.top]
	label $ft.text -text "Find What?" -width 12
	set entry [combobox::combobox $ft.find -width 30 -value [lindex $editor(find_history) 0]]
	pack $ft.text -side left -anchor nw -padx 4 -pady 4
	pack $entry -side left -anchor nw -padx 4 -pady 4
	pack $ft -side top -anchor nw

	set fp [frame $f1.path]
	label $fp.text -text "Search Path" -width 12
	entry $fp.entry -width 30 -textvariable editor(grep_path)
	pack $fp.text -side left -anchor nw -padx 4 -pady 4
	pack $fp.entry -side left -anchor nw -padx 4 -pady 4
	pack $fp -side top -anchor nw

	set editor(grep_ext) $editor(default_ext)
	set fe [frame $f1.ext]
	label $fe.text -text "Search Ext" -width 12
	entry $fe.entry -width 30 -textvariable editor(grep_ext)
	pack $fe.text -side left -anchor nw -padx 4 -pady 4
	pack $fe.entry -side left -anchor nw -padx 4 -pady 4
	pack $fe -side top -anchor nw

	checkbutton $f1.case -text "Match Case?" -variable editor(match_case)
	pack $f1.case -side left -padx 4 -pady 4

	# populate the combobox with the editor find history
	foreach string $editor(find_history) {
		$entry list insert end $string
	}

	button $f2.find -text "Start" -command "grep_search_now $w $entry" -width 10
	button $f2.cancel -text "Cancel" -command "destroy $w" -width 10
	pack $f2.find -side top -padx 8 -pady 4
	pack $f2.cancel -side top -padx 8 -pady 4

	pack $f1 -side left -anchor nw
	pack $f2 -side left -anchor nw

	bind $entry.entry <Return> "+grep_search_now $w $entry"
	bind $entry.entry <Escape> "destroy $w"

	focus -force $entry
	centre_window $w
}

proc grep_search_now { w entry } {
	global editor
	set editor(find_string) [$entry get]
	destroy $w

	# null string? do nothing
	if {$editor(find_string) == ""} {
		return
	}

	# check/add the string to the find history
	set list [lsearch -exact $editor(find_history) $editor(find_string)]
	if {$list != -1} {
		set editor(find_history) [lreplace $editor(find_history) $list $list]
	}
	set editor(find_history) [linsert $editor(find_history) 0 $editor(find_string)]

	# now get list of all files to open
	# has file already been loaded? if not open it
	# search file, display results in a window

	# make new editor window
	set editor_no [make_editor]

	set editor($editor_no,title) "Grep Search Results: $editor(find_string)"
	wm title . $editor($editor_no,title)

	set t $editor($editor_no,text)

	$t insert end "Search String: $editor(find_string)\nSearch Path: $editor(grep_path)\nSearch Ext: $editor(grep_ext)\n\n"

	# get list of files
	variable file_list {}
	grep_add_files ".[string trim $editor(grep_ext) .]" $editor(grep_path)

	set editor(grep_matches) 0

	set st [text .hidden]
	set tag_no 0

	# search each file
	foreach file [lsort -dictionary $file_list] {
		set file_tag tag[incr tag_no]

		$t insert end "$file ...\n" $file_tag
		$t see end
		update

		set matches 0

		# open the file (if not open already?)
		set fid [open $file]
		$st insert end [read -nonewline $fid]
		close $fid

		# search the file
		# attempt to find the string
		set current "1.0"

		while {1} {
			if {$editor(match_case)} {
				set pos [$st search -- $editor(find_string) $current end]
			} else {
				set pos [$st search -nocase -- $editor(find_string) $current end]
			}

			if {$pos != ""} {
				incr matches

				set line [lindex [split $pos .] 0]
				set current "$line.end"

				set tag tag[incr tag_no]
				set data [string trim [$st get "$line.0" "$line.end"]]
				$t insert end "\t$line: $data\n" $tag

				set bg [$t cget -background]
				$t tag bind $tag <Enter> "$t tag configure $tag -background skyblue"
				$t tag bind $tag <Leave> "$t tag configure $tag -background $bg"

				$t tag bind $tag <1> [list grep_click $file $pos]
			} else {
				break
			}
		}

		# remove contents from file
		$st delete 1.0 end

		# configure the "tag" for highlighting purposes
		if {$matches} {
			$t insert end "\n"
			incr editor(grep_matches) $matches
		} else {
			$t delete $file_tag.first $file_tag.last
		}
	}

	destroy $st

	$t insert end "\n[llength $file_list] file(s) were searched, $editor(grep_matches) match(es) were found.\n"
	$t insert end "Move the mouse over any search result and click to open the file and display the match.\n"
	$t see end

	# clear the status - default is "not modified"
	set editor($editor_no,status) ""
}

proc grep_add_files { ext dir } {
	variable file_list

	set pattern [file join $dir *]

	foreach filename [glob -nocomplain $pattern] {
		if {[file isdirectory $filename]} {
			grep_add_files $ext $filename
		}

		if {[file isfile $filename]} {
			if {[string tolower [file extension $filename]] == [string tolower $ext]} {
				lappend file_list $filename
			}
		}
	}
}

proc grep_click { file pos } {
	global editor

	# is the file already in memory?
	set active 0
	foreach name [lsort -dictionary [array names editor *,file]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED" && [string equal -nocase $editor($no,file) $file]} {
			set editor_no $no
			set active 1
			break
		}
	}
	if {!$active} {
		set editor_no [make_editor $file 0 0]
	}

	set t $editor($editor_no,text)
	make_window_active $editor_no
	$t mark set insert $pos
	$t see insert
}

#== goto_line =======================================================#

proc goto_line { editor_no } {
	global editor

	set w .goto

	# destroy the find window if it already exists
	if {[winfo exists $w]} { destroy $w }

	# create the new "goto" window
	toplevel $w
	wm transient $w .
	wm title $w "Goto Line"

	label $w.text -text "Goto Line"
	entry $w.goto -width 6 -validate key -validatecommand "validate_number %W %P"
	pack $w.text $w.goto -side left -anchor nw

	bind $w.goto <Return> "+goto_line_no $editor_no $w"
	bind $w.goto <Escape> "destroy $w"
	focus -force $w.goto

	centre_window $w
}

proc validate_number { w new_value } {
	if {[string is integer $new_value]} {
		return 1
	} else {
		bell
		return 0
	}
}

proc goto_line_no { editor_no w } {
	global editor
	set line_no [$w.goto get]
	destroy $w

	catch {
		set t $editor($editor_no,text)
		$t mark set insert $line_no.0
		$t see insert
	}
}

#=================================================================#

# right click on any word and a popup menu offers the "find WORD" option.
# this is the same as the user pressing "Search-Find" (ctrl-f) then entering the word to search

proc popup_text_menu {editor_no x y} {
	global editor
	set t $editor($editor_no,text)

	# place the insert cursor at the mouse pointer
	$t mark set insert @$x,$y
	set pos [$t index insert]

	# get the first being clicked-on
	set string [string trim [$t get "insert wordstart" "insert wordend"]]

	# create the pop-up menu for "find word"
	set pw .popup
	catch {destroy $pw}
	menu $pw -tearoff false

	# if the mouse was clicked over a word then offer this word for "find"
	if {$string != ""} {
		$pw add command -label "Find \"$string\"" -command [list popup_find_text $editor_no $string]

		# if the string is a procedure name then allow the user to go directly to the procedure definition
		foreach procs $editor($editor_no,procs) {
			set proc [lindex $procs 0]
			set no [lindex $procs 1]
			if {$proc == $string} {
				$pw add command -label "Goto \"$string\" definition" -command "$t mark set insert mark_$no;$t see insert;update_status $editor_no"
				break
			}
		}

		$pw add separator
	}
	# display the "undo" option
	$pw add command -label "Undo" -command "$t undo" -underline 0 -accelerator Ctrl+Z
	$pw add separator
	# display the usual cut/copy/paste options
	$pw add command -label "Cut" -command "tk_textCut $t" -underline 0 -accelerator Ctrl+X
	$pw add command -label "Copy" -command "tk_textCopy $t" -underline 0 -accelerator Ctrl+C
	$pw add command -label "Paste" -command "tk_textPaste $t" -underline 0 -accelerator Ctrl+V
	tk_popup $pw $x $y
}

proc popup_find_text { editor_no string } {
	global editor
	set editor(find_string) $string
	search_find_next $editor_no
}

proc toggle_word_wrap { editor_no } {
	global editor

	set t $editor($editor_no,text)
	switch -- $editor($editor_no,wordwrap) {
		1 { $t configure -wrap word }
		default { $t configure -wrap none }
	}
}

proc view_font_size { editor_no increment } {
	global editor
	set t $editor($editor_no,text)

	set font [$t cget -font]
	set size [lindex $font 1]
	incr size $increment
	set font [lreplace $font 1 1 $size]

	$t configure -font $font
}

#== configure_window =================================================#

proc configure_window {} {
	# trap the EXIT [X] button "exit editor"
	wm protocol . WM_DELETE_WINDOW "exit_editor"

	# on windows we can maximise the window by default
	global tcl_platform
	if {$tcl_platform(platform) == "windows" && [info tclversion] >= 8.3} {
		wm state . zoomed
	}
}

#== make_editor =====================================================#

# this procedure makes a new editor window and creates all necessary bindings
# this procudure is called on start-up to load the files specified on the command line and for every "file open"

proc make_editor { {file ""} {display_window 1} {highlight 1} } {
	global editor editor_no splash_status

	set w [frame .w[incr editor_no]]

	set editor($editor_no,window) $w
	set editor($editor_no,file) $file
	set editor($editor_no,title) [file tail $file]
	set editor($editor_no,status) ""
	set editor($editor_no,procs) ""
	set editor($editor_no,syntax) 0

	if {$file == ""} {
		set data ""
		set file "Untitled"
		# new files are always writable
		set editor($editor_no,writable) 1
	} elseif {[catch {set fid [open $file]} msg]} {
		tk_messageBox -type ok -icon error -title "File Open Error" \
			-message "There was an error opening file \"$file\"; $msg."
		return
	} else {
		if {!$display_window} {
			set splash_status "Loading [file tail $file] ..."
			update
		}

		set data [read -nonewline $fid]
		close $fid
		# record whether or not the file can be saved (is the file writable?)
		set editor($editor_no,writable) [file writable $file]
		if {!$editor($editor_no,writable)} {
			set editor($editor_no,status) "READ ONLY"
		}
	}

	# create the main display frames (1 = editor, 2 = status/procedure window)
	set f1 [frame $w.f1]
	set f2 [frame $w.f2]

	set t $f1.text
	set editor($editor_no,text) $t

	# save the file extension, this is used for syntax highlighting commands
	set editor($editor_no,extension) [string tolower [file extension $file]]

	set tx $f1.tx
	set ty $f1.ty

	# has a font been specified in the configuration file (ml_cfg.ml) for this file type?
	if {[array names editor font,$editor($editor_no,extension)] != ""} {
		set font $editor(font,$editor($editor_no,extension))
	} else {
		set font $editor(font)
	}

	supertext::text $t -xscrollcommand "$tx set" -yscrollcommand "$ty set" -exportselection 1 \
		-wrap none -font $font -tabs {1c 2c 3c 4c 5c 6c} -background #e7e7e7

	$t insert end $data
	$t reset_undo

	set editor($editor_no,wordwrap) 0

	# provide a calling routine for the $t/text procedure to trap insert/delete commands
	rename $t $t\_
	proc $t {command args} "
		global editor

		# store line number where insert/delete starts
		if \{\[string equal \$command insert\] || \[string equal \$command delete\]\} \{
			set line1 \[lindex \[split \[$t\_ index insert\] .\] 0\]

			if {!$editor($editor_no,writable)} {
				bell
				return \"\"
			}
		\}

		# perform the specified command
		set result \[eval uplevel \[list $t\_ \$command \$args\]\]

		if \{\[string equal \$command insert\] || \[string equal \$command delete\]\} \{
			# insert/delete? syntax highlight the newly inserted text & checkall procedures
			set line2 \[lindex \[split \[$t\_ index insert\] .\] 0\]
			syntax_highlight $editor_no \$line1 \$line2
			validate_procedures $editor_no
			set editor($editor_no,status) MODIFIED
			$t see insert
		\}

		if \{\[string equal \$command undo\]\} \{
			set editor($editor_no,status) MODIFIED
		\}

		return \$result"

	scrollbar $tx -command "$t xview" -orient h
	pack $tx -side bottom -fill x

	scrollbar $ty -command "$t yview"
	pack $ty -side right -fill y

	pack $t -side left -fill both -expand yes

	# update the screen/display status after every key/button release
	bind $t <KeyRelease> "update_status $editor_no"
	bind $t <ButtonRelease> "update_status $editor_no"

	# keyboard/accelerator bindings
	bind $t <Control-f> "search_find $editor_no;break"
	bind $t <Control-F> "search_find $editor_no;break"
	bind $t <F3> "search_find_next $editor_no;break"
	bind $t <Control-h> "search_replace $editor_no;break"
	bind $t <Control-H> "search_replace $editor_no;break"

	bind $t <Control-X> "tk_textCut $t;break"
	bind $t <Control-C> "tk_textCopy $t;break"
	bind $t <Control-V> "tk_textPaste $t;break"

	# control-s, shortcut to save file
	bind $t <Control-s> "save_file $editor_no;break"
	bind $t <Control-S> "save_file $editor_no;break"

	if {$::tcl_platform(platform) == "windows"} {
		bind $t <Control-p> "print_file $editor_no;break"
		bind $t <Control-P> "print_file $editor_no;break"
	}

	bind $t <Control-plus> "view_font_size $editor_no 1"
	bind $t <Control-minus> "view_font_size $editor_no -1"

	# bind the right mouse click to select the current word and display a pop-up menu
	bind $t <ButtonPress-3> "popup_text_menu $editor_no %x %y"

	# bind the double click on text brace to select the braces
	bind $t <Double-Button> {if {[selectClosingBrace %W]} {break}}

	# bind control-g for "goto line number"
	bind $t <Control-g> "goto_line $editor_no;break"
	bind $t <Control-G> "goto_line $editor_no;break"

	# PCS time saving option for converting 4 spaces to Tab
	bind $t <F10> "replace_4_spaces $editor_no;break"

	# see the syntax_highlighting procedure for details of each tag	
	$t tag configure command -foreground blue
	$t tag configure number -foreground DarkGreen
	$t tag configure proc -foreground blue -font {Verdana 9 bold}
	$t tag configure comment -foreground green4
	$t tag configure variable -foreground red
	$t tag configure string -foreground purple
	$t tag configure sel -background skyblue

	# create the right-hand frame
	text $f2.procs -xscrollcommand "$f2.tx set" -yscrollcommand "$f2.ty set" \
		-wrap none -font {Arial 8} -background #ffc800 -width 30 -cursor arrow
	scrollbar $f2.tx -command "$f2.procs xview" -orient h
	pack $f2.tx -side bottom -fill x
	scrollbar $f2.ty -command "$f2.procs yview"
	pack $f2.ty -side right -fill y
	pack $f2.procs -side left -fill both -expand yes

	set editor($editor_no,status_window) $f2.procs

	# pack the 3 frames
	pack $f1 -side left -fill both -expand yes
	pack $f2 -side left -fill y

	focus -force $t
	$t mark set insert 1.0

	if {$highlight} {
		syntax_highlight $editor_no 1 end
	}

	if {$display_window} {
		make_window_active $editor_no
	}

	return $editor_no
}

proc replace_4_spaces { editor_no } {
	global editor
	set t $editor($editor_no,text)

	# if the cursor is at the start of 4 spaces then replace them with a tab character
	if {[$t get "insert" "insert+4c"] == "    "} {
		$t delete "insert" "insert+4c"
		$t insert "insert" "\t"
	} elseif {[$t get "insert" "insert+5c"] == "\t    "} {
		$t delete "insert" "insert+5c"
		$t insert "insert" "\t\t\t"
	} elseif {[$t get "insert" "insert+1c"] == "\t"} {
		$t delete "insert" "insert+1c"
		$t insert "insert" "\t\t"
	}

	set pos [$t index "insert"]
	set line_no [expr {[lindex [split $pos "."] 0] + 1}]
	$t mark set insert "$line_no.0"
	$t see $pos
}

#== open file =======================================================#

proc open_file { editor_no } {
	global editor
	global file_types

	set file $editor($editor_no,file)
	if {$file != ""} {
		set pwd [file dirname $file]
		set ext $editor($editor_no,extension)
	} else {
		set pwd [pwd]
		set ext $editor(default_ext)
	}

	set file [tk_getOpenFile -title "Open File" -initialdir $pwd -initialfile "*.[string trim $ext .]" \
		-defaultextension ".[string trim $ext .]" -filetypes $file_types]

	if {$file != ""} {
		make_editor $file
	}
}

#== save file =======================================================#

proc save_file { editor_no } {
	global editor
	set file $editor($editor_no,file)

	if {$file == ""} {
		save_file_as $editor_no
	} else {
		set fid [open $file w+]
		set t $editor($editor_no,text)
		puts -nonewline $fid [$t get 1.0 end]
		close $fid
		set editor($editor_no,status) ""

		# previously we undid the "undo" status after saving
		# now allow undo to go back since the file was originally opened
	}
}

#== save file as ====================================================#

proc save_file_as { editor_no } {
	global editor
	global file_types
	set file $editor($editor_no,file)

	set file [tk_getSaveFile -title "Save File" -initialdir [pwd] -initialfile $file -filetypes $file_types]

	if {$file != ""} {
		set fid [open $file w+]
		set t $editor($editor_no,text)
		puts -nonewline $fid [$t get 1.0 end]
		close $fid
		set editor($editor_no,status) ""
		set editor($editor_no,file) $file
		set editor($editor_no,title) [file tail $file]
		wm title . $editor($editor_no,title)

		# reset the undo status
		set t $editor($editor_no,text)
		$t reset_undo

		# update the file extension, this is used for syntax highlighting commands
		set editor($editor_no,extension) [string tolower [file extension $file]]
	}
}

#== close window ====================================================#

proc close_window { editor_no {action ""} } {
	global editor

	# check status of window before closing
	while {$editor($editor_no,status) == "MODIFIED"} {
		set option [tk_messageBox -title "Save Changes?" -icon question -type yesnocancel -default yes \
			-message "File \"$editor($editor_no,file)\" has been modified.\nDo you want to save the changes?"]

		if {$option == "yes"} {
			save_file $editor_no
		} elseif {$option != "no"} {
			return 0
		} else {
			break
		}
	}

	destroy $editor($editor_no,window)
	set editor($editor_no,status) "CLOSED"

	# make another window active - if any?
	set active 0
	foreach name [lsort -dictionary [array names editor *,file]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED"} {
			make_window_active $no
			set active 1
			break
		}
	}

	if {!$active && $action != "exit"} { make_editor }

	return 1
}

#== exit editor =====================================================#

proc exit_editor {} {
	global editor
	global syntax

	# first save the configuration file "ml_cfg.ml"
	set fid [open [file join $editor(initial_dir) "ml_cfg.ml"] w]
	puts $fid "# ML editor configuration file - AUTO GENERATED"
	puts $fid "# DO NOT EDIT THIS FILE WITH \"ML\", USE ANOTHER EDITOR (BECAUSE ML WILL OVERWRITE YOUR CHANGES)"
	puts $fid ""

	puts $fid "# find & file history"
	set file_history ""
	foreach name [lsort -dictionary [array names editor *,status]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED"} {
			if {$editor($no,file) != ""} {
				lappend file_history $editor($no,file)
			}
		}
	}
	puts $fid "set editor(find_history) [list [lrange $editor(find_history) 0 19]]"
	puts $fid "set editor(replace_history) [list [lrange $editor(replace_history) 0 19]]"
	puts $fid "set editor(file_history) [list $file_history]"
	puts $fid ""

	puts $fid "# fonts for each file type"
	puts $fid "# to specify/change the font for a specific file type insert a line as follows;"
	puts $fid "# set editor(font,extension) {FontName FontSize}"
	foreach font [lsort [array names editor font*]] {
		puts $fid [list set editor($font) $editor($font)]
	}
	puts $fid ""

	puts $fid "# default extension (you'll need to edit the file manually to change the default extension)"
	puts $fid "set editor(default_ext) $editor(default_ext)"
	puts $fid ""

	puts $fid "# syntax highlight for different file types"
	puts $fid "# set syntax(.extension,command) 1"
	foreach syn [lsort [array names syntax]] {
		set ext [lindex [split $syn ","] 0]
		if {$ext != ".tcl"} {
			puts $fid [list set syntax($syn) $syntax($syn)]
		}
	}

	close $fid

	# close all files in reverse order... this is done so we don't end up displaying all files (see close_window)
	foreach name [lsort -dictionary -decreasing [array names editor *,status]] {
		set no [lindex [split $name ","] 0]
		if {$editor($no,status) != "CLOSED"} {
			if {![close_window $no "exit"]} {
				return
			}
		}
	}

	# exit, close main window
	destroy .
}

#== print file =====================================================#

proc gdi_init { title } {
	global gdi

	# display the printer dialog, get response {printer exit_status}
	set printer [printer dialog select]
	if {[lindex $printer 1] != 1} {
		return 0
	}

	# set the "hdc", this is used for all graphics/data output
	set gdi(hdc) [lindex $printer 0]

	printer job -hdc $gdi(hdc) start -name $title

	# process the printer attributes, we need to page margins and pixels per inch
	foreach row [printer attr -hdc $gdi(hdc)] {
		set option [lindex $row 0]
		set values [lindex $row 1]
		switch -exact -- $option {
			"page dimensions" {
				set gdi(width) [lindex $values 0]
				set gdi(height) [lindex $values 1]
			}
			"page minimum margins" {
				set gdi(left) [lindex $values 0]
				set gdi(top) [lindex $values 1]
				set gdi(right) [lindex $values 2]
				set gdi(bottom) [lindex $values 3]
			}
			"pixels per inch" {
				set gdi(resx) [lindex $values 0]
				set gdi(resy) [lindex $values 1]
			}
		}
	}

	return 1
}

proc gdi_x { x } {
	# convert x which is specified as a character position to the pixel position
	global gdi
	set x [expr {(($x - 1) / 11.0) * $gdi(resx) + $gdi(left)}]
	return $x
}

proc gdi_y { y } {
	# convert y which is specified as a character position to the pixel position
	global gdi
	set y [expr {(($y - 1) / 6.0) * $gdi(resy) + $gdi(top)}]
	return $y
}

proc gdi_inches { i axis } {
	# convert i which is specified in inches to a pixel size (eg: 1 inch may equal 600 pixels)
	global gdi
	set i [expr {$i * $gdi(res$axis)}]
	return $i
}

proc gdi_page { command } {
	# gdi_page start/end
	global gdi
	printer page -hdc $gdi(hdc) $command
}

proc gdi_close {} {
	global gdi
	printer job -hdc $gdi(hdc) end
	printer close
}

# the print file command relies on the packages "printer" & "gdi" to be installed somewhere
# the system uses the font for the current window, to print smaller make the font smaller

proc print_file { editor_no } {
	global gdi editor

	# load the packages we require, if not installed then just result in an error
	package require printer
	package require gdi

	# initialise gdi print device
	if {![gdi_init "ML: $editor($editor_no,title)"]} { return }

	set t $editor($editor_no,text)

	set font [$t cget -font]

	# get the number of lines (keep insert cursor in original place)
	set insert [$t index insert]
	$t mark set insert end
	set lines [lindex [split [$t index insert] .] 0]
	$t mark set insert $insert

	set page_no 0
	set y 0

	set datetime [clock format [clock seconds] -format "%A, %d %B %Y - %I:%M %p"]

	# process each line
	for {set line 1} {$line <= $lines} {incr line} {
		set next [expr {$line + 1}]
		set text [$t get $line.0 $next.0]

		# before outputting text determine if new page is requried
		if {!$y} {
			gdi_page start
			incr page_no

			gdi text $gdi(hdc) [gdi_x 1] [gdi_y 0] -text $editor($editor_no,title) -font {Arial 13 bold} -justify left -anchor w
			gdi text $gdi(hdc) [gdi_x 1] [gdi_y 64] -text $datetime -font {Arial 8} -justify left -anchor w
			gdi text $gdi(hdc) [gdi_x 80] [gdi_y 64] -text "Page: $page_no" -font {Arial 8} -justify left -anchor e

			set y [gdi_y 2]
		}

		# now output the text for the source code
		gdi text $gdi(hdc) [gdi_x 4] $y -text $line -font $font -anchor ne -justify left
		set height [gdi text $gdi(hdc) [gdi_x 5] $y -text $text -font $font -anchor nw -justify left]

		set y [expr {$y + ($height / 2)}]
		if {$y > [gdi_y 62]} {
			gdi_page end
			set y 0
		}
	}

	if {$y} { gdi_page end }

	gdi_close
}

#== open the default windows ========================================#

global editor
global syntax
global editor_no
global file_types

set editor(version) "1.11"

set editor_no 0

set editor(current) ""

# set default file extension
set editor(default_ext) "tcl"
set editor(initial_dir) [pwd]
set editor(grep_path) $editor(initial_dir)

# set default font - saved in the ml_cfg.ml file (user needs to change manually)
set editor(font) {Verdana 9}

# files loaded since last use of editor (see proc exit_editor)
set editor(file_history) {}

# find history (list of strings previously searched for)
set editor(find_history) {}
set editor(match_case) 0
set editor(replace_history) {}

# load the configuration file (if it exists/is readable)
if {[file readable "ml_cfg.ml"]} {
	source ml_cfg.ml
}

# default the current find string to the last value
set editor(find_string) [lindex $editor(find_history) 0]
set editor(replace_string) [lindex $editor(replace_history) 0]

set file_types {
	{{All Files}	*	      }
	{{TCL Scripts}	{.tcl}	      }
	{{FastBase Source}	{.fb}	      }
	{{Magix Source}	{.ms}	      }
	{{Html}	{.html .htm}	      }
	{{Text Files}	{.txt}	      }
	{{AGL Scripts}	{.agl}	      }
	{{AGL+ Scripts}	{.aglx}	      }
}

# create a global array syntax(file_extension,commands)
# this is used by the "tag_word" procedure to detect words
foreach command [info commands] {
	set syntax(.tcl,$command) 1
}

# load the files specified on the command line
# if none then check the "editor(file_history)" variable as saved in the configuration file

set any_files 0

if {$argc} {
	foreach name $argv {
		# replace all backslashes with forward slashes so windows filenames will be "globbed" ok.
		regsub -all "\\\\" $name "/" name
		foreach name [glob -nocomplain $name] {
			make_editor $name 0 0
			set any_files 1
		}
	}
} elseif {$editor(file_history) != ""} {
	foreach file $editor(file_history) {
		if {[file readable $file]} {
			make_editor $file 0 0
			set any_files 1
		}
	}
}

after idle {
	destroy .splash
	wm deiconify .
}

# configure the window and menus
configure_window

# if no files loaded then open a blank editor window
if {!$any_files} {
	make_editor
} else {
	make_window_active 1
}
