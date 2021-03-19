#
# Public Domain 2014-present MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

include(CheckIncludeFiles)
include(CheckSymbolExists)
include(CheckLibraryExists)
include(CheckTypeSize)

function(eval_dependency depends enabled)
    # If no dependencies were given then we default to an enabled state
    if(("${depends}" STREQUAL "") OR ("${depends}" STREQUAL "NOTFOUND"))
        set(enabled ON PARENT_SCOPE)
        return()
    endif()
    # Evaluate each dependency
    set(is_enabled ON)
    foreach(dependency ${depends})
        string(REGEX REPLACE " +" ";" dependency "${dependency}")
        if(NOT (${dependency}))
            set(is_enabled OFF)
            break()
        endif()
    endforeach()
    set(enabled ${is_enabled} PARENT_SCOPE)
endfunction()

function(config_string config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_STR"
        "INTERNAL"
        "DEFAULT;DEPENDS"
        ""
    )
    if (NOT "${CONFIG_STR_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_str: ${CONFIG_STR_UNPARSED_ARGUMENTS}")
    endif()
    if ("${CONFIG_STR_DEFAULT}" STREQUAL "")
        message(FATAL_ERROR "No default value passed")
    endif()

    # Check that the configs dependencies are enabled before setting it to a visible enabled state
    eval_dependency("${CONFIG_STR_DEPENDS}" enabled)
    set(default_value "${CONFIG_STR_DEFAULT}")
    if(enabled)
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${default_value} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${default_value} CACHE STRING "${description}")
        endif()
        if (CONFIG_STR_INTERNAL)
            # Mark as an advanced variable, hiding it from initial UI's views
            mark_as_advanced(FORCE ${config_name})
        endif()
    else()
        set(${config_name} "${default_value}" CACHE INTERNAL "" FORCE)
        set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
    endif()
endfunction()

function(config_choice config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_OPT"
        ""
        ""
        "OPTIONS"
    )

    if (NOT "${CONFIG_OPT_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_opt: ${CONFIG_OPT_UNPARSED_ARGUMENTS}")
    endif()
    if ("${CONFIG_OPT_OPTIONS}" STREQUAL "")
        message(FATAL_ERROR "No options passed")
    endif()

    set(found_option ON)
    set(found_pre_set OFF)
    set(default_config_field "")
    set(default_config_var "")
    foreach(curr_option ${CONFIG_OPT_OPTIONS})
        list(LENGTH curr_option opt_length)
        if (NOT opt_length EQUAL 3)
            message(FATAL_ERROR "Invalid option list")
        endif()
        list(GET curr_option 0 option_config_field)
        list(GET curr_option 1 option_config_var)
        list(GET curr_option 2 option_depends)

        eval_dependency("${option_depends}" enabled)
        if(enabled)
            list(APPEND all_option_config_fields ${option_config_field})
            if (found_option)
                set(found_option OFF)
                set(default_config_field "${option_config_field}")
                set(default_config_var "${option_config_var}")
            endif()

            # Check if the option is already set with this given field
            if("${${config_name}}" STREQUAL "${option_config_field}")
                set(${option_config_var} ON CACHE INTERNAL "" FORCE)
                set(${config_name}_CONFIG_VAR ${option_config_var} CACHE INTERNAL "" FORCE)
                set(found_pre_set ON)
                set(found_option OFF)
                set(default_config_field "${option_config_field}")
                set(default_config_var "${option_config_var}")
            else()
                # Clear the cache of the current set value
                set(${option_config_var} OFF CACHE INTERNAL "" FORCE)
            endif()
        else()
            unset(${option_config_var} CACHE)
            # Check if the option is already set with this given field - we want to clear it if so
            if ("${${config_name}_CONFIG_VAR}" STREQUAL "${option_config_var}")
                unset(${config_name}_CONFIG_VAR CACHE)
            endif()
            if("${${config_name}}" STREQUAL "${option_config_field}")
                unset(${config_name} CACHE)
            endif()
        endif()
    endforeach()

    if(NOT found_pre_set)
        set(${default_config_var} ON CACHE INTERNAL "" FORCE)
        set(${config_name} ${default_config_field} CACHE STRING ${description})
        set(${config_name}_CONFIG_VAR ${default_config_var} CACHE INTERNAL "" FORCE)
    endif()
    set_property(CACHE ${config_name} PROPERTY STRINGS ${all_option_config_fields})
endfunction()

