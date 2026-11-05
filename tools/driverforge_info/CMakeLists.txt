add_executable(driverforge_info src/main.cpp)
add_executable(driverforge::driverforge_info ALIAS driverforge_info)
set_target_properties(driverforge_info PROPERTIES OUTPUT_NAME driverforge-info)
target_link_libraries(driverforge_info PRIVATE driverforge::gpu_core)

if(TARGET software_rasterizer)
    target_link_libraries(driverforge_info PRIVATE driverforge::software_rasterizer)
    target_compile_definitions(driverforge_info PRIVATE DRIVERFORGE_HAVE_SOFTWARE_RENDERER)
endif()

# Where the installed plugin lives relative to the installed binary.
file(RELATIVE_PATH _bin_to_plugins
    /prefix/${CMAKE_INSTALL_BINDIR} /prefix/${DRIVERFORGE_PLUGIN_INSTALL_DIR})
target_compile_definitions(driverforge_info PRIVATE
    DRIVERFORGE_RELATIVE_PLUGIN_PATH="${_bin_to_plugins}/libnvk_driver.so.${DRIVERFORGE_PLUGIN_SOVERSION}"
)
driverforge_enable_warnings(driverforge_info)

if(BUILD_TESTING)
    add_test(NAME DriverforgeInfoVersion COMMAND driverforge_info --version)
    set_tests_properties(DriverforgeInfoVersion PROPERTIES
        PASS_REGULAR_EXPRESSION "driverforge-info ${PROJECT_VERSION} "
        LABELS "smoke"
    )

    add_test(NAME DriverforgeInfoFallback COMMAND driverforge_info)
    set_tests_properties(DriverforgeInfoFallback PROPERTIES
        ENVIRONMENT "DRIVERFORGE_DRIVERS=/nonexistent/libnope.so"
        LABELS "smoke"
    )
    if(TARGET software_rasterizer)
        set_property(TEST DriverforgeInfoFallback PROPERTY
            PASS_REGULAR_EXPRESSION "software_rasterizer")
    endif()

    if(TARGET nvk_driver)
        add_test(NAME DriverforgeInfoLoadsPlugin COMMAND driverforge_info --require-plugin)
        set_tests_properties(DriverforgeInfoLoadsPlugin PROPERTIES
            ENVIRONMENT "DRIVERFORGE_DRIVERS=$<TARGET_FILE_DIR:nvk_driver>/${NVK_DRIVER_SONAME}"
            PASS_REGULAR_EXPRESSION "plugin nvk_driver ${PROJECT_VERSION}"
            LABELS "plugin;smoke"
        )
    endif()
endif()
