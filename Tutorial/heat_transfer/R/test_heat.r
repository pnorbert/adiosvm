library(pbdMPI, quiet = TRUE)
library(pbdDMAT, quiet = TRUE)
library(pbdADIOS, quiet = TRUE)
library(raster, quiet=TRUE)
library(ggplot2, quiet=TRUE)
library(grid, quiet=TRUE)

## begin function definitions

raster_plot <- function(x, nrow, ncol, basename="raster", sequence=1, swidth=3)
{
    x <- data.frame(rasterToPoints(raster(matrix(x, nrow, ncol),
                                          xmn=0, xmx=ncol, ymn=0, ymx=nrow)))
    names(x) <- c("x", "y", basename)
    png(paste(basename, "_", formatC(sequence, width=swidth, flag=0), "_",
              comm.rank(), ".png", sep=""))
    plot <- ggplot(x, aes_string(x="x", y="y", fill=basename)) +
            geom_raster() +
            scale_fill_distiller(palette = "Spectral", trans = "reverse") +
            theme_minimal() +
            theme(axis.text.x=element_blank(),
                  axis.ticks.x=element_blank(),
                  axis.title.x=element_blank(),
                  legend.position="none",
                  plot.margin=unit(c(0,0,0,0),"cm")
                 )
    print (plot)
    dev.off()
}
## end function definitions


## Initialize MPI and ADIOS 

init.grid() ## MPI/DMAT intializer
adios.init.noxml() ## Write without using XML ## WR
adios.read.init.method("ADIOS_READ_METHOD_BP", params="verbose=3") ## Initialize reading method

adios.set.max.buffersize(300) ## set max allocation size for ADIOS application in MB
groupname <- "restart" ## WR
adios_group_ptr <-  adios.declare.group(groupname,"", "adios_flag_yes") ## WR

adios.select.method(adios_group_ptr, "MPI", "", "") ## WR
filename <- "heat_R.bp" ## WR


## specify and open file for reading
#dir.data <- ".." 
#file <- paste(dir.data, "heat.bp", sep="/")
file <- "../heat.bp"

timeout.read <- 1 ## in sec
read.file.ptr <- adios.read.open(file, adios.timeout=timeout.read, "ADIOS_READ_METHOD_BP",
                          adios.lockmode="ADIOS_LOCKMODE_NONE") ## Calling adios read function

## select variable to read
variable <- "T"

## get variable dimensions
varinfo = adios.inq.var(read.file.ptr, variable)
block <- adios.inq.var.blockinfo(read.file.ptr, varinfo)

#comm.print("Before custom.inq.var.ndim")


ndim <- custom.inq.var.ndim(varinfo)
dims <- custom.inq.var.dims(varinfo)

## get dimensions and split
#source("pbdADIOS/tests/partition.r")
source("partition.r")

g.dim <- dims # global.dim on write
split <- c(TRUE, FALSE)
my.data.partition <- data.partition(seq(0, 0, along.with=g.dim), g.dim, split)
my.dim <- my.count <- my.data.partition$my.dim # local.dim on write
my.start <- my.data.partition$my.start # local.offset on write
my.grid <- my.data.partition$my.grid

adios.define.var(adios_group_ptr, "T", "", "adios_double", toString(my.dim), toString(g.dim), toString(my.start))  ## WR

errno <- 0 # Default value 0
steps <- 0
retval <- 0
bufsize <- 10
buffer <- matrix(NA, ncol=prod(my.count), nrow=bufsize)
a0 <- matrix(NA, ncol=prod(my.count), nrow=bufsize)
a1 <- matrix(NA, ncol=prod(my.count), nrow=bufsize)
a2 <- matrix(NA, ncol=prod(my.count), nrow=bufsize)
rhs <- cbind(rep(1, bufsize), poly(1:bufsize, degree=2))