function(config_bool config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_BOOL"
        ""
        "DEFAULT;DEPENDS"
        ""
    )

    if (NOT "${CONFIG_BOOL_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_bool: ${CONFIG_BOOL_UNPARSED_ARGUMENTS}")
    endif()
    if ("${CONFIG_BOOL_DEFAULT}" STREQUAL "")
        message(FATAL_ERROR "No default value passed")
    endif()

    # Check that the configs dependencies are enabled before setting it to a visible enabled state
    eval_dependency("${CONFIG_BOOL_DEPENDS}" enabled)
    if(enabled)
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${CONFIG_BOOL_DEFAULT} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${CONFIG_BOOL_DEFAULT} CACHE STRING "${description}")
        endif()
    else()
        set(${config_name} OFF CACHE STRING "${description}" FORCE)
        set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
    endif()
endfunction()

function(config_func config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_FUNC"
        ""
        "FUNC;DEPENDS;FILES;LIBS"
        ""
    )

    if (NOT "${CONFIG_FUNC_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_func: ${CONFIG_FUNC_UNPARSED_ARGUMENTS}")
    endif()

    if ("${CONFIG_FUNC_FILES}" STREQUAL "")
        message(FATAL_ERROR "No file list passed")
    endif()

    if ("${CONFIG_FUNC_FUNC}" STREQUAL "")
        message(FATAL_ERROR "No function passed")
    endif()

    eval_dependency("${CONFIG_FUNC_DEPENDS}" enabled)
    if(enabled)
        set(CMAKE_REQUIRED_LIBRARIES "${CONFIG_FUNC_LIBS}")
        if((NOT "${WT_ARCH}" STREQUAL "") AND (NOT "${WT_ARCH}" STREQUAL ""))
            set(CMAKE_REQUIRED_FLAGS "-DWT_ARCH=${WT_ARCH} -DWT_OS=${WT_OS}")
        endif()
        check_symbol_exists(${CONFIG_FUNC_FUNC} "${CONFIG_FUNC_FILES}" has_symbol_${config_name})
        set(CMAKE_REQUIRED_LIBRARIES)
        set(CMAKE_REQUIRED_FLAGS)
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${has_symbol_${config_name}} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${has_symbol_${config_name}} CACHE STRING "${description}")
        endif()
        unset(has_symbol_${config_name} CACHE)
    else()
        set(${config_name} 0 CACHE INTERNAL "" FORCE)
        set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
    endif()
endfunction()

function(config_include config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_INCLUDE"
        ""
        "FILE;DEPENDS"
        ""
    )

    if (NOT "${CONFIG_INCLUDE_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_func: ${CONFIG_INCLUDE_UNPARSED_ARGUMENTS}")
    endif()

    if ("${CONFIG_INCLUDE_FILE}" STREQUAL "")
        message(FATAL_ERROR "No include file passed")
    endif()

    eval_dependency("${CONFIG_INCLUDE_DEPENDS}" enabled)
    if(enabled)
        set(CMAKE_REQUIRED_LINK_OPTIONS "${CONFIG_FUNC_LINK_OPTIONS}")
        if((NOT "${WT_ARCH}" STREQUAL "") AND (NOT "${WT_ARCH}" STREQUAL ""))
            set(CMAKE_REQUIRED_FLAGS "-DWT_ARCH=${WT_ARCH} -DWT_OS=${WT_OS}")
        endif()
        check_include_files(${CONFIG_INCLUDE_FILE} has_include_${config_name})
        set(CMAKE_REQUIRED_FLAGS)
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${has_include_${config_name}} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${has_include_${config_name}} CACHE STRING "${description}")
        endif()
        unset(has_include_${config_name} CACHE)
    else()
        set(${config_name} OFF CACHE INTERNAL "" FORCE)
        set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
    endif()
    if (${${config_name}})
        set(${config_name}_DECL "#include <${CONFIG_INCLUDE_FILE}>" CACHE INTERNAL "")
    endif()
endfunction()

function(config_lib config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_LIB"
        ""
        "LIB;FUNC;DEPENDS"
        ""
    )

    if (NOT "${CONFIG_LIB_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_lib: ${CONFIG_LIB_UNPARSED_ARGUMENTS}")
    endif()

    if ("${CONFIG_LIB_LIB}" STREQUAL "")
        message(FATAL_ERROR "No library passed")
    endif()

    if ("${CONFIG_LIB_FUNC}" STREQUAL "")
        message(FATAL_ERROR "No library function passed")
    endif()

    eval_dependency("${CONFIG_LIB_DEPENDS}" enabled)
    if(enabled)
        if((NOT "${WT_ARCH}" STREQUAL "") AND (NOT "${WT_ARCH}" STREQUAL ""))
            set(CMAKE_REQUIRED_FLAGS "-DWT_ARCH=${WT_ARCH} -DWT_OS=${WT_OS}")
        endif()
        check_library_exists(${CONFIG_LIB_LIB} ${CONFIG_LIB_FUNC} "" has_lib_${config_name})
        set(CMAKE_REQUIRED_FLAGS)
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${has_lib_${config_name}} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${has_lib_${config_name}} CACHE STRING "${description}")
        endif()
        unset(has_lib_${config_name} CACHE)
    else()
        set(${config_name} 0 CACHE INTERNAL "" FORCE)
        set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
    endif()
