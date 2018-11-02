/* 
 * ADIOS is freely available under the terms of the BSD license described
 * in the COPYING file in the top level directory of this source distribution.
 *
 * Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "mpi.h"
#include "adios.h"
#include "adios_read.h"

#define TIMEOUT_SEC 5.0

/*************************************************************/
/*          Example of writing arrays in ADIOS               */
/*                                                           */
/*        Similar example is manual/2_adios_write.c          */
/*************************************************************/
int main (int argc, char ** argv) 
{
    char        filename [256] = "stream.bp";
    int         rank, size;
    int         NX, NY; 
    int         len, off;
    double      *t = NULL;
    MPI_Comm    comm = MPI_COMM_WORLD;

    int64_t     adios_handle;
	uint64_t    adios_groupsize, adios_totalsize;

    uint64_t    start[2], count[2];

    ADIOS_SELECTION *sel;
    int         steps = 0;

    MPI_Init (&argc, &argv);
    MPI_Comm_rank (comm, &rank);
    MPI_Comm_size (comm, &size);
    
    // ADIOS read init
    adios_read_init_method (ADIOS_READ_METHOD_BP, comm, "verbose=3");
    
    ADIOS_FILE* fp = adios_read_open_file ("kstar.bp", 
                                           ADIOS_READ_METHOD_BP,
                                           comm);
    assert(fp != NULL);

    ADIOS_VARINFO* nx_info = adios_inq_var( fp, "N");
    ADIOS_VARINFO* ny_info = adios_inq_var( fp, "L");

    NX = *((int *)nx_info->value);
    NY= *((int*)ny_info->value);

    len = NX / size;
    off = len * rank;

    if (rank == size-1)
        len = len + NX % size;

    printf("\trank=%d: NX,NY,len,off = %d\t%d\t%d\t%d\n", rank, NX, NY, len, off);
    assert(len > 0);

    t = (double *) malloc(sizeof(double) * len * NY);
    memset(t, '\0', sizeof(double) * len * NY);
    assert(t != NULL);

    start[0] = off;
    start[1] = 0;
    count[0] = len;
    count[1] = NY;
    sel = adios_selection_boundingbox (2, start, count);

    // ADIOS write init
    adios_init ("adios.xml", comm);
    
    remove (filename);
    //int ii;
    //for(ii = 0; ii<10; ii++){
    //    for (i = 0; i < len * NY; i++)
    //        t[i] = ii*1000 + rank;

    while(adios_errno != err_end_of_stream && adios_errno != err_step_notready)
    {
        steps++;
        // Reading
        adios_schedule_read (fp, sel, "var", 0, 1, t);
        adios_perform_reads (fp, 1);

        // Debugging
        //for (i = 0; i < len*NY; i++)  t[i] = off * NY + i;

        printf("step=%d\trank=%d\t[%d,%d]\n", steps, rank, len, NY);

        // Writing
        adios_open (&adios_handle, "writer", filename, "a", comm);
        adios_groupsize = 4*4 + 8*len*NY;
        adios_group_size (adios_handle, adios_groupsize, &adios_totalsize);
        adios_write (adios_handle, "NX", &NX);
        adios_write (adios_handle, "NY", &NY);
        adios_write (adios_handle, "len", &len);
        adios_write (adios_handle, "off", &off);
        adios_write (adios_handle, "var_2d_array", t);
        adios_close (adios_handle);


        // Advance
        MPI_Barrier (comm);
        adios_advance_step(fp, 0, TIMEOUT_SEC);
    }
    free(t);

    MPI_Barrier (comm);
    adios_read_close(fp);

    if (rank==0) 
        printf ("We have processed %d steps\n", steps);

    MPI_Barrier (comm);
    adios_read_finalize_method(ADIOS_READ_METHOD_BP);

    adios_finalize (rank);

    MPI_Finalize ();

    return 0;
}
