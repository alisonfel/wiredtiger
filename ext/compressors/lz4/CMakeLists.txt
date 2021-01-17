#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.12.0)

project(lz4 C)

config_bool(
    HAVE_BUILTIN_EXTENSION_LZ4
    "Build lz4 compression library"
    DEFAULT OFF
)

set(sources "lz4_compress.c")
if(ENABLE_STATIC)
    add_library(lz4 STATIC EXCLUDE_FROM_ALL ${sources})
else()
    add_library(lz4 SHARED EXCLUDE_FROM_ALL ${sources})
endif()
