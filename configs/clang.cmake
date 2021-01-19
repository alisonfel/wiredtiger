#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.11.0)


set(CMAKE_SYSTEM_NAME Generic)

set(CMAKE_C_COMPILER "clang")
set(CMAKE_C_COMPILER_ID "Clang")

set(CMAKE_CXX_COMPILER "clang++")
set(CMAKE_CXX_COMPILER_ID "Clang++")

set(CMAKE_ASM_COMPILER "clang")
set(CMAKE_ASM_COMPILER_ID "Clang")

string(APPEND clang_base_c_flags " -Weverything")
string(APPEND clang_base_c_flags " -Werror")
string(APPEND clang_base_c_flags " -Wno-cast-align")
string(APPEND clang_base_c_flags " -Wno-documentation-unknown-command")
string(APPEND clang_base_c_flags " -Wno-format-nonliteral")
string(APPEND clang_base_c_flags " -Wno-packed")
string(APPEND clang_base_c_flags " -Wno-padded")
string(APPEND clang_base_c_flags " -Wno-reserved-id-macro")
string(APPEND clang_base_c_flags " -Wno-zero-length-array")

string(APPEND clang_base_c_flags " -Wno-cast-qual")
string(APPEND clang_base_c_flags " -Wno-thread-safety-analysis")
string(APPEND clang_base_c_flags " -Wno-disabled-macro-expansion")
string(APPEND clang_base_c_flags " -Wno-extra-semi-stmt")
string(APPEND clang_base_c_flags " -Wno-unknown-warning-option")

if(NOT "${COMPILE_DEFINITIONS}" STREQUAL "")
    ### XXX: intermediate hack to overcome check_symbol_exits using toolchain file without WT_ARCH and WT_OS
    string(REGEX MATCH "-DWT_ARCH=([A-Za-z0-9]+) -DWT_OS=([A-Za-z0-9]+)" _ ${COMPILE_DEFINITIONS})
    set(wt_config_arch ${CMAKE_MATCH_1})
    set(wt_config_os ${CMAKE_MATCH_2})
else()
    set(wt_config_arch ${WT_ARCH})
    set(wt_config_os ${WT_OS})
endif()

if((NOT "${wt_config_arch}" STREQUAL "") AND (NOT "${wt_config_os}" STREQUAL ""))
    if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/${wt_config_arch}/${wt_config_os}/plat_clang.cmake")
        message(FATAL_ERROR "(${wt_config_arch}/${wt_config_os}) directory does not have a plat_clang.cmake file")
    endif()
    include("${CMAKE_CURRENT_LIST_DIR}/${wt_config_arch}/${wt_config_os}/plat_clang.cmake")
endif()

set(CMAKE_C_FLAGS "${clang_base_c_flags}" CACHE STRING "" FORCE)

find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif(CCACHE_FOUND)
