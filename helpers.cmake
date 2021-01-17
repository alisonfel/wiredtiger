#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#  All rights reserved.
#
#  See the file LICENSE for redistribution information
#

cmake_minimum_required(VERSION 3.12.0)

include(CheckIncludeFiles)
include(CheckSymbolExists)
include(CheckTypeSize)

function(config_str config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_STR"
        "HIDE_DISABLED"
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
    set(enabled ON)
    if(NOT "${CONFIG_STR_DEPENDS}" STREQUAL "")
        foreach(dependency ${CONFIG_STR_DEPENDS})
            string(REGEX REPLACE " " ";" dependency "${dependency}")
            if(NOT ${dependency})
                set(enabled OFF)
            endif()
        endforeach()
    endif()

    if(enabled)
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${CONFIG_STR_DEFAULT} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${CONFIG_STR_DEFAULT} CACHE STRING "${description}")
        endif()
    else()
        if(${CONFIG_STR_HIDE_DISABLED})
            unset(${config_name} CACHE)
        else()
            set(${config_name} "${CONFIG_STR_DEFAULT}" CACHE INTERNAL "" FORCE)
            set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
        endif()
    endif()
endfunction(config_str)

function(config_choice config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_OPT"
        "DEFAULT_NONE"
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
        list(GET curr_depends 2 option_depends)

        set(enabled ON)
        if(NOT "${option_depends}" STREQUAL "NOTFOUND")
            if(NOT ${option_depends})
                set(enabled OFF)
            endif()
        endif()

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
                set(found_pre_set ON)
            else()
                # Clear the cache of the current set value
                set(${option_config_var} OFF CACHE INTERNAL "" FORCE)
            endif()
        else()
            unset(${option_config_var} CACHE)
        endif()
    endforeach()

    if(NOT ${CONFIG_OPT_DEFAULT_NONE})
        if(NOT found_pre_set)
            set(${default_config_var} ON CACHE INTERNAL "" FORCE)
        endif()
        set(${config_name} ${default_config_field} CACHE STRING ${description})
        set_property(CACHE ${config_name} PROPERTY STRINGS ${all_option_config_fields})
    endif()
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
    set(enabled ON)
    if(NOT "${CONFIG_BOOL_DEPENDS}" STREQUAL "")
        foreach(dependency ${CONFIG_BOOL_DEPENDS})
            string(REGEX REPLACE " " ";" dependency "${dependency}")
            if(NOT (${dependency}))
                set(enabled OFF)
            endif()
        endforeach()
    endif()

    if(enabled)
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${CONFIG_BOOL_DEFAULT} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${CONFIG_BOOL_DEFAULT} CACHE STRING "${description}")
        endif()
    else()
        set(${config_name} OFF CACHE INTERNAL "" FORCE)
        set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
    endif()
endfunction()


function(config_func config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_FUNC"
        ""
        "FUNC;DEPENDS;FILES;LINK_OPTIONS"
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

    set(enabled ON)
    if(NOT "${CONFIG_FUNC_DEPENDS}" STREQUAL "")
        foreach(dependency ${CONFIG_FUNC_DEPENDS})
            string(REGEX REPLACE " " ";" dependency "${dependency}")
            if(NOT (${dependency}))
                set(enabled OFF)
            endif()
        endforeach()
    endif()

    if(enabled)
        set(CMAKE_REQUIRED_LINK_OPTIONS "${CONFIG_FUNC_LINK_OPTIONS}")
        check_symbol_exists(${CONFIG_FUNC_FUNC} "${CONFIG_FUNC_FILES}" has_symbol_${config_name})
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

    set(enabled ON)
    if(NOT "${CONFIG_INCLUDE_DEPENDS}" STREQUAL "NOTFOUND")
        foreach(dependency ${CONFIG_INCLUDE_DEPENDS})
            string(REGEX REPLACE " " ";" dependency "${dependency}")
            if(NOT ${dependency})
                set(enabled OFF)
            endif()
        endforeach()
    endif()

    if(enabled)
        check_include_files(${CONFIG_INCLUDE_FILE} ${config_name})
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${${config_name}} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${${config_name}} CACHE STRING "${description}")
        endif()
    else()
        set(${config_name} OFF CACHE INTERNAL "" FORCE)
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
