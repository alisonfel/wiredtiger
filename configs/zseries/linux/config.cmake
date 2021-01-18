#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

set(WT_ARCH "ZSERIES" CACHE STRING "")
set(WT_OS "Linux" CACHE STRING "")
set(WT_POSIX ON CACHE BOOL "")

# Allow assembler to detect '.sx' file extensions 
list(APPEND CMAKE_ASM_SOURCE_FILE_EXTENSION "sx")
