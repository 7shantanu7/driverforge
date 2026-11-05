include(FetchContent)

# GoogleTest is pinned by content hash, not just by version, so a tampered
# or silently re-generated archive fails the build instead of being trusted.
# FIND_PACKAGE_ARGS means an installed GTest (distro libgtest-dev, the dev
# container) is used first, so offline and air-gapped builds still work and
# the network is only touched as a fallback. Two mirrors, one hash.
set(GPU_STACK_GTEST_VERSION 1.17.0)
FetchContent_Declare(
    googletest
    URL
        https://launchpadlibrarian.net/811312893/googletest_${GPU_STACK_GTEST_VERSION}.orig.tar.gz
        https://archive.ubuntu.com/ubuntu/pool/universe/g/googletest/googletest_${GPU_STACK_GTEST_VERSION}.orig.tar.gz
    URL_HASH SHA256=3dc65ed118d82feb8276176354568e66acefee362d2b615e798bdd6c656377ff
    DOWNLOAD_EXTRACT_TIMESTAMP ON
    FIND_PACKAGE_ARGS NAMES GTest
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)
if(TARGET gtest_main)
    message(STATUS "Using GoogleTest ${GPU_STACK_GTEST_VERSION} from pinned archive")
else()
    message(STATUS "Using installed GoogleTest (find_package)")
endif()

include(GoogleTest)

# Tests listed in quarantine.txt still build and still run nightly, but are
# labelled so the blocking PR pipeline can skip them with -LE quarantined.
# This keeps a known-flaky test from blocking everyone without deleting it.
file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/quarantine.txt GPU_STACK_QUARANTINED REGEX "^[^#].*")

# Small helper: one gtest executable per area, so failures are easy to
# attribute and test binaries stay fast to rebuild.
function(gpu_stack_add_gtest name)
    cmake_parse_arguments(ARG "" "" "SOURCES;LIBS;LABELS" ${ARGN})
    add_executable(${name} ${ARG_SOURCES})
    target_link_libraries(${name} PRIVATE ${ARG_LIBS} GTest::gtest_main)
    gpu_driver_stack_enable_warnings(${name})
    gtest_discover_tests(${name}
        PROPERTIES LABELS "unit;${ARG_LABELS}"
        DISCOVERY_TIMEOUT 60
    )
endfunction()

gpu_stack_add_gtest(core_tests
    SOURCES core_test.cpp submission_queue_test.cpp version_test.cpp
    LIBS gpu_driver_stack::gpu_core
    LABELS core
)

gpu_stack_add_gtest(shader_compiler_tests
    SOURCES shader_compiler_test.cpp
    LIBS shader_compiler_lib
    LABELS shader
)

if(TARGET software_rasterizer)
    gpu_stack_add_gtest(software_rasterizer_tests
        SOURCES software_rasterizer_test.cpp
        LIBS gpu_driver_stack::software_rasterizer
        LABELS software
    )
endif()

if(TARGET cuda_compute)
    # Skips (does not fail) on GPU-less runners; runs for real on GPU nodes.
    gpu_stack_add_gtest(cuda_compute_tests
        SOURCES ${PROJECT_SOURCE_DIR}/drivers/cuda/tests/saxpy_test.cpp
        LIBS gpu_driver_stack::cuda_compute
        LABELS cuda
    )
endif()

# Deliberately broken plugins. Each one fails ABI validation in a different
# way, so the loader's error paths are tested, not just the happy path.
foreach(_variant future_abi missing_symbol null_table)
    add_library(test_plugin_${_variant} MODULE plugins/test_plugin.c)
    target_link_libraries(test_plugin_${_variant} PRIVATE gpu_driver_stack::plugin_abi)
    string(TOUPPER ${_variant} _define)
    target_compile_definitions(test_plugin_${_variant} PRIVATE TEST_PLUGIN_${_define})
    gpu_driver_stack_enable_warnings(test_plugin_${_variant})
endforeach()

