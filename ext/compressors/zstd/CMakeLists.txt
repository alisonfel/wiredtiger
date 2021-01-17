#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.12.0)

project(zstd C)

config_bool(
    HAVE_BUILTIN_EXTENSION_ZSTD
    "Build zstd compression library"
    DEFAULT OFF
)

set(sources "zstd_compress.c")
if(ENABLE_STATIC)
    add_library(zstd STATIC EXCLUDE_FROM_ALL ${sources})
else()
    add_library(zstd SHARED EXCLUDE_FROM_ALL ${sources})
endif()
