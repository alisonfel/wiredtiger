#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.12.0)

project(WiredTiger C ASM)

include(helpers.cmake)

if(NOT WT_ARCH OR NOT WT_OS)
    message(FATAL_ERROR "Need to pass in both WT_ARCH & WT_OS")
endif()

if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/configs/${WT_ARCH}/${WT_OS}/config.cmake")
    message(FATAL_ERROR "${WT_ARCH}/${WT_OS}/config.cmake does not exist")
endif()
include(configs/${WT_ARCH}/${WT_OS}/config.cmake)
include(config.cmake)
include(configs/default.cmake)

set(link_type "STATIC")
if(NOT ENABLE_STATIC)
    set(link_type "SHARED")
    SET_PROPERTY(GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS TRUE)
endif()

add_subdirectory(ext/compressors/lz4)
add_subdirectory(ext/compressors/nop)
add_subdirectory(ext/compressors/snappy)
add_subdirectory(ext/compressors/zlib)
add_subdirectory(ext/compressors/zstd)

set(c_sources "")
set(asm_sources "")
set(plat_sources "")

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
if(WT_X86)
    file(GLOB arch_c_sources CONFIGURE_DEPENDS "src/checksum/x86/*.c")
elseif(WT_ARM64)
    file(GLOB arch_c_sources CONFIGURE_DEPENDS "src/checksum/arm64/*.c")
elseif(WT_POWER8)
    file(GLOB arch_c_sources CONFIGURE_DEPENDS "src/checksum/wtPower8/*.c")
elseif(WT_ZSERIES)
    file(GLOB arch_c_sources CONFIGURE_DEPENDS "src/checksum/zseries/*.c" "src/checksum/zseries/*.sx")
    file(GLOB arch_asm_sources CONFIGURE_DEPENDS "src/checksum/zseries/*.sx")
endif()

set(plat_c_sources "")
if(WT_POSIX)
    file(GLOB plat_c_sources CONFIGURE_DEPENDS "src/os_posix/*.c")
endif()

if(WT_WIN)
    file(GLOB plat_c_sources CONFIGURE_DEPENDS "src/os_win/*.c")
endif()

list(APPEND c_sources ${arch_c_sources})
list(APPEND asm_sources ${arch_asm_sources})
list(APPEND plat_sources ${plat_c_sources})
set(wt_sources "${c_sources};${plat_sources};${asm_sources}")

# Establish wiredtiger library target
add_library(wiredtiger ${link_type} ${wt_sources})

# Generate wiredtiger.h
configure_file(src/include/wiredtiger.in "include/wiredtiger.h" @ONLY)
create_config_header("${exported_configs_config};${exported_configs_default}" "config/wiredtiger_config.h")
target_include_directories(
    wiredtiger
    PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/include
    PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/config ${CMAKE_CURRENT_LIST_DIR}/src/include
)

if(HAVE_LIBPTHREAD)
    target_link_libraries(wiredtiger "pthread")
endif()

if(HAVE_LIBRT)
    target_link_libraries(wiredtiger "rt")
endif()

if(HAVE_LIBDL)
    target_link_libraries(wiredtiger "dl")
endif()
