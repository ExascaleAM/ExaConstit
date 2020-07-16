#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
An example script of how to work with ADIOS2 data files
Note, when the ADIOS2 library we use in ExaConstit required MPI and based
on my understanding of how the Python version works that also requires us to
use an MPI version here. In the future, we should be able to many of our common
post-processing scripts in a MPI friendly manner, but the current version doesn't
have that capability.

Also, I obtained ADIOS2 as conda package from here:
    https://anaconda.org/williamfgc/adios2-mpich
    williamfgc is one of the developers on the project

"""

import adios2
import numpy as np
from mpi4py import MPI

import matplotlib.pyplot as plt
from matplotlib import rc

# MPI related info
# comm = MPI.COMM_WORLD
# rank = comm.Get_rank()
# size = comm.Get_size()
# Want to set this to be the same number as the number of MPI ranks the
# simulation was run on
nranks = 12

#%%
# if( rank == 0 ):
fh = adios2.open("dir/to/output.bp", "r", engine_type="BP4")
# How to see what variables were printed out
# The time and cycle number are also saved off as well
init_vars = fh.available_variables()
# This is the total number of cycles that were saved off
# We always have the initial step saved off as well which is at time = 0
# Most of the data there is usually 0. However, the initial lattice orientation
# for each grain is saved off here which is nice to have.
steps = fh.steps()

con1d = list()
index = np.zeros((nranks, 2), dtype=np.int32)

iend = 0

# How to get out the initial end node vertices and connectivity array for everything
# ADIOS2 doesn't bother to save off the higher order values, so we only have
# the end nodes.
# Also, we have a ton of repeat vertices given in here, since it saved them off
# for each element
for i in range(nranks):
    if(i == 0):
        con = fh.read('connectivity', block_id=i)
        vert = fh.read('vertices', block_id=i)
        con1d.append(con[:, 1])
        con = con[:, 1::]
    else:
        tmp = fh.read('connectivity', block_id=i)
        con1d.append(tmp[:, 1])
        # The connectivity is the local processor one rather than the global
        # one. So, we increment the local one to have a global version
        tmp = tmp + np.max(con)
        con = np.vstack((con, tmp[:, 1::]))
        
        tmp = fh.read('vertices', block_id=i)
        vert = np.vstack((vert, tmp))

    # indexing variable that can be used later on
    index[i, 0] = iend
    iend = con.shape[0]
    index[i, 1] = iend
#%%
# An example of how to read data one step at a time
vm = np.empty((con.shape[0], steps - 1))
istep = 0
for fstep in fh:
    if(istep > 0):
        for i in range(nranks):
            arr = fstep.read('VonMisesStress', block_id=i)
            vm[index[i, 0]:index[i, 1], istep - 1] = arr[con1d[i]]
    istep = istep + 1

# An example for how to read the data off in chunks
# This could be useful if we have a large dataset to work with and you can only
# make use of a few steps at a time
hss = np.empty((con.shape[0], steps - 1))
for i in range(nranks):
    # So we need to figure out how many elements we need to read in
    isize = con1d[i].shape[0] * con.shape[1]
    # Note this method requires us to define start and count. We can't just
    # set step_start and step_count. Also, note the transpose at the end to work
    # in the same way as the previous method
    arr = fh.read('HydrostaticStress', start=[0], count=[isize], step_start=1, step_count=2, block_id=i).T
    hss[index[i, 0]:index[i, 1], :] = arr[con1d[i], :]
#%%
# Always make sure to close the file when you're finished loading data from it
fh.close()

#%%
# A short example showing some simple things that we can look at now that we have our data
# Here we're going to plot our hydrostatic stress at the last time step we were looking at
# It's important to remember that hydrostatic stress outputted from ExaConstit is
# 1/3 tr(\sigma) or -1 * p where p is the typical definition of pressure

# Here we're just going to plot a histogram of the hydrostatic stress at the last step

counts, bins = np.histogram(hss[:, -1], bins=25)
plt.hist(bins[:-1], bins, weights=counts)
