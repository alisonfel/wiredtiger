#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

include(helpers.cmake)

set(config "${defaults_config}")

# WiredTiger config options

config_choice(
    WTArch
    WT_ARCH
    "Target architecture for WiredTiger"
    OPTIONS
        "X86;WTX86;WT_X86;"
        "ARM64;WTArm64;WT_ARM64;"
        "POWER8;WTPower8;WT_POWER8;"
        "ZSERIES;WTZseries;WT_ZSERIES;"
)

config_choice(
    WTOS
    WT_OS
    "Target OS for WiredTiger"
    OPTIONS
        "Darwin;WTDarwin;WT_Darwin;"
        "Windows;WTWin;WT_WIN;"
        "Linux;WTLinux;WT_LINUX;"
)

config_bool(
    WTPosix
    WT_POSIX
    "Is a posix platform"
    DEFAULT
        ON
)

config_bool(
    WTStatic
    WT_STATIC
    "Compile as a static library"
    DEFAULT
        ON
)

config_str(
    WTBufferAlignment
    WT_BUFFER_ALIGNMENT
    "WiredTiger buffer boundary aligment"
    DEFAULT
        0
)

config_bool(
    WTEnableDiagnostic
    HAVE_DIAGNOSTIC
    "Enable WiredTiger diagnostics"
    DEFAULT
        OFF
)

config_bool(
    WTEnableAttach
    HAVE_ATTACH
    ""
    DEFAULT
        OFF
)

config_choice(
    WTWithSpinlock
    SPINLOCK_TYPE
    "Set a spinlock type"
    OPTIONS
        "gcc;wtSpinlockGCC;SPINLOCK_GCC;"
        "msvc;wtSpinlockMSVC;SPINLOCK_MSVC;WTWin"
        "pthread;wtSpinlockPthread;SPINLOCK_PTHREAD_MUTEX;"
        "pthread_adaptive;wtSpinlockPthread_adaptive;SPINLOCK_PTHREAD_ADAPTIVE;"
    DEFAULT_NONE
)

config_str(
    WTVersionMajor
    VERSION_MAJOR
    "Major version number for WiredTiger"
    DEFAULT
        10
)

config_str(
    WTVersionMinor
    VERSION_MINOR
    "Minor version number for WiredTiger"
    DEFAULT
        0
)

config_str(
    WTVersionPatch
    VERSION_PATCH
    "Path version number for WiredTiger"
    DEFAULT
        0
)

config_str(
    WTVersionString
    VERSION_STRING
    "Version string for WiredTiger"
    DEFAULT
    "WiredTiger 10.0.0 (Jan 1. 2021)"
    QUOTE_CONFIG
)
