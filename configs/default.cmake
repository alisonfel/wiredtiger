#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

set(exported_configs)

include(helpers.cmake)

### Autoconf compatibility options

## Assert type sizes
assert_type_size("size_t" 8)
assert_type_size("ssize_t" 8)
assert_type_size("time_t" 8)
assert_type_size("off_t" 0)
assert_type_size("uintptr_t" 0)
test_type_size("uintmax_t" u_intmax_size)
test_type_size("unsigned long long" u_long_long_size)
set(default_uintmax_def " ")
if(${u_intmax_size} STREQUAL "")
    if(${unsigned long long} STREQUAL "")
        set(default_uintmax_def "typedef unsigned long uintmax_t\\;")
    else()
        set(default_uintmax_def "typedef unsigned long long uintmax_t\\;")
    endif()
endif()

config_str(
    off_t_decl
    "off_t type declaration (Autoconf backwards compatibility config)"
    DEFAULT
    "typedef off_t wt_off_t\\;"
)

config_str(
    uintprt_t_decl
    "uintptr_t type declaration (Autoconf backwards compatibility config)"
    DEFAULT "${default_uintmax_def}"
)

config_str(
    wiredtiger_includes_decl
    "WiredTiger standard lib includes definition block (Autoconf backwards compatibility config)"
    DEFAULT
    "#include <sys/types.h>
    #include <inttypes.h>
    #include <stdarg.h>
    #include <stdbool.h>
    #include <stdint.h>
    #include <stdio.h>"
)

config_include(
    HAVE_X86INTRIN_H
    "Include x86intrin.h exists"
    FILE "x86intrin.h"
    DEPENDS "WT_X86"
    HIDE_DISABLED
    EXPORT
)

config_func(
    HAVE_CLOCK_GETTIME
    "Function clock_gettime exists"
    FUNC "clock_gettime"
    FILES "time.h"
    EXPORT
)

config_func(
    HAVE_FALLOCATE
    "Function fallocate exists"
    FUNC "fallocate"
    FILES "fcntl.h"
    EXPORT
)

config_func(
    HAVE_FDATASYNC
    "Function fdatasync exists"
    FUNC "fdatasync"
    FILES "unistd.h"
    DEPENDS "NOT WT_DARWIN"
    EXPORT
)

config_func(
    HAVE_FTRUNCATE
    "Function ftruncate exists"
    FUNC "ftruncate"
    FILES "unistd.h;sys/types.h"
    EXPORT
)

config_func(
    HAVE_GETTIMEOFDAY
    "Function gettimeofday exists"
    FUNC "gettimeofday"
    FILES "sys/time.h"
    EXPORT
)

config_func(
    HAVE_POSIX_FADVISE
    "Function posix_fadvise exists"
    FUNC "posix_fadvise"
    FILES "fcntl.h"
    EXPORT
)

config_func(
    HAVE_POSIX_FALLOCATE
    "Function posix_fallocate exists"
    FUNC "posix_fallocate"
    FILES "fcntl.h"
    EXPORT
)

config_func(
    HAVE_POSIX_MADVISE
    "Function posix_madvise exists"
    FUNC "posix_madvise"
    FILES "sys/mman.h"
    EXPORT
)

config_func(
    HAVE_POSIX_MEMALIGN
    "Function posix_memalign exists"
    FUNC "posix_memalign"
    FILES "stdlib.h"
    EXPORT
)

config_func(
    HAVE_SETRLIMIT
    "Function setrlimit exists"
    FUNC "setrlimit"
    FILES "sys/time.h;sys/resource.h"
    EXPORT
)

config_func(
    HAVE_STRTOUQ
    "Function strtouq exists"
    FUNC "strtouq"
    FILES "stdlib.h"
    EXPORT
)

config_func(
    HAVE_SYNC_FILE_RANGE
    "Function sync_file_range exists"
    FUNC "sync_file_range"
    FILES "fcntl.h"
    EXPORT
)

config_func(
    HAVE_TIMER_CREATE
    "Function timer_create exists"
    FUNC "timer_create"
    FILES "signal.h;time.h"
    LINK_OPTIONS "-lrt"
    EXPORT
)

config_lib(
    HAVE_LIBPTHREAD
    "Pthread library exists"
    LIB "pthread"
    FUNC "pthread_create"
    EXPORT
)

config_lib(
    HAVE_LIBRT
    "rt library exists"
    LIB "rt"
    FUNC "timer_create"
    EXPORT
)

config_lib(
    HAVE_LIBDL
    "dl library exists"
    LIB "dl"
    FUNC "dlopen"
    EXPORT
)

set(exported_configs_default "${exported_configs}" CACHE INTERNAL "")
