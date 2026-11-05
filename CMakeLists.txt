cmake_minimum_required(VERSION 3.25)

# The release version lives in exactly one place: the VERSION file at the
# repository root. CMake, CPack, the release workflow, Jenkins and GitLab all
# read it from there, so they can never disagree.
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" GPU_STACK_VERSION LIMIT_COUNT 1)

project(gpu_driver_stack
    VERSION ${GPU_STACK_VERSION}
    DESCRIPTION "NVK-inspired mock GPU driver stack used to demonstrate build and release engineering"
    HOMEPAGE_URL "https://github.com/7shantanu7/CICD"
    LANGUAGES C CXX
)

# The plugin ABI version is deliberately separate from the release version.
# It is the SOVERSION of every driver plugin and only changes when the plugin
# ABI breaks. scripts/check_abi.sh enforces that rule in CI.
set(GPU_STACK_PLUGIN_SOVERSION 1)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Hide every symbol by default. Each library opts symbols back in explicitly
# (export header for gpu_core, a linker version script for driver plugins),
# so the shipped ABI is exactly what we decided it is and nothing more.
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

include(GNUInstallDirs)
include(CompilerLauncher)
include(CompilerWarnings)
include(Sanitizers)
include(Hardening)
include(Reproducible)
include(Coverage)
include(BuildInfo)

option(ENABLE_DRIVER_NVK "Build the NVK-inspired mock driver plugin" ON)
option(ENABLE_SOFTWARE_RENDERER "Build the CPU fallback driver" ON)
option(ENABLE_CUDA "Build the optional CUDA compute backend (needs nvcc)" OFF)
option(BUILD_SHARED_LIBS "Build libraries as shared instead of static" OFF)
option(BUILD_TESTING "Build unit tests" ON)
option(GPU_STACK_ENABLE_INSTALL "Generate install rules and CPack packaging" ON)

# Plugins are installed into a private directory, not straight into libdir:
# they are loaded with dlopen() by the host and never linked against.
set(GPU_STACK_PLUGIN_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/gpu_driver_stack"
    CACHE STRING "Install directory for driver plugins, relative to the prefix")

# Installed executables find shared libraries relative to themselves, so the
# packages stay relocatable (tarball unpacked anywhere still works).
set(CMAKE_INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")

if(BUILD_TESTING)
    enable_testing()
endif()

add_subdirectory(core)
add_subdirectory(shader_compiler)

if(ENABLE_DRIVER_NVK)
    add_subdirectory(drivers/nvk)
endif()

if(ENABLE_SOFTWARE_RENDERER)
    add_subdirectory(drivers/software)
endif()

if(ENABLE_CUDA)
    # Enabled at the top level (not inside drivers/cuda) so every directory,
    # including tests/, knows the CUDA toolchain.
    if(NOT CMAKE_CUDA_ARCHITECTURES)
        # Ampere (A100) and Hopper (H100) by default; CI overrides per leg.
        set(CMAKE_CUDA_ARCHITECTURES 80 90)
    endif()
    enable_language(CUDA)
    add_subdirectory(drivers/cuda)
endif()

add_subdirectory(tools/gpu_stack_info)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

# Package names, shared by install rules (doc dirs) and CPack.
set(GPU_STACK_PACKAGE_NAME_RUNTIME "gpu-driver-stack")
set(GPU_STACK_PACKAGE_NAME_DEVELOPMENT "gpu-driver-stack-dev")
set(GPU_STACK_PACKAGE_NAME_TOOLS "gpu-driver-stack-tools")
set(GPU_STACK_MAINTAINER "Shantanu Zadbuke <7shantanu7@users.noreply.github.com>")

if(GPU_STACK_ENABLE_INSTALL)
    include(Install)
    include(Packaging)
endif()

message(STATUS "gpu_driver_stack ${PROJECT_VERSION} (plugin ABI ${GPU_STACK_PLUGIN_SOVERSION}), "
               "build type '${CMAKE_BUILD_TYPE}', compiler ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
