#!/bin/bash

CIL_SRC=cil_tmp.c

cilly.asm.exe --commPrintLn --out $CIL_SRC $1
krun $CIL_SRC
