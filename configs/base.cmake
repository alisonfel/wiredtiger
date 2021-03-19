#
# Public Domain 2014-present MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

include(tools/cmake/helpers.cmake)

set(exported_configs "")

# WiredTiger config options

config_choice(
    WT_ARCH
    "Target architecture for WiredTiger"
    OPTIONS
        "x86;WT_X86;"
        "arm64;WT_ARM64;"
        "ppc64;WT_PPC64;"
        "zseries;WT_ZSERIES;"
)

config_choice(
    WT_OS
    "Target OS for WiredTiger"
    OPTIONS
        "darwin;WT_DARWIN;"
        "windows;WT_WIN;"
        "linux;WT_LINUX;"
)

config_bool(
    WT_POSIX
    "Is a posix platform"
    DEFAULT ON
    DEPENDS "WT_LINUX OR WT_DARWIN"
)

config_string(
    WT_BUFFER_ALIGNMENT_DEFAULT
    "WiredTiger buffer boundary aligment"
    DEFAULT 0
)

config_bool(
    HAVE_DIAGNOSTIC
    "Enable WiredTiger diagnostics"
    DEFAULT OFF
)

config_bool(
    HAVE_ATTACH
    ""
    DEFAULT OFF
)

config_bool(
    ENABLE_STATIC
    "Compile as a static library"
    DEFAULT ON
)

config_bool(
    ENABLE_STRICT
    "Compile with strict compiler warnings enabled"
    DEFAULT ON
)

config_bool(
    ENABLE_PYTHON
    ""
    DEFAULT OFF
    DEPENDS "NOT ENABLE_STATIC"
)

config_bool(
    WT_STANDALONE_BUILD
    "Support standalone build"
    DEFAULT ON
)

config_bool(
    HAVE_NO_CRC32_HARDWARE
    "Disable any crc32 hardware support"
    DEFAULT OFF
)

config_choice(
    SPINLOCK_TYPE
    "Set a spinlock type"
    OPTIONS
        "pthread;SPINLOCK_PTHREAD_MUTEX;HAVE_LIBPTHREAD"
        "gcc;SPINLOCK_GCC;"
        "msvc;SPINLOCK_MSVC;WT_WIN"
        "pthread_adaptive;SPINLOCK_PTHREAD_ADAPTIVE;HAVE_LIBPTHREAD"
)

config_string(
    CC_OPTIMIZE_LEVEL
    "CC optimisation level"
    DEFAULT "-O3"
)

config_string(
    VERSION_MAJOR
    "Major version number for WiredTiger"
    DEFAULT 10
)

config_string(
    VERSION_MINOR
    "Minor version number for WiredTiger"
    DEFAULT 0
)

config_string(
    VERSION_PATCH
    "Path version number for WiredTiger"
    DEFAULT 0
)

config_string(
    VERSION_STRING
    "Version string for WiredTiger"
    DEFAULT "\"WiredTiger 10.0.0 (Jan 1. 2021)\""
)

if(HAVE_DIAGNOSTIC)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g" CACHE STRING "" FORCE)
endif()

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CC_OPTIMIZE_LEVEL}" CACHE STRING "" FORCE)
