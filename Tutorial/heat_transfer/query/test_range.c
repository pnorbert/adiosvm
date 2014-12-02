/* 
 * Test range queries on genarray_varying 
 *
 * Copyright (c) 2008 - 2012.  UT-BATTELLE, LLC. All rights reserved.
 */


/* Query example code for the heat transfer output
   Assumptions: Have two 2D arrays of the same size in the output (like T and
     dT in heat transfer).  One or multiple steps in the file.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include "mpi.h"
#include "utils.h"
#include "adios.h"
#include "adios_read.h"
#include "adios_query.h"
#include "adios_error.h"

#define _GNU_SOURCE
#include "math.h"

// Input arguments
char   infilename[256];    // File/stream to read 
char   outfilename[256];   // File to write
char   minstr[32];
char   maxstr[32];
double minval;
double maxval;
double fillval;
enum ADIOS_QUERY_METHOD query_method = ADIOS_QUERY_METHOD_UNKNOWN;

double mynan;

static const enum ADIOS_READ_METHOD read_method = ADIOS_READ_METHOD_BP;

static const int max_read_buffer_size  = 1024*1024*1024;
static const int max_write_buffer_size = 1024*1024*1024;

static int timeout_sec = 0; // will stop if no data found for this time (-1: never stop)

static const char v1name[] = "T";
static const char v2name[] = "dT";


// Global variables
int         rank, numproc;
MPI_Comm    comm; 
ADIOS_FILE *f;      // stream for reading
uint64_t    write_total; // data size written by one processor
uint64_t    largest_block; // the largest variable block one process reads
char     ** group_namelist; // name of ADIOS group
char       *readbuf; // read buffer
int         decomp_values[10];


void cleanup_step ();
int alloc_vars(int step);
int do_queries(int step);
int read_vars(int step);
int write_vars(int step);

void printUsage(char *prgname)
{
    print0("Usage: %s input output min max fillvalue querymethod <decomposition>\n"
           "    input      Input file\n"
           "    output     Output file\n"
           "    min        Range query minimum value (float)\n"
           "    max        Range query maximum value (float)\n"
           "    fillvalue  Fill value (float)\n"
           "               NAN is allowed, its value in this actual executable is: %g\n"
           "    querymethod   [fastbit|alacrity|unknown]\n"
           "               Which query method to use (unknown uses default available\n"
           "    <decomposition>    list of numbers e.g. 32 8 4\n"
           "            Decomposition values in each dimension of an array\n"
           "            The product of these number must be less then the number\n"
           "            of processes. Processes whose rank is higher than the\n"
           "            product, will not write anything.\n"
           "               Arrays with less dimensions than the number of values,\n"
           "            will be decomposed with using the appropriate number of\n"
           "            values.\n"
           ,prgname, mynan);
}

int get_double_arg (int argidx, char ** argv, double * value)
{
    char *end;
    errno = 0; 
    *value = strtod(argv[argidx], &end); 
    if (errno || (end != 0 && *end != '\0')) { 
        print0 ("ERROR: Invalid floating point number in argument %d: '%s'\n",
                argidx, argv[argidx]); 
        printUsage(argv[0]);
        return 1; 
    } 
    return 0;
}

int processArgs(int argc, char ** argv)
{
    int i, j, nd, prod;
    char *end;
    if (argc < 6) {
        printUsage (argv[0]);
        return 1;
    }
    strncpy(infilename,     argv[1], sizeof(infilename));
    strncpy(outfilename,    argv[2], sizeof(outfilename));
    if (get_double_arg (3, argv, &minval)) return 1;
    strncpy(minstr,    argv[3], sizeof(minstr)); // save it as string too
    if (get_double_arg (4, argv, &maxval)) return 1;
    strncpy(maxstr,    argv[4], sizeof(maxstr)); // save it as string too
    if (get_double_arg (5, argv, &fillval)) return 1;
    
    if (argc > 6) {
        if (!strcmp (argv[6], "alacrity")) {
            query_method = ADIOS_QUERY_METHOD_ALACRITY;
        }
        else if (!strcmp (argv[6], "fastbit")) {
            query_method = ADIOS_QUERY_METHOD_FASTBIT;
        }
        else {
            query_method = ADIOS_QUERY_METHOD_UNKNOWN;
        }
    }


    nd = 0;
    j = 7;
    while (argc > j && j<14) { // get max 6 dimensions
        errno = 0; 
        decomp_values[nd] = strtol(argv[j], &end, 10); 
        if (errno || (end != 0 && *end != '\0')) { 
            print0 ("ERROR: Invalid decomposition number in argument %d: '%s'\n",
                    j, argv[j]); 
            printUsage(argv[0]);
            return 1; 
        } 
        nd++; 
        j++;
    }

    if (argc > j) { 
        print0 ("ERROR: Only 6 decompositon arguments are supported\n");
        return 1; 
    } 

    for (i=nd; i<10; i++) {
        decomp_values[i] = 1;
    }

    prod = 1;
    for (i=0; i<nd; i++) {
        prod *= decomp_values[i];
    }

    if (prod > numproc) {
        print0 ("ERROR: Product of decomposition numbers %d > number of processes %d\n", 
                prod, numproc);
        printUsage(argv[0]);
        return 1; 
    }

    return 0;
}


int main (int argc, char ** argv) 
{
    int         err;
    int         steps = 0, curr_step;
    int         retval = 0;

#ifdef NAN
    mynan = (double) NAN;
#else
    mynan = (double) 0;
#endif

    MPI_Init (&argc, &argv);
    //comm = MPI_COMM_WORLD;
    //MPI_Comm_rank (comm, &rank);
    //MPI_Comm_size (comm, &numproc);
    MPI_Comm_rank (MPI_COMM_WORLD, &rank);
    MPI_Comm_size (MPI_COMM_WORLD, &numproc);
    MPI_Barrier(MPI_COMM_WORLD);

    MPI_Comm_split(MPI_COMM_WORLD, 2, rank, &comm);	//color=2
    MPI_Comm_rank (comm, &rank);
    MPI_Comm_size (comm, &numproc);

    if (processArgs(argc, argv)) {
        return 1;
    }
    
    print0("Input stream            = %s\n", infilename);
    print0("Output stream           = %s\n", outfilename);
    print0("Min value               = %g\n", minval);
    print0("Max value               = %g\n", maxval);
    print0("Fill value              = %g\n", fillval);
    print0("Query method id         = %d\n", query_method);
    

    adios_init ("test_range.xml", comm);
    err = adios_read_init_method(read_method, comm, "verbose=2");

    if (!err) {
        print0 ("%s\n", adios_errmsg());
    }

    print0 ("Waiting to open stream %s...\n", infilename);
    f = adios_read_open (infilename, read_method, comm, 
                         ADIOS_LOCKMODE_ALL, timeout_sec);
    if (adios_errno == err_file_not_found) 
    {
        print ("rank %d: Stream not found after waiting %d seconds: %s\n", 
               rank, timeout_sec, adios_errmsg());
        retval = adios_errno;
    } 
    else if (adios_errno == err_end_of_stream) 
    {
        print ("rank %d: Stream terminated before open. %s\n", rank, adios_errmsg());
        retval = adios_errno;
    } 
    else if (f == NULL) {
        print ("rank %d: Error at opening stream: %s\n", rank, adios_errmsg());
        retval = adios_errno;
    } 
    else 
    {
        // process steps here... 
        if (f->current_step != 0) {
            print ("rank %d: WARNING: First %d steps were missed by open.\n", 
                   rank, f->current_step);
        }

        while (1)
        {
            steps++; // start counting from 1

            fflush (stderr);
            print0 ("\n\nFile info:\n");
            print0 ("  current step:   %d\n", f->current_step);
            print0 ("  last step:      %d\n", f->last_step);
            print0 ("  # of variables: %d\n", f->nvars);

            retval = alloc_vars(steps);
            if (retval) break;

            retval = do_queries(steps);
            if (retval) break;

            retval = read_vars(steps);
            if (retval) break;

            adios_release_step (f); // this step is no longer needed to be locked in staging area

            retval = write_vars(steps);
            if (retval) break;

            // advance to 1) next available step with 2) blocking wait 
            curr_step = f->current_step; // save for final bye print
            cleanup_step();
            adios_advance_step (f, 0, timeout_sec);

            if (adios_errno == err_end_of_stream) 
            {
                break; // quit while loop
            }
            else if (adios_errno == err_step_notready) 
            {
                print ("rank %d: No new step arrived within the timeout. Quit. %s\n", 
                        rank, adios_errmsg());
                break; // quit while loop
            } 
            else if (f->current_step != curr_step+1) 
            {
                // we missed some steps
                print ("rank %d: WARNING: steps %d..%d were missed when advancing.\n", 
                        rank, curr_step+1, f->current_step-1);
            }

        }

        adios_read_close (f);
    } 
    print0 ("Bye after processing %d steps\n", steps);

    adios_read_finalize_method (read_method);
    adios_finalize (rank);

    MPI_Finalize ();

    return retval;
}

/* Store variables that go out to disk */
uint64_t offs[10];
uint64_t ldims[10];
//uint64_t gdims[10]; // gdims is varinfo->dims
double *v1;
double *v2;

