# Picks a compiler cache automatically so nobody has to remember
# -DCMAKE_CXX_COMPILER_LAUNCHER=ccache. An explicit launcher always wins.
#
#   DRIVERFORGE_COMPILER_CACHE=auto     (default) sccache if SCCACHE_BUCKET or
#                                     SCCACHE_GCS_BUCKET is set (remote cache),
#                                     otherwise ccache, otherwise nothing
#   DRIVERFORGE_COMPILER_CACHE=ccache|sccache|none
set(DRIVERFORGE_COMPILER_CACHE "auto" CACHE STRING "Compiler cache: auto, ccache, sccache or none")
set_property(CACHE DRIVERFORGE_COMPILER_CACHE PROPERTY STRINGS auto ccache sccache none)

if(NOT CMAKE_CXX_COMPILER_LAUNCHER AND NOT DRIVERFORGE_COMPILER_CACHE STREQUAL "none")
    set(_driverforge_cache_choice "${DRIVERFORGE_COMPILER_CACHE}")
    if(_driverforge_cache_choice STREQUAL "auto")
        if(DEFINED ENV{SCCACHE_BUCKET} OR DEFINED ENV{SCCACHE_GCS_BUCKET})
            set(_driverforge_cache_choice "sccache")
        else()
            set(_driverforge_cache_choice "ccache")
        endif()
    endif()

    find_program(DRIVERFORGE_CACHE_PROGRAM ${_driverforge_cache_choice})
    if(DRIVERFORGE_CACHE_PROGRAM)
        foreach(_lang C CXX CUDA)
            set(CMAKE_${_lang}_COMPILER_LAUNCHER "${DRIVERFORGE_CACHE_PROGRAM}")
        endforeach()
        message(STATUS "Compiler cache enabled: ${DRIVERFORGE_CACHE_PROGRAM}")
    elseif(NOT DRIVERFORGE_COMPILER_CACHE STREQUAL "auto")
        message(FATAL_ERROR "DRIVERFORGE_COMPILER_CACHE=${DRIVERFORGE_COMPILER_CACHE} but it was not found")
    endif()
endif()
