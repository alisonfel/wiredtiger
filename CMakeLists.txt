#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.12.0)

project(WiredTiger C ASM)

if(WT_PLAT_CONFIG)
    include(configs/${WT_PLAT_CONFIG}.cmake)
endif()
include(config.cmake)
include(configs/default.cmake)

set(c_sources "")
set(asm_sources "")

file(GLOB c_sources CONFIGURE_DEPENDS
    "src/block/*.c"
    "src/bloom/*.c"
    "src/btree/*.c"
    "src/checksum/software/*.c"
    "src/config/*.c"
    "src/conn/*.c"
    "src/cursor/*.c"
    "src/evict/*.c"
    "src/history/*.c"
    "src/log/*.c"
    "src/lsm/*.c"
    "src/meta/*.c"
    "src/optrack/*.c"
    "src/os_common/*.c"
    "src/packing/*.c"
    "src/reconcile/*.c"
    "src/schema/*.c"
    "src/session/*.c"
    "src/support/*.c"
    "src/txn/*.c"
)

set(arch_c_sources "")
set(arch_asm_sources "")
if(WTX86)
    file(GLOB arch_c_sources CONFIGURE_DEPENDS "src/checksum/x86/*.c")
elseif(WTArm64)
    file(GLOB arch_c_sources CONFIGURE_DEPENDS "src/checksum/arm64/*.c")
elseif(WTPower8)
    file(GLOB arch_c_sources CONFIGURE_DEPENDS "src/checksum/wtPower8/*.c")
elseif(WTZseries)
    file(GLOB arch_c_sources CONFIGURE_DEPENDS "src/checksum/zseries/*.c" "src/checksum/zseries/*.sx")
    file(GLOB arch_asm_sources CONFIGURE_DEPENDS "src/checksum/zseries/*.sx")
endif()

set(plat_c_sources "")
if(WTPosix)
    file(GLOB plat_c_sources CONFIGURE_DEPENDS "src/os_posix/*.c")
endif()

if(WTWin)
    file(GLOB plat_c_sources CONFIGURE_DEPENDS "src/os_win/*.c")
endif()

list(APPEND c_sources ${arch_c_sources})
list(APPEND asm_sources ${arch_asm_sources})
set(wt_sources "${c_sources};${asm_sources}")

set(link_type "SHARED")
if(WTStatic)
    set(link_type "STATIC")
endif()

# Establish wiredtiger library target
add_library(wiredtiger ${link_type} ${wt_sources})

# Generate wiredtiger.h
configure_file(src/include/wiredtiger.in "include/wiredtiger.h" @ONLY)
target_include_directories(
    wiredtiger
    PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/include
)
