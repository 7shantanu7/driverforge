# CPack configuration: one set of install rules, three package formats.
#
#   cpack -G DEB   ->  gpu-driver-stack, gpu-driver-stack-dev, gpu-driver-stack-tools
#                      (+ -dbgsym debug-symbol packages for RelWithDebInfo)
#   cpack -G RPM   ->  same split, Fedora/RHEL naming
#   cpack -G TGZ   ->  one relocatable tarball with everything
#
# Package names are defined in the top-level CMakeLists.txt so the doc
# directories and the package names can never drift apart.

set(CPACK_PACKAGE_NAME "gpu-driver-stack")
set(CPACK_PACKAGE_VENDOR "gpu_driver_stack project")
set(CPACK_PACKAGE_CONTACT "${GPU_STACK_MAINTAINER}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Mock NVK-inspired GPU driver stack")
set(CPACK_PACKAGE_HOMEPAGE_URL "${PROJECT_HOMEPAGE_URL}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE")
set(CPACK_RESOURCE_FILE_README "${PROJECT_SOURCE_DIR}/README.md")
set(CPACK_PACKAGE_DIRECTORY "${PROJECT_BINARY_DIR}/dist")
set(CPACK_THREADS 0)
set(CPACK_GENERATOR "TGZ;DEB")

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
    set(GPU_STACK_DEB_ARCH arm64)
    set(GPU_STACK_RPM_ARCH aarch64)
else()
    set(GPU_STACK_DEB_ARCH amd64)
    set(GPU_STACK_RPM_ARCH x86_64)
endif()
set(CPACK_SYSTEM_NAME "linux-${GPU_STACK_RPM_ARCH}")

# Tarball: everything in one relocatable archive (gpu-stack-info finds its
# plugin relative to itself, so it can be unpacked anywhere).
set(CPACK_ARCHIVE_COMPONENT_INSTALL OFF)
set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${PROJECT_VERSION}-${CPACK_SYSTEM_NAME}")

set(CPACK_COMPONENTS_ALL Runtime Development Tools)

# First line is the synopsis (kept short), the rest the extended description.
set(_gpu_stack_note "This is a build and release engineering showcase built around mock driver
 code. It does not drive real GPU hardware.")
set(CPACK_COMPONENT_RUNTIME_DESCRIPTION "Mock NVK-inspired GPU driver plugin and host tool
 Runtime part of gpu_driver_stack: the dlopen()-able nvk_driver plugin, the
 gpu-stack-info host tool and precompiled sample shaders.
 ${_gpu_stack_note}")
set(CPACK_COMPONENT_DEVELOPMENT_DESCRIPTION "SDK for the mock NVK-inspired GPU driver stack
 Headers, static libraries and CMake package files for building host
 applications against gpu_core, and the C plugin ABI header for writing
 driver plugins.
 ${_gpu_stack_note}")
set(CPACK_COMPONENT_TOOLS_DESCRIPTION "Mock shader compiler for gpu_driver_stack
 The shader_compiler tool used at build time to turn GLSL sources into mock
 SPIR-V artifacts.
 ${_gpu_stack_note}")
set(CPACK_COMPONENT_RUNTIME_DISPLAY_NAME "Runtime (driver plugin, gpu-stack-info, shaders)")
set(CPACK_COMPONENT_DEVELOPMENT_DISPLAY_NAME "SDK (headers, libraries, CMake config)")
set(CPACK_COMPONENT_DEVELOPMENT_DEPENDS Runtime)
set(CPACK_COMPONENT_TOOLS_DISPLAY_NAME "Tools (shader_compiler)")

# --- Debian ------------------------------------------------------------------
set(CPACK_DEB_COMPONENT_INSTALL ON)
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE ${GPU_STACK_DEB_ARCH})
set(CPACK_DEBIAN_PACKAGE_SECTION "libs")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_RELEASE 1)
set(CPACK_DEBIAN_RUNTIME_PACKAGE_NAME "${GPU_STACK_PACKAGE_NAME_RUNTIME}")
set(CPACK_DEBIAN_DEVELOPMENT_PACKAGE_NAME "${GPU_STACK_PACKAGE_NAME_DEVELOPMENT}")
set(CPACK_DEBIAN_DEVELOPMENT_PACKAGE_SECTION "libdevel")
set(CPACK_DEBIAN_TOOLS_PACKAGE_NAME "${GPU_STACK_PACKAGE_NAME_TOOLS}")
set(CPACK_DEBIAN_TOOLS_PACKAGE_SECTION "devel")
set(CPACK_DEBIAN_ENABLE_COMPONENT_DEPENDS ON)
# Separate -dbgsym packages: ship stripped binaries, keep symbols for crash
# triage, the way distros and driver vendors do. CPackDeb splits the debug
# info out itself (by build-id), so CPack must not strip files first.
# RPM debuginfo is left off: rpm rewrites source paths in DWARF, which
# conflicts with the -ffile-prefix-map remapping reproducible builds need.
if(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    set(CPACK_DEBIAN_DEBUGINFO_PACKAGE ON)
    set(CPACK_STRIP_FILES OFF)
else()
    set(CPACK_STRIP_FILES ON)
endif()
if(CMAKE_CROSSCOMPILING)
    # dpkg-shlibdeps cannot inspect foreign-architecture binaries here.
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS OFF)
    set(CPACK_DEBIAN_RUNTIME_PACKAGE_DEPENDS "libc6 (>= 2.34), libstdc++6 (>= 12)")
    set(CPACK_DEBIAN_TOOLS_PACKAGE_DEPENDS "libc6 (>= 2.34), libstdc++6 (>= 12)")
else()
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
endif()

# --- RPM ---------------------------------------------------------------------
set(CPACK_RPM_COMPONENT_INSTALL ON)
set(CPACK_RPM_FILE_NAME RPM-DEFAULT)
set(CPACK_RPM_PACKAGE_ARCHITECTURE ${GPU_STACK_RPM_ARCH})
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_PACKAGE_RELEASE 1)
set(CPACK_RPM_PACKAGE_GROUP "System Environment/Libraries")
set(CPACK_RPM_PACKAGE_DESCRIPTION "Mock NVK-inspired GPU driver stack used to demonstrate build and release engineering.")
set(CPACK_RPM_RUNTIME_PACKAGE_NAME "${GPU_STACK_PACKAGE_NAME_RUNTIME}")
set(CPACK_RPM_DEVELOPMENT_PACKAGE_NAME "${GPU_STACK_PACKAGE_NAME_RUNTIME}-devel")
set(CPACK_RPM_TOOLS_PACKAGE_NAME "${GPU_STACK_PACKAGE_NAME_TOOLS}")
set(CPACK_RPM_DEVELOPMENT_PACKAGE_REQUIRES "${GPU_STACK_PACKAGE_NAME_RUNTIME} = ${PROJECT_VERSION}")
set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION
    /usr/share/doc /usr/lib/cmake /usr/lib64/cmake /usr/share/gpu_driver_stack)

# Reproducible package metadata: derive timestamps from the commit, not the
# wall clock (honoured by CPack's archive generators when set).
if(DEFINED ENV{SOURCE_DATE_EPOCH})
    message(STATUS "SOURCE_DATE_EPOCH=$ENV{SOURCE_DATE_EPOCH} (reproducible package timestamps)")
endif()

include(CPack)
