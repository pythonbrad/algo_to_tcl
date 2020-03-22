#!/usr/bin/sh

echo "Tools test"
tclsh test.tcl

for code in exemples/*;
	do
	echo "Test $code";
	tclsh algo.tcl $code;
	tclsh out.tcl;
	echo "Press enter to continuous";
	read;
done