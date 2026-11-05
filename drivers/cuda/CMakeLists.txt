# Optional CUDA backend (-DENABLE_CUDA=ON). CI builds it in the official
# nvidia/cuda containers for several CUDA versions and GPU architectures on
# runners WITHOUT a GPU, then checks the fat binary really contains code for
# every requested architecture (scripts/ci/check_cuda_fatbin.sh).
# CUDA itself is enabled in the top-level CMakeLists.txt.
find_package(CUDAToolkit REQUIRED)

add_library(cuda_compute STATIC src/saxpy.cu)
add_library(driverforge::cuda_compute ALIAS cuda_compute)
target_include_directories(cuda_compute PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_compile_features(cuda_compute PUBLIC cxx_std_17 PRIVATE cuda_std_17)
target_link_libraries(cuda_compute PUBLIC CUDA::cudart_static)
set_target_properties(cuda_compute PROPERTIES CUDA_SEPARABLE_COMPILATION OFF)
target_compile_options(cuda_compute PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:--Werror=all-warnings>
)

message(STATUS "CUDA ${CMAKE_CUDA_COMPILER_VERSION}, architectures: ${CMAKE_CUDA_ARCHITECTURES}")

# Tests are registered in tests/CMakeLists.txt, where GoogleTest is set up.
