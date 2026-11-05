add_executable(gpu_stack_info src/main.cpp)
add_executable(gpu_driver_stack::gpu_stack_info ALIAS gpu_stack_info)
set_target_properties(gpu_stack_info PROPERTIES OUTPUT_NAME gpu-stack-info)
target_link_libraries(gpu_stack_info PRIVATE gpu_driver_stack::gpu_core)

if(TARGET software_rasterizer)
    target_link_libraries(gpu_stack_info PRIVATE gpu_driver_stack::software_rasterizer)
    target_compile_definitions(gpu_stack_info PRIVATE GPU_STACK_HAVE_SOFTWARE_RENDERER)
endif()

# Where the installed plugin lives relative to the installed binary.
file(RELATIVE_PATH _bin_to_plugins
    /prefix/${CMAKE_INSTALL_BINDIR} /prefix/${GPU_STACK_PLUGIN_INSTALL_DIR})
target_compile_definitions(gpu_stack_info PRIVATE
    GPU_STACK_RELATIVE_PLUGIN_PATH="${_bin_to_plugins}/libnvk_driver.so.${GPU_STACK_PLUGIN_SOVERSION}"
)
gpu_driver_stack_enable_warnings(gpu_stack_info)

if(BUILD_TESTING)
    add_test(NAME GpuStackInfoVersion COMMAND gpu_stack_info --version)
    set_tests_properties(GpuStackInfoVersion PROPERTIES
        PASS_REGULAR_EXPRESSION "gpu-stack-info ${PROJECT_VERSION} "
        LABELS "smoke"
    )

    add_test(NAME GpuStackInfoFallback COMMAND gpu_stack_info)
    set_tests_properties(GpuStackInfoFallback PROPERTIES
        ENVIRONMENT "GPU_STACK_DRIVERS=/nonexistent/libnope.so"
        LABELS "smoke"
    )
    if(TARGET software_rasterizer)
        set_property(TEST GpuStackInfoFallback PROPERTY
            PASS_REGULAR_EXPRESSION "software_rasterizer")
    endif()

    if(TARGET nvk_driver)
        add_test(NAME GpuStackInfoLoadsPlugin COMMAND gpu_stack_info --require-plugin)
        set_tests_properties(GpuStackInfoLoadsPlugin PROPERTIES
            ENVIRONMENT "GPU_STACK_DRIVERS=$<TARGET_FILE_DIR:nvk_driver>/${NVK_DRIVER_SONAME}"
            PASS_REGULAR_EXPRESSION "plugin nvk_driver ${PROJECT_VERSION}"
            LABELS "plugin;smoke"
        )
    endif()
endif()
