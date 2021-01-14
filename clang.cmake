#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.11.0)

SET(CMAKE_SYSTEM_NAME Generic)

SET(CROSS_COMPILER_PREFIX ${TARGET}-)

set(CMAKE_C_COMPILER "clang")
set(CMAKE_C_COMPILER_ID "Clang")
set(CMAKE_C_COMPILER_TARGET "${TARGET}")

set(CMAKE_CXX_COMPILER "clang++")
set(CMAKE_CXX_COMPILER_ID "Clang++")
set(CMAKE_CXX_COMPILER_TARGET "${TARGET}")

set(CMAKE_ASM_COMPILER "clang")
set(CMAKE_ASM_COMPILER_ID "Clang")
set(CMAKE_ASM_COMPILER_TARGET "${TARGET}")

string(APPEND clang_base_c_flags " -Weverything")
string(APPEND clang_base_c_flags " -Werror")
string(APPEND clang_base_c_flags " -Wno-cast-align")
string(APPEND clang_base_c_flags " -Wno-documentation-unknown-command")
string(APPEND clang_base_c_flags " -Wno-format-nonliteral")
string(APPEND clang_base_c_flags " -Wno-packed")
string(APPEND clang_base_c_flags " -Wno-padded")
string(APPEND clang_base_c_flags " -Wno-reserved-id-macro")
string(APPEND clang_base_c_flags " -Wno-zero-length-array")

set(CMAKE_C_FLAGS "${clang_base_c_flags}" CACHE STRING "" FORCE)

find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif(CCACHE_FOUND)
