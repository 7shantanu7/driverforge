# One switch for sanitizer builds instead of hand-written flag soup in every
# CI file:  -DGPU_STACK_SANITIZE=address,undefined   or   =thread
set(GPU_STACK_SANITIZE "" CACHE STRING "Comma-separated sanitizers (address,undefined | thread)")

if(GPU_STACK_SANITIZE)
    if(GPU_STACK_SANITIZE MATCHES "thread" AND GPU_STACK_SANITIZE MATCHES "address")
        message(FATAL_ERROR "ThreadSanitizer cannot be combined with AddressSanitizer")
    endif()
    set(_san_flags -fsanitize=${GPU_STACK_SANITIZE} -fno-omit-frame-pointer -fno-sanitize-recover=all)
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:${_san_flags}>")
    add_link_options(-fsanitize=${GPU_STACK_SANITIZE})
    message(STATUS "Sanitizers enabled: ${GPU_STACK_SANITIZE}")
endif()
