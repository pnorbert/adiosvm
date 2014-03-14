#!/bin/bash

/opt/plotter/bin/plotter -f adios_global_no_xml.bp -v temperature \
   -o temperature -imgsize 720 600

/opt/plotter/bin/plotter -f adios_global_no_xml.bp -v blocks \
   -o blocks -imgsize 720 600

/opt/plotter/bin/plotter -f adios_global_no_xml.bp -v temperature -v blocks \
   -o multi -multiplot -imgsize 720 600 \
    -subtitle="" \
    -title="Temperature and Blocks" 

