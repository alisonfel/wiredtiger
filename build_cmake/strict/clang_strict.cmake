# Public Domain 2014-present MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
# See the file LICENSE for redistribution information.
#

string(APPEND clang_base_c_flags " -Weverything -Werror")
string(APPEND clang_base_c_flags " -Wno-cast-align")
string(APPEND clang_base_c_flags " -Wno-documentation-unknown-command")
string(APPEND clang_base_c_flags " -Wno-format-nonliteral")
string(APPEND clang_base_c_flags " -Wno-packed")
string(APPEND clang_base_c_flags " -Wno-padded")
string(APPEND clang_base_c_flags " -Wno-reserved-id-macro")
string(APPEND clang_base_c_flags " -Wno-zero-length-array")

# We should turn on cast-qual, but not as a fatal error: see WT-2690.
# For now, turn it off.
# w="$w -Wno-error=cast-qual"
string(APPEND clang_base_c_flags " -Wno-cast-qual")

# Turn off clang thread-safety-analysis, it doesn't like some of the
# code patterns in WiredTiger.
string(APPEND clang_base_c_flags " -Wno-thread-safety-analysis")

# On Centos 7.3.1611, system header files aren't compatible with
# -Wdisabled-macro-expansion.
string(APPEND clang_base_c_flags " -Wno-disabled-macro-expansion")

# We occasionally use an extra semicolon to indicate an empty loop or
# conditional body.
string(APPEND clang_base_c_flags " -Wno-extra-semi-stmt")

# Ignore unrecognized options.
string(APPEND clang_base_c_flags " -Wno-unknown-warning-option")

# TODO: Add Apple 4.1 check

# Set our base gcc flags to ensure it propogates to the rest of our build
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${clang_base_c_flags}" CACHE STRING "" FORCE)
