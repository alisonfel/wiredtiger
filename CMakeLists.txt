#
# Public Domain 2014-present MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.12.0)

project(WiredTiger C ASM)

include(tools/cmake/helpers.cmake)

# TODO
# AUTO DETERMINE WT_ARCH or WT_OS
# Extensions etc
# Clang version for compile flags
# Comments

if(NOT WT_ARCH OR NOT WT_OS)
    message(FATAL_ERROR "Need to pass in both WT_ARCH & WT_OS")
endif()

if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/configs/${WT_ARCH}/${WT_OS}/config.cmake")
    message(FATAL_ERROR "${WT_ARCH}/${WT_OS}/config.cmake does not exist")
endif()
include(configs/${WT_ARCH}/${WT_OS}/config.cmake)
include(configs/auto.cmake)
include(configs/base.cmake)

if(ENABLE_STRICT)
    if("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
        include(configs/gcc_strict.cmake)
    elseif("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
        include(configs/clang_strict.cmake)
    endif()
endif()

set(link_type "STATIC")
if(NOT ENABLE_STATIC)
    set(link_type "SHARED")
    SET_PROPERTY(GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS TRUE)
endif()

#add_subdirectory(ext/compressors/lz4)
#add_subdirectory(ext/compressors/nop)
#add_subdirectory(ext/compressors/snappy)
#add_subdirectory(ext/compressors/zlib)
#add_subdirectory(ext/compressors/zstd)

set(arch_host "")
set(plat_host "")
# Determine architecture host for our filelist parse
if(WT_X86)
    set(arch_host "X86_HOST")
elseif(WT_ARM640)
    set(arch_host "ARM64_HOST")
elseif(WT_POWER8)
    set(arch_host "POWERPC_HOST")
elseif(WT_ZSERIES)
    set(arch_host "ZSERIES_HOST")
endif()
# Determine platform host for our filelist parse
if(WT_POSIX)
    set(plat_host "POSIX_HOST")
elseif(WT_WIN)
    set(plat_host "WINDOWS_HOST")
endif()

# Collect all the library sources we need to compile from the source filelist
parse_filelist_source(${CMAKE_CURRENT_LIST_DIR}/dist/filelist ${arch_host} ${plat_host} wt_sources)
# Establish wiredtiger library target
add_library(wiredtiger ${link_type} ${wt_sources})

# Generate wiredtiger.h
configure_file(src/include/wiredtiger.in "include/wiredtiger.h" @ONLY)
# Generate our wiredtiger_config.h
configure_file(configs/wiredtiger_config.h.in "config/wiredtiger_config.h" @ONLY)
# Set our targets public and private includes
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