// hitlist dimensions
uint64_t nhits;  // number of hits on this process
uint64_t nhits_total; // all hits; also hits_gdim for hitlist
uint64_t hits_off; // offset in hitlist; ldim is point selection -> npoints
ADIOS_SELECTION *hitlist;
double * hitdata; // the data, read in from file, for the hits
ADIOS_VARINFO * vinfo;

uint64_t groupsize;

typedef struct {
    uint64_t        writesize; // size of subset this process writes, 0: do not write
} VarInfo;

VarInfo * varinfo;

// cleanup all info from previous step 
void cleanup_step ()
{
    free (v1);
    free (v2);
    adios_free_varinfo(vinfo);
    if (hitlist) {
        free (hitlist->u.points.points);
        adios_selection_delete(hitlist);
        hitlist = NULL;
    }
    if (hitdata) {
        free (hitdata);
        hitdata = NULL;
    }
}

void print_type_and_dimensions (ADIOS_VARINFO *v)
{
    // print variable type and dimensions
    int j;
    print0("    %-9s  %s", adios_type_to_string(v->type), f->var_namelist[v->varid]);
    if (v->ndim > 0) {
        print0("[%llu", v->dims[0]);
        for (j = 1; j < v->ndim; j++)
            print0(", %llu", v->dims[j]);
        print0("] :\n");
    } else {
        print0("\tscalar\n");
    }
}

