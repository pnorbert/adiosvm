#!/bin/bash

# Cmds: help  data  code  all
cmd=${1:-help}

echo "Clean-up $cmd"

if [ "x$cmd" == "xhelp" -o "x$cmd" == "xh" ]; then
    echo "./cleanup.sh   [ data | code | all ]"
elif [ "x$cmd" == "xcode" -o "x$cmd" == "xall" ]; then
    cd build
    make clean
    cd -
else
    rm -rf *.bp *.bp.dir 
    rm -rf *.h5 *.sst *_insitumpi_*
    rm -rf *.png *.pnm *.jpg
fi

