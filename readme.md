This program permit to compile the algorithm in TCL.

# If you know TCL/TK
* In putting #strict=0 in beginning, you disable the verification of function and varname,
 and like this, you can used the TCL/TK function and varname.
* **NB: After using #strict=0**:
 * -only function write like function_name(arg1,...,argn) or function_name() will be considered like a function.
 * -only varname of type wordchar and not integer will be considered like a varname. 