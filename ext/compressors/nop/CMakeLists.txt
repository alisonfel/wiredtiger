#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.12.0)

project(nop C)

config_bool(
    HAVE_BUILTIN_EXTENSION_NOP
    "Build nop compression library"
    DEFAULT OFF
)

set(sources "nop_compress.c")
if(ENABLE_STATIC)
    add_library(nop STATIC EXCLUDE_FROM_ALL ${sources})
else()
    add_library(nop SHARED EXCLUDE_FROM_ALL ${sources})
endif()
