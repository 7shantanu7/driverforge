# Always static: the fallback must be available even when no plugin loads.
add_library(software_rasterizer STATIC
    src/software_rasterizer.cpp
)
add_library(gpu_driver_stack::software_rasterizer ALIAS software_rasterizer)

target_include_directories(software_rasterizer PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(software_rasterizer PUBLIC gpu_driver_stack::gpu_core)

gpu_driver_stack_enable_warnings(software_rasterizer)
