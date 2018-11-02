#!/bin/bash

export LIBGL_ALWAYS_INDIRECT=1
export PATH=$PATH:/opt/plotter/bin

for ((i=1; i<10; i++)); do
  plotter2d -f reader_00$i.bp -v var -o var00$i -square -colormap XGCLog 
done

for ((i=10; i<15; i++)); do
  plotter2d -f reader_0$i.bp -v var -o var0$i -square -colormap XGCLog
done
