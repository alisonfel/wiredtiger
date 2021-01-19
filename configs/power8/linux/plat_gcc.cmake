#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

cmake_minimum_required(VERSION 3.11.0)

set(CROSS_COMPILER_PREFIX "powerpc64-linux-gnu-" CACHE INTERNAL "" FORCE)

# XXX: Need to extract gcc version, currently assumed >= 7

string(APPEND gcc_base_c_flags " -Wformat-signedness")
string(APPEND gcc_base_c_flags " -Wjump-misses-init")
string(APPEND gcc_base_c_flags " -Wredundant-decls")
string(APPEND gcc_base_c_flags " -Wunused-macros")
string(APPEND gcc_base_c_flags " -Wvariadic-macros")
string(APPEND gcc_base_c_flags " -Wduplicated-cond")
string(APPEND gcc_base_c_flags " -Wlogical-op")
string(APPEND gcc_base_c_flags " -Wunused-const-variable=2")
string(APPEND gcc_base_c_flags " -Walloca")
string(APPEND gcc_base_c_flags " -Walloc-zero")
string(APPEND gcc_base_c_flags " -Wduplicated-branches")
string(APPEND gcc_base_c_flags " -Wformat-overflow=2")
string(APPEND gcc_base_c_flags " -Wformat-truncation=2")
string(APPEND gcc_base_c_flags " -Wrestrict")
