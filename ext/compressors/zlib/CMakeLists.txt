#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.12.0)

project(zlib C)

config_bool(
    HAVE_BUILTIN_EXTENSION_ZLIB
    "Build zlib compression library"
    DEFAULT OFF
)

set(sources "zlib_compress.c")
if(ENABLE_STATIC)
    add_library(zlib STATIC EXCLUDE_FROM_ALL ${sources})
else()
    add_library(zlib SHARED EXCLUDE_FROM_ALL ${sources})
endif()