int alloc_vars(int step)
{
    int retval = 0;
    int i, j;
    uint64_t sum_count;

    groupsize = 6*sizeof(uint64_t)   // dimensions+offsets
              + 5*sizeof(uint64_t)   // nhits + nhits_total + hits' dimensions
              + 5*sizeof(int);        // rank, nproc, decomposition

    // Decompose each variable and calculate output buffer size
    print0 ("Get info on variable %s\n",v1name); 
    vinfo = adios_inq_var (f, v1name);
    if (vinfo == NULL) {
        print ("rank %d: ERROR: Variable inquiry on %s failed: %s\n", 
                rank, v1name, adios_errmsg());
        return 1;
    }
    print_type_and_dimensions (vinfo);

    // determine subset we will query/write
    decompose (numproc, rank, vinfo->ndim, vinfo->dims, decomp_values,
            ldims, offs, &sum_count);

    v1 = malloc (sum_count * sizeof(double));
    v2 = malloc (sum_count * sizeof(double));

    groupsize += 2 * sum_count * sizeof(double); // v1 + v2

    return retval;
}

int do_queries(int step)
{
    // limit the query to the bounding box of this process
    ADIOS_SELECTION *boxsel = adios_selection_boundingbox (vinfo->ndim, offs, ldims);
    ADIOS_QUERY *q1 = adios_query_create (f, boxsel, v1name, ADIOS_GTEQ, minstr);
    ADIOS_QUERY *q2 = adios_query_create (f, boxsel, v1name, ADIOS_LTEQ, maxstr);
    ADIOS_QUERY* q = adios_query_combine(q1, ADIOS_QUERY_OP_AND, q2);

    // We can call this with unknown too, just testing the default behavior here
    if (query_method != ADIOS_QUERY_METHOD_UNKNOWN)
        adios_query_set_method (q, query_method);

    if (q == NULL)  {
        print ("rank %d: ERROR: Query creation failed: %s\n", rank, adios_errmsg());
        return 1;
    }

    // retrieve the whole query result at once
    int64_t batchSize = vinfo->dims[0] * vinfo->dims[1];
    print ("rank %d: set upper limit to number of hits = %lld\n", rank, batchSize); 
    int hasMore =  adios_query_evaluate(q, boxsel, 0, batchSize, &hitlist);

    if (hasMore == -1) {
        print ("rank %d: Query failed. It returned a NULL list: %s\n", rank, adios_errmsg());
    } 
    else if (hasMore==1) 
    {
        print ("rank %d: ERROR: Query retrieval failure: "
               "it says it has more results to retrieve, although we "
               "tried to get all at once\n", rank);
    }
    
    if (hitlist) {
        nhits = hitlist->u.points.npoints;
        print ("rank %d: Query returned %lld hits\n", rank, nhits);
    } else {
        nhits = 0;
        print ("rank %d: Query returned zero hits\n", rank);
    }



    adios_query_free(q);
    adios_query_free(q2);
    adios_query_free(q1);
    groupsize += 0; // FIXME: Add size of hitlist here

    // FIXME: Gather all npoints to rank 0
    nhits_total = 0; 
    MPI_Allreduce (&nhits, &nhits_total, 1, MPI_LONG_LONG, MPI_SUM, comm);

    print0 ("rank %d: Total number of hits: %lld\n", rank, nhits_total);

    adios_selection_delete (boxsel);
    return 0;
}

