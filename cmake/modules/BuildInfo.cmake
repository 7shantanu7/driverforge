# Records which commit a binary came from, so a crash report or a bug in a
# shipped package can be traced back to source. CI passes DRIVERFORGE_GIT_SHA
# explicitly; local builds ask git. A fixed value (not a timestamp) keeps the
# build reproducible.
set(DRIVERFORGE_GIT_SHA "" CACHE STRING "Commit the build comes from (auto-detected if empty)")

if(NOT DRIVERFORGE_GIT_SHA)
    find_package(Git QUIET)
    if(GIT_FOUND)
        execute_process(
            COMMAND ${GIT_EXECUTABLE} rev-parse --short=12 HEAD
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            OUTPUT_VARIABLE _driverforge_sha
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
    endif()
    if(_driverforge_sha)
        set(DRIVERFORGE_GIT_SHA_RESOLVED "${_driverforge_sha}")
    else()
        set(DRIVERFORGE_GIT_SHA_RESOLVED "unknown")
    endif()
else()
    set(DRIVERFORGE_GIT_SHA_RESOLVED "${DRIVERFORGE_GIT_SHA}")
endif()
