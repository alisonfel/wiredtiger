#
# Public Domain 2014-present MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.12.0)

project(nop_compression C)

set(sources "nop_compress.c")
if(ENABLE_STATIC)
    add_library(wiredtiger_nop STATIC ${sources})
else()
    add_library(wiredtiger_nop SHARED ${sources})
endif()

target_include_directories(
    wiredtiger_nop
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src/include
        ${CMAKE_BINARY_DIR}/include
        ${CMAKE_BINARY_DIR}/config
)
