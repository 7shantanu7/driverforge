include(GenerateExportHeader)

add_library(gpu_core
    src/command_buffer.cpp
    src/device.cpp
    src/plugin_loader.cpp
    src/shader_ir.cpp
    src/submission_queue.cpp
    src/version.cpp
)
add_library(driverforge::gpu_core ALIAS gpu_core)

set(GPU_CORE_GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)

# gpu_core_export.h defines GPU_CORE_EXPORT: visibility("default") when built
# as a shared library, nothing when static. Combined with the global
# hidden-by-default visibility, only annotated classes become public ABI.
generate_export_header(gpu_core
    EXPORT_FILE_NAME ${GPU_CORE_GENERATED_DIR}/include/gpu_core/gpu_core_export.h
)
if(NOT BUILD_SHARED_LIBS)
    target_compile_definitions(gpu_core PUBLIC GPU_CORE_STATIC_DEFINE)
endif()

configure_file(include/gpu_core/version.h.in
    ${GPU_CORE_GENERATED_DIR}/include/gpu_core/version.h @ONLY)
configure_file(src/gpu_core_build_info.h.in
    ${GPU_CORE_GENERATED_DIR}/private/gpu_core_build_info.h @ONLY)

# PUBLIC: our own .cpp files need these to find "gpu_core/*.h", AND anyone
# linking gpu_core inherits them. BUILD_INTERFACE/INSTALL_INTERFACE make the
# same target work from the build tree and from an installed package.
target_include_directories(gpu_core
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${GPU_CORE_GENERATED_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${GPU_CORE_GENERATED_DIR}/private
)
target_compile_features(gpu_core PUBLIC cxx_std_17)

find_package(Threads REQUIRED)
target_link_libraries(gpu_core PUBLIC Threads::Threads PRIVATE ${CMAKE_DL_LIBS})

set_target_properties(gpu_core PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    EXPORT_NAME gpu_core
)

driverforge_enable_warnings(gpu_core)

# Header-only target for people writing driver plugins. A plugin needs
# nothing but the C ABI header, never gpu_core itself.
add_library(plugin_abi INTERFACE)
add_library(driverforge::plugin_abi ALIAS plugin_abi)
target_include_directories(plugin_abi INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
