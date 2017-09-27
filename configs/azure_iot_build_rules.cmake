#Copyright (c) Microsoft. All rights reserved.
#Licensed under the MIT license. See LICENSE file in the project root for full license information.

# Silences a CMake warning, no apparent effect on the Azure IoT SDK
if(POLICY CMP0042)
    cmake_policy(SET CMP0042 NEW)
endif()

option(run_valgrind "set run_valgrind to ON if tests are to be run under valgrind/helgrind/drd. Default is OFF" OFF)
option(compileOption_C "passes a string to the command line of the C compiler" OFF)
option(compileOption_CXX "passes a string to the command line of the C++ compiler" OFF)

# These are the include folders. (assumes that this file is in a subdirectory of c-utility)
get_filename_component(SHARED_UTIL_FOLDER ${CMAKE_CURRENT_LIST_DIR} DIRECTORY)
set(SHARED_UTIL_FOLDER "${SHARED_UTIL_FOLDER}" CACHE INTERNAL "this is the sharedLib directory" FORCE)
set(SHARED_UTIL_INC_FOLDER ${SHARED_UTIL_FOLDER}/inc CACHE INTERNAL "this is what needs to be included if using sharedLib lib" FORCE)
set(SHARED_UTIL_SRC_FOLDER ${SHARED_UTIL_FOLDER}/src CACHE INTERNAL "this is what needs to be included when doing include sources" FORCE)
set(SHARED_UTIL_ADAPTER_FOLDER "${SHARED_UTIL_FOLDER}/adapters" CACHE INTERNAL "this is where the adapters live" FORCE)
# PAL will eventually absorb the contents of SHARED_UTIL_ADAPTER_FOLDER
set(SHARED_UTIL_PAL_FOLDER "${SHARED_UTIL_FOLDER}/pal" CACHE INTERNAL "this is the PAL common sources directory" FORCE)
set(SHARED_UTIL_PAL_INC_FOLDER "${SHARED_UTIL_FOLDER}/pal/inc" CACHE INTERNAL "this is the PAL include directory" FORCE)


#making a global variable to know if we are on linux, windows, or macosx.
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(WINDOWS TRUE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(LINUX TRUE)
    #on Linux, enable valgrind
    #these commands (MEMORYCHECK...) need to apear BEFORE include(CTest) or they will not have any effect
    find_program(MEMORYCHECK_COMMAND valgrind)
    set(MEMORYCHECK_COMMAND_OPTIONS "--leak-check=full --error-exitcode=1")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(MACOSX TRUE)
endif()

include(CTest)

include_directories(${SHARED_UTIL_INC_FOLDER})

include(CheckIncludeFiles)
CHECK_INCLUDE_FILES(stdint.h HAVE_STDINT_H)
CHECK_INCLUDE_FILES(stdbool.h HAVE_STDBOOL_H)

if ((NOT HAVE_STDINT_H) OR (NOT HAVE_STDBOOL_H))
    include_directories(${SHARED_UTIL_INC_FOLDER}/azure_c_shared_utility/windowsce)
endif()

# System-specific compiler flags
if(MSVC)
    if (WINCE) # Be lax with WEC 2013 compiler
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W3")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /W3")
        add_definitions(-DWIN32) #WEC 2013
    ELSE()
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W4")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /W4")
    endif()
elseif(UNIX) #LINUX OR APPLE
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -Werror")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC -Werror")
    if(NOT (IN_OPENWRT OR APPLE))
        set (CMAKE_C_FLAGS "-D_POSIX_C_SOURCE=200112L ${CMAKE_C_FLAGS}")
    endif()
endif()

enable_testing()

include(CheckSymbolExists)
function(detect_architecture symbol arch)
    if (NOT DEFINED ARCHITECTURE OR ARCHITECTURE STREQUAL "")
        set(CMAKE_REQUIRED_QUIET 1)
        check_symbol_exists("${symbol}" "" ARCHITECTURE_${arch})
        unset(CMAKE_REQUIRED_QUIET)

        # The output variable needs to be unique across invocations otherwise
        # CMake's crazy scope rules will keep it defined
        if (ARCHITECTURE_${arch})
            set(ARCHITECTURE "${arch}" PARENT_SCOPE)
            set(ARCHITECTURE_${arch} 1 PARENT_SCOPE)
            add_definitions(-DARCHITECTURE_${arch}=1)
        endif()
    endif()
