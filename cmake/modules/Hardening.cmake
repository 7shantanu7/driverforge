# Distro-grade hardening flags (the same family Debian/Fedora apply to their
# packages, and what lintian/rpmlint look for). Applied globally because they
# do not change behaviour, only make exploitation harder. Compile flags are
# limited to C/C++ so nvcc (CUDA) never sees GCC-only options.
option(GPU_STACK_HARDENING "Enable stack protector, FORTIFY_SOURCE and full RELRO" ON)

if(GPU_STACK_HARDENING AND CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT GPU_STACK_SANITIZE)
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:-fstack-protector-strong>")
    # FORTIFY_SOURCE needs optimisation, so leave it out of Debug builds.
    add_compile_definitions("$<$<AND:$<COMPILE_LANGUAGE:C,CXX>,$<NOT:$<CONFIG:Debug>>>:_FORTIFY_SOURCE=2>")
    add_link_options(LINKER:-z,relro LINKER:-z,now LINKER:-z,noexecstack)
endif()
