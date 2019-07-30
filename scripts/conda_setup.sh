#!/bin/bash

set -e
set -x

rm -fr build
conda create -n adios2-tutorial adios2-mpich matplotlib -c williamfgc -c conda-forge
source activate adios2-tutorial

mkdir -p build
cd build

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    ..

make -j 2