endfunction()
if (MSVC)
    detect_architecture("_M_AMD64" x86_64)
    detect_architecture("_M_IX86" x86)
    detect_architecture("_M_ARM" ARM)
else()
    detect_architecture("__x86_64__" x86_64)
    detect_architecture("__i386__" x86)
    detect_architecture("__arm__" ARM)
endif()
if (NOT DEFINED ARCHITECTURE OR ARCHITECTURE STREQUAL "")
    set(ARCHITECTURE "GENERIC")
endif()
message(STATUS "target architecture: ${ARCHITECTURE}")

#if any compiler has a command line switch called "OFF" then it will need special care
if(NOT "${compileOption_C}" STREQUAL "OFF")
    set(CMAKE_C_FLAGS "${compileOption_C} ${CMAKE_C_FLAGS}")
endif()

if(NOT "${compileOption_CXX}" STREQUAL "OFF")
    set(CMAKE_CXX_FLAGS "${compileOption_CXX} ${CMAKE_CXX_FLAGS}")
endif()


include(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG("-std=c++11" CXX_FLAG_CXX11)

macro(compileAsC99)
  if (CMAKE_VERSION VERSION_LESS "3.1")
    if (CMAKE_C_COMPILER_ID STREQUAL "GNU")
      set (CMAKE_C_FLAGS "--std=c99 ${CMAKE_C_FLAGS}")
      if (CXX_FLAG_CXX11)
        set (CMAKE_CXX_FLAGS "--std=c++11 ${CMAKE_CXX_FLAGS}")
      else()
        set (CMAKE_CXX_FLAGS "--std=c++0x ${CMAKE_CXX_FLAGS}")
      endif()
    endif()
  else()
    set (CMAKE_C_STANDARD 99)
    set (CMAKE_CXX_STANDARD 11)
  endif()
endmacro(compileAsC99)

macro(compileAsC11)
  if (CXX_FLAG_CXX11)
    if (CMAKE_VERSION VERSION_LESS "3.1")
      if (CMAKE_C_COMPILER_ID STREQUAL "GNU")
        set (CMAKE_C_FLAGS "--std=c11 ${CMAKE_C_FLAGS}")
        set (CMAKE_C_FLAGS "-D_POSIX_C_SOURCE=200112L ${CMAKE_C_FLAGS}")
        set (CMAKE_CXX_FLAGS "--std=c++11 ${CMAKE_CXX_FLAGS}")
      endif()
    else()
      set (CMAKE_C_STANDARD 11)
      set (CMAKE_CXX_STANDARD 11)
    endif()
  else()
    if (CMAKE_C_COMPILER_ID STREQUAL "GNU")
        set (CMAKE_C_FLAGS "--std=c99 ${CMAKE_C_FLAGS}")
        set (CMAKE_CXX_FLAGS "--std=c++0x ${CMAKE_CXX_FLAGS}")
    else()
      set (CMAKE_C_STANDARD 11)
      set (CMAKE_CXX_STANDARD 11)
    endif()
  endif()
endmacro(compileAsC11)

compileAsC99()

IF(WIN32)
    #windows needs this define
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
    IF(WINCE)
        # Don't treat warning as errors for WEC 2013. WEC 2013 uses older compiler version
        add_definitions(/WX-)
    ELSE()
    # Make warning as error
    add_definitions(/WX)
    ENDIF()
ELSE()
    # Make warning as error
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror")
ENDIF(WIN32)


function(add_files_to_install filesToBeInstalled)
    set(INSTALL_H_FILES ${INSTALL_H_FILES} ${filesToBeInstalled} CACHE INTERNAL "Files that will be installed on the system")
endfunction()


