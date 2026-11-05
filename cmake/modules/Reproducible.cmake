# Bit-for-bit reproducible builds: the same commit built in two different
# directories must produce identical binaries. scripts/check_reproducible.sh
# proves it in CI. The main source of drift is absolute paths baked into
# debug info and __FILE__, which -ffile-prefix-map rewrites.
option(GPU_STACK_REPRODUCIBLE "Strip build paths from binaries" ON)

if(GPU_STACK_REPRODUCIBLE AND NOT MSVC)
    add_compile_options(
        "$<$<COMPILE_LANGUAGE:C,CXX>:-ffile-prefix-map=${CMAKE_SOURCE_DIR}=.>"
        "$<$<COMPILE_LANGUAGE:C,CXX>:-ffile-prefix-map=${CMAKE_BINARY_DIR}=build>"
    )
endif()
