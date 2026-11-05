# One switch for sanitizer builds instead of hand-written flag soup in every
# CI file:  -DDRIVERFORGE_SANITIZE=address,undefined   or   =thread
set(DRIVERFORGE_SANITIZE "" CACHE STRING "Comma-separated sanitizers (address,undefined | thread)")

if(DRIVERFORGE_SANITIZE)
    if(DRIVERFORGE_SANITIZE MATCHES "thread" AND DRIVERFORGE_SANITIZE MATCHES "address")
        message(FATAL_ERROR "ThreadSanitizer cannot be combined with AddressSanitizer")
    endif()
    set(_san_flags -fsanitize=${DRIVERFORGE_SANITIZE} -fno-omit-frame-pointer -fno-sanitize-recover=all)
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:${_san_flags}>")
    add_link_options(-fsanitize=${DRIVERFORGE_SANITIZE})
    message(STATUS "Sanitizers enabled: ${DRIVERFORGE_SANITIZE}")
endif()