gpu_stack_add_gtest(plugin_loader_tests
    SOURCES plugin_loader_test.cpp
    LIBS gpu_driver_stack::gpu_core
    LABELS plugin
)
target_compile_definitions(plugin_loader_tests PRIVATE
    TEST_PLUGIN_FUTURE_ABI="$<TARGET_FILE:test_plugin_future_abi>"
    TEST_PLUGIN_MISSING_SYMBOL="$<TARGET_FILE:test_plugin_missing_symbol>"
    TEST_PLUGIN_NULL_TABLE="$<TARGET_FILE:test_plugin_null_table>"
)
add_dependencies(plugin_loader_tests test_plugin_future_abi test_plugin_missing_symbol test_plugin_null_table)
if(TARGET nvk_driver)
    target_compile_definitions(plugin_loader_tests PRIVATE
        NVK_DRIVER_PATH="$<TARGET_FILE_DIR:nvk_driver>/${NVK_DRIVER_SONAME}")
    add_dependencies(plugin_loader_tests nvk_driver)
endif()

# plugin_abi.h must stay valid C (and C++), with strict warnings on.
add_executable(c_abi_header_test c_abi_header_test.c)
target_link_libraries(c_abi_header_test PRIVATE gpu_driver_stack::plugin_abi)
gpu_driver_stack_enable_warnings(c_abi_header_test)
add_test(NAME CAbiHeaderCompilesAsC COMMAND c_abi_header_test)
set_tests_properties(CAbiHeaderCompilesAsC PROPERTIES LABELS "abi")

# Build-time codegen produced real artifacts with the right magic header.
add_test(NAME ShaderArtifactsGenerated
    COMMAND ${CMAKE_COMMAND}
        -DSHADER_DIR=${CMAKE_BINARY_DIR}/shader_compiler
        -DSHADERS=triangle,fullscreen
        -P ${CMAKE_CURRENT_SOURCE_DIR}/check_shader_artifacts.cmake
)
set_tests_properties(ShaderArtifactsGenerated PROPERTIES LABELS "shader")

# Install the project into a scratch prefix, then build a separate
# downstream project against it with find_package(). This is the test that
# proves the -dev package is actually consumable, including writing a
# third-party plugin against the installed SDK. Skipped when cross-compiling
# (the consumer would need its own toolchain setup).
if(GPU_STACK_ENABLE_INSTALL AND NOT CMAKE_CROSSCOMPILING AND NOT GPU_STACK_SANITIZE AND NOT GPU_STACK_COVERAGE)
    set(_prefix ${CMAKE_BINARY_DIR}/consumer-test/prefix)
    set(_consumer_build ${CMAKE_BINARY_DIR}/consumer-test/build)
    add_test(NAME InstallForConsumerTest
        COMMAND ${CMAKE_COMMAND} --install ${CMAKE_BINARY_DIR} --prefix ${_prefix} --config $<CONFIG>
    )
    set_tests_properties(InstallForConsumerTest PROPERTIES FIXTURES_SETUP installed_tree LABELS "install")

    add_test(NAME DownstreamConsumerBuild
        COMMAND ${CMAKE_CTEST_COMMAND}
            --build-and-test ${CMAKE_CURRENT_SOURCE_DIR}/consumer ${_consumer_build}
            --build-generator ${CMAKE_GENERATOR}
            --build-options
                -DCMAKE_PREFIX_PATH=${_prefix}
                # Explicit, because Debian-patched CMake does not search lib64
                # (the RPM layout). Real search-path discovery is covered by
                # the package install tests on Ubuntu, Debian and Fedora.
                -Dgpu_driver_stack_DIR=${_prefix}/${CMAKE_INSTALL_LIBDIR}/cmake/gpu_driver_stack
                -DCMAKE_BUILD_TYPE=$<CONFIG>
                -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
                -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
                -DEXPECTED_VERSION=${PROJECT_VERSION}
            --test-command ${CMAKE_CTEST_COMMAND} --output-on-failure
    )
    set_tests_properties(DownstreamConsumerBuild PROPERTIES FIXTURES_REQUIRED installed_tree LABELS "install")
endif()

# Python build tooling has its own unit tests. Run them with everything else.
find_package(Python3 3.8 COMPONENTS Interpreter)
if(Python3_FOUND)
    add_test(NAME BuildstatsPythonTests
        COMMAND ${Python3_EXECUTABLE} -m unittest discover -s tests -t . -v
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/tools/buildstats
    )
    set_tests_properties(BuildstatsPythonTests PROPERTIES LABELS "tooling")
endif()

# Apply quarantine labels last, after every test above exists.
foreach(_test IN LISTS GPU_STACK_QUARANTINED)
    string(STRIP "${_test}" _test)
    if(_test AND TEST "${_test}")
        set_property(TEST "${_test}" APPEND PROPERTY LABELS quarantined)
    endif()
endforeach()
