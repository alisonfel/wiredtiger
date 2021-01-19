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
include(CheckLibraryExists)
include(CheckTypeSize)

function(config_str config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_STR"
        "HIDE_DISABLED;EXPORT;UNQUOTE"
        "DEFAULT;DEPENDS"
        ""
    )
    if (NOT "${CONFIG_STR_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_str: ${CONFIG_STR_UNPARSED_ARGUMENTS}")
    endif()
    if ("${CONFIG_STR_DEFAULT}" STREQUAL "")
        message(FATAL_ERROR "No default value passed")
    endif()

    if(CONFIG_STR_UNQUOTE)
        set(quote "")
    else()
        set(quote "\"")
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

    set(default_value "${CONFIG_STR_DEFAULT}")
    if(enabled)
        # We want to ensure we capture a transition for a disabled to enabled state when dependencies are met
        if(${config_name}_DISABLED)
            unset(${config_name}_DISABLED CACHE)
            set(${config_name} ${default_value} CACHE STRING "${description}" FORCE)
        else()
            set(${config_name} ${default_value} CACHE STRING "${description}")
        endif()
    else()
        if(CONFIG_STR_HIDE_DISABLED)
            unset(${config_name} CACHE)
        else()
            set(${config_name} "${default_value}" CACHE INTERNAL "" FORCE)
            set(${config_name}_DISABLED ON CACHE INTERNAL "" FORCE)
        endif()
    endif()
    if(CONFIG_STR_EXPORT AND NOT CONFIG_STR_HIDE_DISABLED)
        set(new_exported_configs "${exported_configs}")
        list(APPEND new_exported_configs "#define ${config_name} ${quote}${${config_name}}${quote}")
        set(exported_configs "${new_exported_configs}" PARENT_SCOPE)
    endif()
endfunction(config_str)

function(config_choice config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_OPT"
        "DEFAULT_NONE;EXPORT;UNQUOTE;EXPORT_OPTIONS"
        ""
        "OPTIONS"
    )

    if (NOT "${CONFIG_OPT_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to config_opt: ${CONFIG_OPT_UNPARSED_ARGUMENTS}")
    endif()
    if ("${CONFIG_OPT_OPTIONS}" STREQUAL "")
        message(FATAL_ERROR "No options passed")
    endif()

    if(CONFIG_OPT_UNQUOTE)
        set(quote "")
    else()
        set(quote "\"")
    endif()

    set(new_exported_configs "${exported_configs}")
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
                set(found_option OFF)
                if(CONFIG_OPT_EXPORT_OPTIONS)
                    list(APPEND new_exported_configs "#define ${option_config_var} 1")
                endif()
                set(default_config_field "${option_config_field}")
                set(default_config_var "${option_config_var}")
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
            if(CONFIG_OPT_EXPORT_OPTIONS)
                list(APPEND new_exported_configs "#define ${default_config_var} 1")
            endif()
            set(${config_name} ${default_config_field} CACHE STRING ${description})
        endif()
        set_property(CACHE ${config_name} PROPERTY STRINGS ${all_option_config_fields})

        if(CONFIG_OPT_EXPORT)
            list(APPEND new_exported_configs "#define ${config_name} ${quote}${default_config_var}${quote}")
        endif()
    endif()
    set(exported_configs "${new_exported_configs}" PARENT_SCOPE)
endfunction()

function(config_bool config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_BOOL"
        "EXPORT"
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
    if(CONFIG_BOOL_EXPORT)
        set(new_exported_configs "${exported_configs}")
        list(APPEND new_exported_configs "#define ${config_name} ${${config_name}}")
        set(exported_configs "${new_exported_configs}" PARENT_SCOPE)
    endif()
endfunction()

function(config_func config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_FUNC"
        "EXPORT"
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
        if((NOT "${WT_ARCH}" STREQUAL "") AND (NOT "${WT_ARCH}" STREQUAL ""))
            set(CMAKE_REQUIRED_FLAGS "-DWT_ARCH=${WT_ARCH} -DWT_OS=${WT_OS}")
        endif()
        check_symbol_exists(${CONFIG_FUNC_FUNC} "${CONFIG_FUNC_FILES}" has_symbol_${config_name})
        set(CMAKE_REQUIRED_LINK_OPTIONS)
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
    if(CONFIG_FUNC_EXPORT)
        set(new_exported_configs "${exported_configs}")
        list(APPEND new_exported_configs "#define ${config_name} ${${config_name}}")
        set(exported_configs "${new_exported_configs}" PARENT_SCOPE)
    endif()
endfunction()

function(config_include config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_INCLUDE"
        "EXPORT;HIDE_DISABLED"
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
        set(CMAKE_REQUIRED_LINK_OPTIONS "${CONFIG_FUNC_LINK_OPTIONS}")
        if((NOT "${WT_ARCH}" STREQUAL "") AND (NOT "${WT_ARCH}" STREQUAL ""))
            set(CMAKE_REQUIRED_FLAGS "-DWT_ARCH=${WT_ARCH} -DWT_OS=${WT_OS}")
        endif()
        check_include_files(${CONFIG_INCLUDE_FILE} ${config_name})
        set(CMAKE_REQUIRED_FLAGS)
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
    if(CONFIG_INCLUDE_EXPORT AND (enabled AND NOT CONFIG_INCLUDED_HIDE_DISABLE))
        set(new_exported_configs "${exported_configs}")
        list(APPEND new_exported_configs "#define ${config_name} ${${config_name}}")
        set(exported_configs "${new_exported_configs}" PARENT_SCOPE)
    endif()
endfunction()

function(config_lib config_name description)
    cmake_parse_arguments(
        PARSE_ARGV
        2
        "CONFIG_LIB"
        "EXPORT"
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

    set(enabled ON)
    if(NOT "${CONFIG_LIB_DEPENDS}" STREQUAL "")
        foreach(dependency ${CONFIG_LIB_DEPENDS})
            string(REGEX REPLACE " " ";" dependency "${dependency}")
            if(NOT (${dependency}))
                set(enabled OFF)
            endif()
        endforeach()
    endif()

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
    if(CONFIG_LIB_EXPORT)
        set(new_exported_configs "${exported_configs}")
        list(APPEND new_exported_configs "#define ${config_name} ${${config_name}}")
        set(exported_configs "${new_exported_configs}" PARENT_SCOPE)
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

function(create_config_header config_string config_file)
    string(REPLACE ";" "\n" config_contents "${config_string};")
    file(GENERATE OUTPUT "${config_file}" CONTENT "${config_contents}")
endfunction()

function(extract_target_config input_target output_arch output_plat)
    string(REPLACE "-" ";" config_list "${input_target}")
    list(GET config_list 0 config_arch)
    list(GET config_list 1 config_plat)
    if(("${config_arch}" STREQUAL "NOTFOUND") OR ("${config_plat}" STREQUAL "NOTFOUND"))
        message(FATAL_ERROR "Invalid target variable")
    endif()
    set(${output_arch} "${config_arch}" PARENT_SCOPE)
    set(${output_plat} "${config_plat}" PARENT_SCOPE)
endfunction()
