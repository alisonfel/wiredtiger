#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.11.0)

set(TRIPLE "ppc64-pc-linux-gnu")

set(CROSS_COMPILER_PREFIX ${TRIPLE}-)
set(CMAKE_C_COMPILER_TARGET "${TRIPLE}")
set(CMAKE_CXX_COMPILER_TARGET "${TRIPLE}")
set(CMAKE_ASM_COMPILER_TARGET "${TRIPLE}")
