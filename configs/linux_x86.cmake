#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

set(WTArch "X86" CACHE STRING "" FORCE)
set(WTOS "Linux" CACHE STRING "" FORCE)
set(WTPosix ON CACHE BOOL "" FORCE)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_GNU_SOURCE" CACHE STRING "" FORCE)

# Linux requires buffers aligned to 4KB boundaries for O_DIRECT to work.
set(WTBufferAlignment "4096" CACHE STRING "")
