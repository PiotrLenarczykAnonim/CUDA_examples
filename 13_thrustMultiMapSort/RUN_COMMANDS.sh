#!/bin/bash
#also one can run: 
#                   make && ./a.out
touch a.out && rm a.out
make -j`nproc`
make clean
clear 
./a.out 4