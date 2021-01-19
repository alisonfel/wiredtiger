#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

include(helpers.cmake)

set(exported_configs "")

# WiredTiger config options

config_choice(
    WT_ARCH
    "Target architecture for WiredTiger"
    OPTIONS
        "x86;WT_X86;"
        "arm64;WT_ARM64;"
        "power8;WT_POWER8;"
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
)

config_str(
    WT_BUFFER_ALIGNMENT_DEFAULT
    "WiredTiger buffer boundary aligment"
    DEFAULT 0
    EXPORT
    UNQUOTE
)

config_bool(
    HAVE_DIAGNOSTIC
    "Enable WiredTiger diagnostics"
    DEFAULT ON
    EXPORT
)

config_bool(
    HAVE_ATTACH
    ""
    DEFAULT OFF
    EXPORT
)

config_bool(
    ENABLE_STATIC
    "Compile as a static library"
    DEFAULT ON
)

config_bool(
    ENABLE_PYTHON
    ""
    DEFAULT OFF
    DEPENDS "NOT ENABLE_STATIC"
)


config_choice(
    SPINLOCK_TYPE
    "Set a spinlock type"
    OPTIONS
        "gcc;SPINLOCK_GCC;"
        "msvc;SPINLOCK_MSVC;WTWin"
        "pthread;SPINLOCK_PTHREAD_MUTEX;"
        "pthread_adaptive;SPINLOCK_PTHREAD_ADAPTIVE;"
    EXPORT
    UNQUOTE
)

config_str(
    CC_OPTIMIZE_LEVEL
    "CC optimisation level"
    DEFAULT "-O3"
)

config_str(
    VERSION_MAJOR
    "Major version number for WiredTiger"
    DEFAULT 10
)

config_str(
    VERSION_MINOR
    "Minor version number for WiredTiger"
    DEFAULT 0
)

config_str(
    VERSION_PATCH
    "Path version number for WiredTiger"
    DEFAULT 0
)

config_str(
    VERSION_STRING
    "Version string for WiredTiger"
    DEFAULT "WiredTiger 10.0.0 (Jan 1. 2021)"
)

if(HAVE_DIAGNOSTIC)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g" CACHE STRING "" FORCE)
endif()

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CC_OPTIMIZE_LEVEL}" CACHE STRING "" FORCE)

set(exported_configs_config "${exported_configs}" CACHE INTERNAL "")
