#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

set(WTArch "ZSERIES" CACHE STRING "")
set(WTOS "Linux" CACHE STRING "")
set(WTPosix ON CACHE BOOL "")

# Allow assembler to detect '.sx' file extensions 
list(APPEND CMAKE_ASM_SOURCE_FILE_EXTENSION "sx")
