# A separate, downstream project. It knows nothing about this repository's
# source tree: it only sees what `cmake --install` (or the -dev package)
# put under CMAKE_PREFIX_PATH. If this builds and passes, the SDK we ship is
# genuinely consumable.
cmake_minimum_required(VERSION 3.25)
project(gpu_driver_stack_consumer LANGUAGES C CXX)

find_package(gpu_driver_stack REQUIRED CONFIG)

if(DEFINED EXPECTED_VERSION AND NOT gpu_driver_stack_VERSION VERSION_EQUAL EXPECTED_VERSION)
    message(FATAL_ERROR "found gpu_driver_stack ${gpu_driver_stack_VERSION}, expected ${EXPECTED_VERSION}")
endif()
message(STATUS "Consuming gpu_driver_stack ${gpu_driver_stack_VERSION} from ${gpu_driver_stack_DIR}")

# A host application using the C++ API.
add_executable(consumer_app src/app.cpp)
target_link_libraries(consumer_app PRIVATE
    gpu_driver_stack::gpu_core
    gpu_driver_stack::software_rasterizer
)

# A third-party driver plugin written only against the installed C ABI.
add_library(third_party_plugin MODULE src/third_party_plugin.c)
target_link_libraries(third_party_plugin PRIVATE gpu_driver_stack::plugin_abi)
set_target_properties(third_party_plugin PROPERTIES C_VISIBILITY_PRESET hidden)

enable_testing()
add_test(NAME ConsumerLoadsThirdPartyPlugin
    COMMAND consumer_app $<TARGET_FILE:third_party_plugin>)
set_tests_properties(ConsumerLoadsThirdPartyPlugin PROPERTIES
    PASS_REGULAR_EXPRESSION "third_party_plugin: ok")

if(EXISTS "${gpu_driver_stack_PLUGIN_DIR}/libnvk_driver.so.${gpu_driver_stack_PLUGIN_SOVERSION}")
    add_test(NAME ConsumerLoadsInstalledNvkDriver
        COMMAND consumer_app "${gpu_driver_stack_PLUGIN_DIR}/libnvk_driver.so.${gpu_driver_stack_PLUGIN_SOVERSION}")
    set_tests_properties(ConsumerLoadsInstalledNvkDriver PROPERTIES
        PASS_REGULAR_EXPRESSION "nvk_driver: ok")
endif()

if(TARGET gpu_driver_stack::shader_compiler)
    add_test(NAME ConsumerRunsInstalledShaderCompiler
        COMMAND gpu_driver_stack::shader_compiler --version)
endif()
