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
# TCMalloc link
# Comments
# Complete all POSIX platforms

find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif(CCACHE_FOUND)

if(NOT WT_ARCH)
    # We will default defer to our callers host architecture as our target
    if ("${CMAKE_HOST_SYSTEM_PROCESSOR}" MATCHES "^(x86_64|i686|i386)$")
        set(WT_ARCH "x86")
    else()
        set(WT_ARCH "${CMAKE_HOST_SYSTEM_PROCESSOR}")
    endif()
endif()
if(NOT WT_OS)
    # We will default defer to the host OS as our target
    string(TOLOWER "${CMAKE_HOST_SYSTEM_NAME}" host_os)
    set(WT_OS "${host_os}")
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

# Include the extensions to the build
add_subdirectory(ext)

# Collect all the library sources we need to compile from the source filelist
parse_filelist_source(${CMAKE_CURRENT_LIST_DIR}/dist/filelist wt_sources)
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

if(HAVE_BUILTIN_EXTENSION_LZ4)
    target_link_libraries(wiredtiger wiredtiger_lz4)
endif()

if(HAVE_BUILTIN_EXTENSION_SNAPPY)
    target_link_libraries(wiredtiger wiredtiger_snappy)
endif()

if(HAVE_BUILTIN_EXTENSION_ZLIB)
    target_link_libraries(wiredtiger wiredtiger_zlib)
endif()

if(HAVE_BUILTIN_EXTENSION_ZSTD)
    target_link_libraries(wiredtiger wiredtiger_zstd)
endif()

# Establish our install target configuration
include(configs/install.cmake)