endfunction()

function(config_compile config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_COMPILE"
        ""
        "SOURCE;DEPENDS;LIBS"
        ""
    )

    if (NOT "${CONFIG_COMPILE_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_compile: ${CONFIG_COMPILE_UNPARSED_ARGUMENTS}")
    endif()

    if ("${CONFIG_COMPILE_SOURCE}" STREQUAL "")
        message(FATAL_ERROR "No source passed")
    endif()

    eval_dependency("${CONFIG_COMPILE_DEPENDS}" enabled)
    if(enabled)
        try_compile(
            can_compile_${config_name}
            ${CMAKE_CURRENT_BINARY_DIR}
            ${CONFIG_COMPILE_SOURCE}
            CMAKE_FLAGS "-DWT_ARCH=${WT_ARCH}" "-DWT_OS=${WT_OS}"
            LINK_LIBRARIES "${CONFIG_COMPILE_LIBS}"
        )
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${can_compile_${config_name}} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${can_compile_${config_name}} CACHE STRING "${description}")
        endif()
        unset(can_compile_${config_name} CACHE)
    else()
        set(${config_name} 0 CACHE INTERNAL "" FORCE)
        set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
    endif()
endfunction()

function(test_type_size type output_size)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "TEST_TYPE"
        ""
        ""
        "EXTRA_INCLUDES"
    )

    if (NOT "${TEST_TYPE_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to assert_type: ${TEST_TYPE_UNPARSED_ARGUMENTS}")
    endif()

    set(CMAKE_EXTRA_INCLUDE_FILES "${TEST_TYPE_EXTRA_INCLUDES}")
    check_type_size(${type} TEST_TYPE)
    set(CMAKE_EXTRA_INCLUDE_FILES)

    if(NOT HAVE_TEST_TYPE)
        set(${output_size} "" PARENT_SCOPE)
    else()
        set(${output_size} ${TEST_TYPE} PARENT_SCOPE)
    endif()
endfunction()


function(assert_type_size type size)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "ASSERT_TYPE"
        ""
        ""
        "EXTRA_INCLUDES"
    )

    if (NOT "${ASSERT_TYPE_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to assert_type: ${ASSERT_TYPE_UNPARSED_ARGUMENTS}")
    endif()

    set(additional_args "")
    if(${ASSERT_TYPE_EXTRA_INCLUDES})
        set(additional_args "EXTRA_INCLUDES ${ASSERT_TYPE_EXTRA_INCLUDES}")
    endif()
    test_type_size(${type} output_type_size ${additional_args})

    if(${output_type_size} EQUAL "")
        # Type does not exist
        message(FATAL_ERROR "Type assertion failed: ${type} does not exists")
    endif()

    if((NOT ${size} EQUAL 0) AND  (NOT ${output_type_size} EQUAL ${size}))
        # Type does not meet size assertion
        message(FATAL_ERROR "Type assertion failed: ${type} does not equal size ${size}")
    endif()
endfunction()

function(parse_filelist_source filelist output_var)
    set(arch_host "")
    set(plat_host "")
    # Determine architecture host for our filelist parse
    if(WT_X86)
        set(arch_host "X86_HOST")
    elseif(WT_ARM64)
        set(arch_host "ARM64_HOST")
    elseif(WT_PPC64)
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

    # Read file list and parse into list
    file(READ "${filelist}" contents NEWLINE_CONSUME)
    string(REGEX REPLACE "\n" ";" contents "${contents}")
    set(output_files "")
    foreach(file ${contents})
        if(${file} MATCHES "^#.*$")
            continue()
        endif()
        string(REGEX REPLACE "[ \t\r\]+" ";" file_contents ${file})
        list(LENGTH file_contents file_contents_len)
        if (file_contents_len EQUAL 1)
            list(APPEND output_files ${file})
        elseif(file_contents_len EQUAL 2)
            list(GET file_contents 0 file_name)
            list(GET file_contents 1 file_group)
            if ((${file_group} STREQUAL "${plat_host}") OR (${file_group} STREQUAL "${arch_host}"))
                list(APPEND output_files ${file_name})
            endif()
        else()
            message(FATAL_ERROR "filelist (${filelist}) has an unexpected format [Invalid Line: \"${file}]\"")
        endif()
    endforeach()
    set(${output_var} ${output_files} PARENT_SCOPE)
endfunction()
