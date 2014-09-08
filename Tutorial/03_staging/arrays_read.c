/* 
 * ADIOS is freely available under the terms of the BSD license described
 * in the COPYING file in the top level directory of this source distribution.
 *
 * Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
 */

/*************************************************************/
/*          Example of reading arrays in ADIOS               */
/*    which were written from the same number of processors  */
/*                                                           */
/*        Similar example is manual/2_adios_read.c           */
/*************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>

#include "mpi.h"
#include "adios.h"
#include "adios_read.h"

#define TIMEOUT_SEC 5.0

int main (int argc, char ** argv) 
{
    int         rank, size;
    int         NX, NY; 
    int         len, off;
    double      *t = NULL;
    MPI_Comm    comm = MPI_COMM_WORLD;

    uint64_t    start[2], count[2];

    ADIOS_SELECTION *sel;
    int         steps = 0;

#ifdef _USE_GNUPLOT
    int         i, j;
    double      *tmp;
    FILE        *pipe;
#else
    // Variables for ADIOS write
    int64_t     adios_handle;
    uint64_t    adios_groupsize, adios_totalsize;
    char        outfn[256];
#endif

    MPI_Init (&argc, &argv);
    MPI_Comm_rank (comm, &rank);
    MPI_Comm_size (comm, &size);

    adios_read_init_method(ADIOS_READ_METHOD_FLEXPATH, comm, "");

    ADIOS_FILE* fp = adios_read_open("stream.bp", 
                                     ADIOS_READ_METHOD_FLEXPATH, 
                                     comm, ADIOS_LOCKMODE_NONE, 0.0);
    assert(fp != NULL);
    
    ADIOS_VARINFO* nx_info = adios_inq_var( fp, "NX");
    ADIOS_VARINFO* ny_info = adios_inq_var( fp, "NY");

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
    // Not working ... 
    //sel = adios_selection_boundingbox (2, start, count);

    sel = malloc(sizeof(ADIOS_SELECTION));
    sel->type=ADIOS_SELECTION_WRITEBLOCK;
    sel->u.block.index = rank;

#ifdef _USE_GNUPLOT
    if ((NX % size) > 0)
    {
        fprintf(stderr, "Equal distribution is required\n");
        return -1;
    }

    if (rank == 0) {
        pipe = popen("gnuplot", "w");
        fprintf(pipe, "set view map\n");
        fprintf(pipe, "set xrange [0:%d]\n", NX-1);

        tmp = (double *) malloc(sizeof(double) * NX * NY);
        assert(tmp != NULL);
    }

#else
    // ADIOS write init
    adios_init ("adios.xml", comm);
#endif

    //while(adios_errno != err_end_of_stream && adios_errno != err_step_notready)
    while(fp != NULL)
    {
        steps++;
        // Reading
        adios_schedule_read (fp, sel, "var_2d_array", 0, 1, t);
        adios_perform_reads (fp, 1);
        
        printf("step=%d\trank=%d\t[%d,%d]\n", steps, rank, len, NY);
        /*
        // Debugging
        for (i=0; i<len; i++) {
            printf("%d: rank=%d: t[%d,0:4] = ", steps, rank, off+i);
            for (j=0; j<5; j++) {
                printf(", %g", t[i*NY + j]);
            }
            printf(" ...\n");
        }
        */

        // Do something 
#ifdef _USE_GNUPLOT         // Option 1: plotting

        MPI_Gather(t, len * NY, MPI_DOUBLE, tmp, len * NY, MPI_DOUBLE, 0, comm);
        
        if (rank == 0)
        {
            fprintf(pipe, "set title 'Soft X-Rray Signal (shot #%d)'\n", steps);
            fprintf(pipe, "set xlabel 'Channel#'\n");
            fprintf(pipe, "set ylabel 'Timesteps'\n");
            fprintf(pipe, "set cblabel 'Voltage (eV)'\n");

#  ifndef _GNUPLOT_INTERACTIVE
            fprintf(pipe, "set terminal png\n");
            fprintf(pipe, "set output 'fig%03d.png'\n", steps);
#  endif

            fprintf(pipe, "splot '-' matrix with image\n");
            //fprintf(pipe, "plot '-' with lines, '-' with lines, '-' with lines\n");

            double *sum = calloc(NX, sizeof(double));

            for (j = 0; j < NY; j++) {
                for (i = 0; i < NX; i++) {
                    sum[i] += tmp[i * NY + j];
                }
            }

            for (j = 0; j < NY; j++) {
                for (i = 0; i < NX; i++) {
                    fprintf (pipe, "%g ", (-tmp[i * NY + j] + sum[i]/NY)/3276.8);
                }
                fprintf(pipe, "\n");
            }
            fprintf(pipe, "e\n");
            fprintf(pipe, "e\n");
            fflush (pipe);

#  ifdef _GNUPLOT_INTERACTIVE
            printf ("Press [Enter] to continue . . .");
            fflush (stdout);
            getchar ();
#  endif

            free(sum);
        }


#else        // Option 2: BP writing

        snprintf (outfn, sizeof(outfn), "reader_%3.3d.bp", steps);
        adios_open (&adios_handle, "reader", outfn, "w", comm);
        adios_groupsize = 4 * sizeof(int) + sizeof(double) * len * NY; 
        adios_group_size (adios_handle, adios_groupsize, &adios_totalsize);
        adios_write (adios_handle, "NX", &NX);
        adios_write (adios_handle, "NY", &NY);
        adios_write (adios_handle, "len", &len);
        adios_write (adios_handle, "off", &off);
        adios_write (adios_handle, "var", t);
        adios_close (adios_handle);

#endif        

        // Advance
        MPI_Barrier (comm);
        adios_advance_step(fp, 0, TIMEOUT_SEC);
    }
    //
    free(t);

    adios_read_close(fp);

    adios_read_finalize_method(ADIOS_READ_METHOD_FLEXPATH);

#ifndef _USE_GNUPLOT
    adios_finalize (rank);
#else
    if (rank==0) {
        free(tmp);
        pclose(pipe);
    }
#endif

    MPI_Finalize ();

    return 0;
}
