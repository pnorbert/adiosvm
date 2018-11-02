#!/bin/bash
#BSUB -P CSC143SUMMITDEV
#BSUB -J cpp_1d
#BSUB -n 60
#BSUB -W 10
#BSUB -env "all,JOB_FEATURE='NVME'"
#BSUB -o nvram.out
#BSUB -e nvram.err
### BSUB -o %J.out
### BSUB -e %J.err

#
# Summitdev + local nvram
# Every process can access any portion of the data due ADIOS metadata
#

#
# Configurable parameters
#

## Path for SSD
NVRAMDIR=/xfs/scratch/$USER/$LSB_JOBID

NNODES=$(((LSB_DJOB_NUMPROC-1)/20+1))
echo "Number of cores:" $LSB_DJOB_NUMPROC
echo "Number of nodes:" $NNODES

WRITEPROC=$LSB_DJOB_NUMPROC
READPROC=$(($NNODES*2))


#
# End of configurable parameters
#

echo "Job outputdir: $LSB_OUTDIR"
echo "Data output dir: $NVRAMDIR"
echo "Current dir: $PWD"
cd $LSB_OUTDIR
echo "Current dir again: $PWD"

# clean-up previous run
rm -rf writer.bp writer.bp.dir reader*.txt

# Create temporary directory on nvram 
mpirun -np $NNODES --map-by ppr:1:node mkdir -p $NVRAMDIR


# Run Writer
echo "-- Start writer on $WRITEPROC PEs"
mpirun -np $WRITEPROC ./writer $NVRAMDIR/writer.bp >& log.writer

echo "-- This is what we have in the local nvrams"
mpirun -np $NNODES --map-by ppr:1:node ls -lR $NVRAMDIR


# Run Reader
echo ""
echo "-- Start reader on $READPROC PEs"
mpirun -np $READPROC --map-by ppr:2:node ./reader $NVRAMDIR/writer.bp >& log.reader

echo "-- This is what the readers produced in the global job directory"
ls -l reader*.txt

# Delete temporary nvram directory 
mpirun -np $NNODES --map-by ppr:1:node rm -rf $NVRAMDIR
