#!/usr/bin/sh

echo "Tools test"
tclsh test.tcl

for code in table.agl test3.agl code.agl plus_or_menos.agl test2.agl test.agl test4.agl matrice.agl schtroumpf.agl;
	do
	echo "Test $code";
	tclsh algo.tcl $code;
	tclsh out.tcl;
done