# Cross-compiles for 64-bit Arm Linux (the architecture of NVIDIA Jetson and
# Grace) from an x86_64 host. Tests run under qemu-user, so the full ctest
# suite still executes in CI without Arm hardware.
#
#   cmake --preset cross-aarch64
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(DRIVERFORGE_CROSS_TRIPLE aarch64-linux-gnu)
# Lets find_* look in the Debian multiarch directories of the target. The
# install libdir (lib/aarch64-linux-gnu) is set in the cross-aarch64 preset,
# because GNUInstallDirs ignores multiarch when cross-compiling.
set(CMAKE_LIBRARY_ARCHITECTURE ${DRIVERFORGE_CROSS_TRIPLE})
set(CMAKE_C_COMPILER ${DRIVERFORGE_CROSS_TRIPLE}-gcc)
set(CMAKE_CXX_COMPILER ${DRIVERFORGE_CROSS_TRIPLE}-g++)

set(CMAKE_FIND_ROOT_PATH /usr/${DRIVERFORGE_CROSS_TRIPLE})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# ctest, gtest_discover_tests and add_custom_command (the shader codegen
# step) all prefix target executables with this, so they run under qemu.
find_program(DRIVERFORGE_QEMU qemu-${CMAKE_SYSTEM_PROCESSOR})
if(DRIVERFORGE_QEMU)
    set(CMAKE_CROSSCOMPILING_EMULATOR "${DRIVERFORGE_QEMU};-L;/usr/${DRIVERFORGE_CROSS_TRIPLE}")
endif()
