# MODULE, not SHARED: this library is only ever dlopen()ed, never linked.
# It still carries a SONAME and versioned file name, like a real ICD.
add_library(nvk_driver MODULE
    src/nvk_driver.cpp
)
add_library(gpu_driver_stack::nvk_driver ALIAS nvk_driver)

configure_file(src/nvk_driver_version.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/generated/nvk_driver_version.h @ONLY)

target_include_directories(nvk_driver PRIVATE
    src
    ${CMAKE_CURRENT_BINARY_DIR}/generated
)
# The plugin depends on the C ABI header ONLY, never on gpu_core.
target_link_libraries(nvk_driver PRIVATE gpu_driver_stack::plugin_abi)
target_compile_features(nvk_driver PRIVATE cxx_std_17)

gpu_driver_stack_enable_warnings(nvk_driver)

set(NVK_DRIVER_MAP ${CMAKE_CURRENT_SOURCE_DIR}/nvk_driver.map)
target_link_options(nvk_driver PRIVATE "LINKER:--version-script=${NVK_DRIVER_MAP}")
set_property(TARGET nvk_driver APPEND PROPERTY LINK_DEPENDS ${NVK_DRIVER_MAP})

# Refuse to link if the plugin has unresolved symbols. Sanitizer runtimes are
# resolved from the host executable, so skip the check for those builds.
if(NOT GPU_STACK_SANITIZE)
    target_link_options(nvk_driver PRIVATE "LINKER:-z,defs")
endif()

# MODULE libraries get no SONAME by default. Give it one by hand so the file
# layout matches what a real driver ships:
#   libnvk_driver.so.1.0.0   real file, SONAME libnvk_driver.so.1
#   libnvk_driver.so.1       symlink the host loads
set(NVK_DRIVER_SONAME libnvk_driver.so.${GPU_STACK_PLUGIN_SOVERSION})
set_target_properties(nvk_driver PROPERTIES
    OUTPUT_NAME nvk_driver
    SUFFIX ".so.${PROJECT_VERSION}"
)
target_link_options(nvk_driver PRIVATE "LINKER:-soname,${NVK_DRIVER_SONAME}")
add_custom_command(TARGET nvk_driver POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E create_symlink
            $<TARGET_FILE_NAME:nvk_driver>
            $<TARGET_FILE_DIR:nvk_driver>/${NVK_DRIVER_SONAME}
    COMMENT "Creating plugin symlink ${NVK_DRIVER_SONAME}"
    VERBATIM
)

set(NVK_DRIVER_SONAME ${NVK_DRIVER_SONAME} PARENT_SCOPE)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
