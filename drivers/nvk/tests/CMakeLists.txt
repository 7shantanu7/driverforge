add_executable(nvk_plugin_smoke_test plugin_smoke_test.c)
target_link_libraries(nvk_plugin_smoke_test PRIVATE gpu_driver_stack::plugin_abi ${CMAKE_DL_LIBS})
gpu_driver_stack_enable_warnings(nvk_plugin_smoke_test)

# Deliberately does NOT link nvk_driver: it dlopen()s the built artifact by
# its SONAME symlink, so we need an explicit build dependency to guarantee
# the .so exists before this test runs.
target_compile_definitions(nvk_plugin_smoke_test PRIVATE
    NVK_DRIVER_PATH="$<TARGET_FILE_DIR:nvk_driver>/${NVK_DRIVER_SONAME}"
)
add_dependencies(nvk_plugin_smoke_test nvk_driver)
add_test(NAME NvkDriverPluginSmokeTest COMMAND nvk_plugin_smoke_test)
set_tests_properties(NvkDriverPluginSmokeTest PROPERTIES LABELS "plugin;smoke")

# ABI surface check: the plugin must export exactly the allow-listed symbols.
find_program(GPU_STACK_NM NAMES ${CMAKE_NM} nm)
if(GPU_STACK_NM)
    add_test(NAME NvkDriverExportedSymbols
        COMMAND ${CMAKE_SOURCE_DIR}/scripts/check_exported_symbols.sh
                $<TARGET_FILE:nvk_driver>
                ${CMAKE_CURRENT_SOURCE_DIR}/../exported_symbols.txt
    )
    set_tests_properties(NvkDriverExportedSymbols PROPERTIES
        LABELS "abi"
        ENVIRONMENT "NM=${GPU_STACK_NM}"
    )
endif()
