##
## These two functions (rank2grid and grid2rank) map linear ranks
## to locations on a lattice. This can be done in many ways and is
## a generalization of "n-ary gray codes". Here I use simple
## "index on left moves faster" order. The order probably has a
## strong impact on performance! Need to get a better understanding.
rank2grid <- function(rank, lattice)
{
  ## converts linear rank to lattice location (my.grid)
  ## must have 0 <= rank <= prod(lattice) - 1
  
  lpg <- length(lattice)
  grid <- rep(NA, lpg)
  
  if(rank >= 0 && rank < prod(lattice))
    {
      base <- cumprod(c(1, lattice[ - length(lattice)]))
      remain <- rank
      for(d in lpg:1)
        {
          d.rev <- lpg - d + 1
          grid[d] <- remain %/% base[d] + 1
          remain <- remain %% base[d]
        }
    }
  else
    cat("rank:", rank, "and lattice:", lattice, "not compatible!\n")
  grid
}
grid2rank <- function(grid, lattice)
{
  ## converts lattice location (grid) to linear rank
  ## check for valid grid and lattice
  if(all(grid > 0 & grid <= lattice))
    {
      rank <- sum((grid - 1) *
                  c(1, cumprod(lattice)[-length(lattice)]))
    }
  else
    {
      cat("grid:", grid, "and lattice:", lattice,
          "not compatible!\n")
      rank <- NA
    }
  rank
}

best.local <- function(g.dim, split, domain=3, debug=0)
{
  ## Finds "best" fitting sub-hyperrectangle that splits across required
  ## dimensions into comm.size() pieces. Only +1 +2 tried in each dimension
  ## by enumeration in up to 3 dimensions for n processors.
  ##
  ## g.dim - global dimensions
  ## split - indicates over which dimensions to split (handles up to
  ##         3d split in a >= dimensional array)
  
  ## This produces homogeneous rectangular blocks. Some applications may
  ## admit heterogeneous blocks for better load balance.
  ## (Is this true and worth pursuing?)
  
  ## work only with the dimensions to split (restore before exit)
  split.dim <- g.dim[split]
  nsplit <- length(split.dim)
  data.points <- prod(split.dim)
  
  ## first set up with equal sides, then make proportional to dimensions
  points.per.cell <- floor(data.points / comm.size())
  base.loc.length <- floor(split.dim /
                           (data.points/points.per.cell)^(1 / nsplit))
  ## this should give a size that is a bit small to hold data.points
  loc.length <- base.loc.length
  
  keep.the.better <- function(best, new, split.dim)
    {
      ## get minimum covering processor grid
      ## (need mach.eps for rounding??)
      data.points <- prod(split.dim)
      
      best.grid <- ceiling(split.dim/best)
      best.n.points <- prod(best)*comm.size()
      best.n.slack <- best.n.points - data.points
      
      new.grid <- ceiling(split.dim/new)
      new.procs <- prod(new.grid)
      if(new.procs <= comm.size())
        {
          ## have enough procs to cover
          new.n.points <- prod(new)*comm.size() # global container
          new.grid.points <- prod(new*new.grid) # container pts
          new.n.slack <- new.n.points - data.points # slack
          
          if(debug > 1)
            {
              out <- paste(new, "covers", new.grid.points,
                           "elements with", new.procs,
                           "processors. Slack with all",
                           comm.size(), "is", new.n.slack,
                           "elements", collapse=" ")
              comm.print(out)
            }
          if(best.n.slack < 0)
            {
              ## accept since the first to have enough
              best <- new
            }
          else if(new.n.slack < best.n.slack)
            {
              ## new.n.slack is always positive because
              ##    new.grid is designed that way
              ## accept if new.n.slack is less
              best <- new
            }
          else if(new.n.slack == best.n.slack)
            {
              ## got one that's equally good
              if(debug > 1)
                comm.print(paste("Just as good", new,
                                 " but keeping first\n",
                                 collapse=" "))
            }
        }
      best
    }
  
  ## try all combinations of up to length 3
  combs <- combn(nsplit, min(3, nsplit), simplify=FALSE)
  for(c in combs)
    {
      if(length(c) == 1)
        ## try increases for 1d split
        for(add in 1:domain)
          {
            new <- base.loc.length
            new[c] <- new[c] + add
            loc.length <- keep.the.better(loc.length, new, split.dim)
          }
      else if(length(c) == 2)
        ## try increases for 2d split
        for(add1 in 0:domain)
          for(add2 in 0:domain)
            {
              new <- base.loc.length
              new[c[1]] <- new[c[1]] + add1
              new[c[2]] <- new[c[2]] + add2
              loc.length <- keep.the.better(loc.length, new, split.dim)
            }
      else if(length(c) == 3)
        ## try increases for 3d split
        for(add1 in 0:domain)
          for(add2 in 0:domain)
            for(add3 in 0:domain)
              {
                new <- base.loc.length
                new[c[1]] <- new[c[1]] + add1
                new[c[2]] <- new[c[2]] + add2
                new[c[3]] <- new[c[3]] + add3
                loc.length <- keep.the.better(loc.length, new, split.dim)
              }
    }
  
  ## restore all dimensions  
  loc.dim <- g.dim
  data.points <- prod(g.dim)
  loc.dim[split] <- loc.length
  best.grid <- ceiling(g.dim/loc.dim)
  best.n.points <- prod(loc.dim)*comm.size()
  best.n.slack <- best.n.points - prod(g.dim)
  
  if(debug)
    {
      comm.print(loc.dim)
      comm.print(paste("data.points:", data.points, collapse=" "))
      comm.print(paste("best.n.points:", best.n.points,
                       collapse=" "))
      comm.print(paste("best.n.slack:", best.n.slack, collapse=" "))
    }
  loc.dim
}

data.partition <- function(g.start, g.dim, split)
{
  ## Calls best.local to configure "optimal" local sizes according to split.
  ## Performs cleanup for partly full procs and empty procs.
  ##
  ## g.start - starting point for sub-hyperrectangle
  ## g.dim - global data dimensions of sub-hyperrectangle
  ## split - logical vector indicating dimensions to distribute
  ##
  ## Currently set up for 3d domain
  my.dim <- best.local(g.dim, split, domain=3)
  
  proc.grid <- ceiling(g.dim/my.dim)
  
  ## get my.grid and my.start
  if(comm.rank() < prod(proc.grid))
    {
      my.grid <- rank2grid(comm.rank(), proc.grid)
      my.start <- (my.grid - 1)*my.dim + g.start
      for(d in 1:length(my.dim))
        {
          ## fix me if I exceed global boundary
          if(my.start[d] + my.dim[d] > g.dim[d])
            my.dim[d] <- g.dim[d] - my.start[d] + 1
        }
    }
  else
    {
      ## I have no data
      my.dim <- my.start <- my.grid <- NULL
    }
  list(my.dim=my.dim, my.start=my.start, my.grid=my.grid)
}