int read_vars(int step)
{
    // initialize v1/v2 array 
    int i, j, k=0;
    for (i=0; i<ldims[0]; i++) {
        for (j=0; j<ldims[1]; j++) {
            v1[k] = fillval;
            v2[k] = fillval;
            k++;
        }
    }

    // read the pointlist and add values to v1
    if (hitlist) {
        hitdata = (double *) malloc (nhits * sizeof(double));

        adios_schedule_read (f, hitlist, v1name, 1, 1, hitdata);
        adios_perform_reads (f, 1);   

        for (k=0; k < nhits; k++) {
            i = hitlist->u.points.points[2*k] - offs[0];
            j = hitlist->u.points.points[2*k+1] - offs[1];
            v1 [i*ldims[1]+j] = hitdata[k];
        }

        // do the same for v2
        adios_schedule_read (f, hitlist, v2name, 1, 1, hitdata);
        adios_perform_reads (f, 1);   

        for (k=0; k < nhits; k++) {
            i = hitlist->u.points.points[2*k] - offs[0];
            j = hitlist->u.points.points[2*k+1] - offs[1];
            v2 [i*ldims[1]+j] = hitdata[k];
        }

    } else {
        hitdata = NULL;
    }
        
    /* Validate result here */
    // read the original v1 completely and do manual evaluation
    double *v1m = (double *) malloc (ldims[0]*ldims[1]*sizeof(double));
    ADIOS_SELECTION *sel = adios_selection_boundingbox (vinfo->ndim, offs, ldims);
    adios_schedule_read (f, sel, v1name, 1, 1, v1m);
    adios_perform_reads (f, 1);   
    adios_selection_delete (sel);

    // manually evaluate query on xy and store in xy/manual
    k=0; uint64_t manualhits=0;
    for (i=0; i<ldims[0]; i++) {
        for (j=0; j<ldims[1]; j++) {
            if (v1m[k] >= minval && v1m[k] <= maxval) {
                manualhits++;
            } else {
                v1m[k] = fillval;
            }
            k++;
        }
    }
    if (nhits != manualhits) {
        print ("rank %d: Validation Error: Manual query evaluation found %lld "
                "hits in contrast to query engine which found %lld hits\n", 
                rank, manualhits, nhits);
    }
    free(v1m);
        
    return 0;
}

int write_vars(int step)
{
    int retval = 0;
    int i;
    uint64_t total_size;
    int64_t    fh;     // ADIOS output file handle

    // open output file
    adios_open (&fh, "range", outfilename, (step==1 ? "w" : "a"), comm);
    adios_group_size (fh, groupsize, &total_size);
    
    adios_write(fh, "gdim1", &vinfo->dims[0]);
    adios_write(fh, "gdim2", &vinfo->dims[1]);
    adios_write(fh, "ldim1", &ldims[0]);
    adios_write(fh, "ldim2", &ldims[1]);
    adios_write(fh, "off1",  &offs[0]);
    adios_write(fh, "off2",  &offs[1]);

    if (rank == 0) 
    {
        adios_write(fh, "nhits_total", &nhits_total);
    }

    adios_write(fh, v1name, v1);
    adios_write(fh, v2name, v2);

    adios_close (fh); // write out output buffer to file
    return retval;
}