while(errno != -21) { ## This is hard-coded for now. -21=err_end_of_stream
    steps = steps + 1 ## Double check with Norbert. Should it start with 1 or 2

    ## set reading bounding box
    adios.selection  <- adios.selection.boundingbox(ndim, my.start, my.count)
    comm.print("Selection.boundingbox complete ...")
    
    ## schedule the read
    adios.data <- adios.schedule.read(varinfo, my.start, my.count, read.file.ptr,
                                      adios.selection, variable, 0, 1)
    comm.print("Schedule read complete ...")
    
    ## perform the read
    adios.perform.reads(read.file.ptr, 1)
    comm.print("Perform read complete ...")

    data_chunk <- custom.data.access(adios.data, adios.selection, varinfo)
    comm.print("Data access complete ...")

    ## print a few to verify
    comm.cat("first 5:", head(data_chunk, 5),"\n")
    comm.cat("last 5:", tail(data_chunk, 5),"\n")

    ## shape into matrix with first dim as rows
    ## local reshape dimensions
    my.ncol <- prod(my.dim[2])
    my.nrow <- my.dim[1]
    ldim <- c(my.nrow, my.ncol)

    ## global reshape dimensions
    g.ncol <- prod(g.dim[2])
    g.nrow <- g.dim[1]
    gdim <- c(g.nrow, g.ncol)
    
    ## now glue into a ddmatrix
    ##  x <- matrix(data_chunk, nrow=my.nrow, ncol=my.ncol, byrow=FALSE)
    ##  X <- new("ddmatrix", Data=x, dim=gdim, ldim=ldim, bldim=ldim, ICTXT=2)

    ## Fit a quadratic to a moving window of 10 steps
    ## Actually don't need the ddmatrix for this and can go straight
    ## from data_chunk into buffer matrix
    buffer <- rbind(buffer[-1, ], data_chunk)

    ## plot the original local matrix (swapping row to col - C to R)
    raster_plot(data_chunk, my.ncol, my.nrow, "T", steps)
    
    ## fit data and plot three coefficient raster plots
    if(steps >= bufsize)
        {
            fit <- lm.fit(rhs, buffer)$coefficients
    ##         raster_plot(fit[1, ], my.ncol, my.nrow, "a0", steps)
    ##         raster_plot(fit[2, ], my.ncol, my.nrow, "a1", steps)
    ##         raster_plot(fit[3, ], my.ncol, my.nrow, "a2", steps)
      
    ## All these work fine!
    ##    X <- as.blockcyclic(X, bldim=c(4, 4))
    ##    X.pc <- prcomp(X)
    ##    comm.print(X.pc)
    
    ##
    ## Here, write out the results of the analysis
    a0 <- fit[1, ]
    a1 <- fit[2, ]
    a2 <- fit[3, ]
    ## now use adios to write (T, a0, a1, a2). All are with dimensions:
    ##       global.dim = g.dim
    ##       local.dim = my.dim = my.count
    ##       local.offset = my.start
  
     adios_file_ptr <- adios.open(groupname, filename, "a") ## WR

     groupsize <- object.size(data_chunk) ## Ask george       ## WR

     adios.group.size(adios_file_ptr, groupsize) ## WR
     adios.write(adios_file_ptr, "T", data_chunk) ## WR
     adios.close(adios_file_ptr) ## WR
     barrier() ## WR
     comm.print("Data write complete ...")

    ## insert adios writing code here  <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
     }
    
    ## try to get more data
    adios.advance.step(read.file.ptr, 0, adios.timeout.sec=1)
    comm.print(paste("Done advance.step", steps, "..."))
     
    ## check errors
    errno <- adios.errno()
    #comm.cat("Error Num",errno, "\n")

    ## if error is timeout (or EOF)
    if(errno == -22){ #-22 = err_step_notready
        comm.cat(comm.rank(), "Timeout waiting for more data. Quitting ...\n")
        break
    }
if(steps > 20) break
} # While end 

comm.print("Broke out of loop ...")
adios.read.close(read.file.ptr)
comm.print("File closed")
adios.read.finalize.method("ADIOS_READ_METHOD_BP")
comm.print("Finalized adios ...")

adios.finalize(pbdMPI:::comm.rank()) # ADIOS finalize ## WR

finalize() # pbdMPI finalize

