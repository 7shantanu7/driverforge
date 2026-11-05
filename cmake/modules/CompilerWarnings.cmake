option(GPU_STACK_WARNINGS_AS_ERRORS "Treat warnings as errors on project targets" ON)
option(GPU_STACK_CLANG_TIDY "Run clang-tidy on project targets while compiling" OFF)

if(GPU_STACK_CLANG_TIDY)
    find_program(GPU_STACK_CLANG_TIDY_EXE NAMES clang-tidy clang-tidy-18 clang-tidy-16 REQUIRED)
    message(STATUS "clang-tidy enabled: ${GPU_STACK_CLANG_TIDY_EXE}")
endif()

# Applies strict warnings (and optionally clang-tidy) to one of OUR targets.
# Deliberately PRIVATE and per-target, never global, so third-party code we
# pull in (e.g. GoogleTest) is never held to our own warning bar.
function(gpu_driver_stack_enable_warnings target)
    set(_warnings
        -Wall -Wextra -Wpedantic -Wshadow -Wnon-virtual-dtor -Wold-style-cast
        -Wcast-align -Woverloaded-virtual -Wnull-dereference -Wformat=2
    )
    set(_c_warnings -Wall -Wextra -Wpedantic -Wshadow -Wformat=2)
    if(GPU_STACK_WARNINGS_AS_ERRORS)
        list(APPEND _warnings -Werror)
        list(APPEND _c_warnings -Werror)
    endif()
    target_compile_options(${target} PRIVATE
        $<$<COMPILE_LANGUAGE:CXX>:${_warnings}>
        $<$<COMPILE_LANGUAGE:C>:${_c_warnings}>
    )
    if(GPU_STACK_CLANG_TIDY)
        set_target_properties(${target} PROPERTIES
            CXX_CLANG_TIDY "${GPU_STACK_CLANG_TIDY_EXE};--warnings-as-errors=*"
        )
    endif()
endfunction()
