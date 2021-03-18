#
# Public Domain 2014-present MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.11.0)


set(CMAKE_SYSTEM_NAME Generic)

if(NOT "${COMPILE_DEFINITIONS}" STREQUAL "")
    ### Additional check to overcome check_[symbol|include|function]_exits using toolchain file without passing WT_ARCH and WT_OS
    string(REGEX MATCH "-DWT_ARCH=([A-Za-z0-9]+) -DWT_OS=([A-Za-z0-9]+)" _ ${COMPILE_DEFINITIONS})
    set(wt_config_arch ${CMAKE_MATCH_1})
    set(wt_config_os ${CMAKE_MATCH_2})
else()
    set(wt_config_arch ${WT_ARCH})
    set(wt_config_os ${WT_OS})
endif()

if((NOT "${wt_config_arch}" STREQUAL "") AND (NOT "${wt_config_os}" STREQUAL ""))
    if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/${wt_config_arch}/${wt_config_os}/plat_gcc.cmake")
        message(FATAL_ERROR "(${wt_config_arch}/${wt_config_os}) directory does not have a plat_gcc.cmake file")
    endif()
    include("${CMAKE_CURRENT_LIST_DIR}/${wt_config_arch}/${wt_config_os}/plat_gcc.cmake")
endif()

set(CMAKE_C_COMPILER "${CROSS_COMPILER_PREFIX}gcc")
set(CMAKE_CXX_COMPILER "${CROSS_COMPILER_PREFIX}g++")
set(CMAKE_ASM_COMPILER "${CROSS_COMPILER_PREFIX}gcc")

if(ENABLE_STRICT)
    # Extract GCC version in-order to establish the correct compiler flags
    execute_process(
        COMMAND ${CMAKE_C_COMPILER} -dumpfullversion
        OUTPUT_VARIABLE gcc_version
        RESULT_VARIABLE status
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(status AND NOT status EQUAL 0)
        message(FATAL_ERROR "Failed to extract GCC version")
    endif()

    string(APPEND gcc_base_c_flags " -Wall")
    string(APPEND gcc_base_c_flags " -Wextra")
    string(APPEND gcc_base_c_flags " -Werror")
    string(APPEND gcc_base_c_flags " -Waggregate-return")
    string(APPEND gcc_base_c_flags " -Wbad-function-cast")
    string(APPEND gcc_base_c_flags " -Wcast-align")
    string(APPEND gcc_base_c_flags " -Wdeclaration-after-statement")
    string(APPEND gcc_base_c_flags " -Wdouble-promotion")
    string(APPEND gcc_base_c_flags " -Wfloat-equal")
    string(APPEND gcc_base_c_flags " -Wformat-nonliteral")
    string(APPEND gcc_base_c_flags " -Wformat-security")
    string(APPEND gcc_base_c_flags " -Wformat=2")
    string(APPEND gcc_base_c_flags " -Winit-self")
    string(APPEND gcc_base_c_flags " -Wjump-misses-init")
    string(APPEND gcc_base_c_flags " -Wmissing-declarations")
    string(APPEND gcc_base_c_flags " -Wmissing-field-initializers")
    string(APPEND gcc_base_c_flags " -Wmissing-prototypes")
    string(APPEND gcc_base_c_flags " -Wnested-externs")
    string(APPEND gcc_base_c_flags " -Wold-style-definition")
    string(APPEND gcc_base_c_flags " -Wpacked")
    string(APPEND gcc_base_c_flags " -Wpointer-arith")
    string(APPEND gcc_base_c_flags " -Wpointer-sign")
    string(APPEND gcc_base_c_flags " -Wredundant-decls")
    string(APPEND gcc_base_c_flags " -Wshadow")
    string(APPEND gcc_base_c_flags " -Wsign-conversion")
    string(APPEND gcc_base_c_flags " -Wstrict-prototypes")
    string(APPEND gcc_base_c_flags " -Wswitch-enum")
    string(APPEND gcc_base_c_flags " -Wundef")
    string(APPEND gcc_base_c_flags " -Wuninitialized")
    string(APPEND gcc_base_c_flags " -Wunreachable-code")
    string(APPEND gcc_base_c_flags " -Wunused")
    string(APPEND gcc_base_c_flags " -Wwrite-strings")

    # Non-fatal informational warnings.
    # We don't turn on the unsafe-loop-optimizations warning after gcc7,
    # it's too noisy to tolerate. Regardless, don't fail even when it's
    # configured.
    string(APPEND gcc_base_c_flags " -Wno-error=unsafe-loop-optimizations")
    if(gcc_version VERSION_EQUAL 4.7)
        string(APPEND gcc_base_c_flags " -Wno-c11-extensions")
        string(APPEND gcc_base_c_flags " -Wunsafe-loop-optimizations")
    elseif(gcc_version VERSION_EQUAL 5)
        string(APPEND gcc_base_c_flags " -Wunsafe-loop-optimizations")
    endif()

    if(gcc_version VERSION_GREATER_EQUAL 5)
        string(APPEND gcc_base_c_flags " -Wformat-signedness")
        string(APPEND gcc_base_c_flags " -Wjump-misses-init")
        string(APPEND gcc_base_c_flags " -Wredundant-decls")
        string(APPEND gcc_base_c_flags " -Wunused-macros")
        string(APPEND gcc_base_c_flags " -Wvariadic-macros")
    endif()
    if(gcc_version VERSION_GREATER_EQUAL 6)
        string(APPEND gcc_base_c_flags " -Wduplicated-cond")
        string(APPEND gcc_base_c_flags " -Wlogical-op")
        string(APPEND gcc_base_c_flags " -Wunused-const-variable=2")
    endif()
    if(gcc_version VERSION_GREATER_EQUAL 7)
        string(APPEND gcc_base_c_flags " -Walloca")
        string(APPEND gcc_base_c_flags " -Walloc-zero")
        string(APPEND gcc_base_c_flags " -Wduplicated-branches")
        string(APPEND gcc_base_c_flags " -Wformat-overflow=2")
        string(APPEND gcc_base_c_flags " -Wformat-truncation=2")
        string(APPEND gcc_base_c_flags " -Wrestrict")
    endif()
    if(gcc_version VERSION_GREATER_EQUAL 8)
        string(APPEND gcc_base_c_flags " -Wmultistatement-macros")
    endif()

    # Set our base gcc flags to ensure it propogates to the rest of our build
    set(CMAKE_C_FLAGS "${gcc_base_c_flags}" CACHE STRING "" FORCE)
endif()

find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif(CCACHE_FOUND)
