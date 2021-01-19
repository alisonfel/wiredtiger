#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

set(WT_ARCH "power8" CACHE STRING "")
set(WT_OS "linux" CACHE STRING "")
set(WT_POSIX ON CACHE BOOL "")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_GNU_SOURCE" CACHE STRING "" FORCE)
