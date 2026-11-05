include(ShaderCompile)

add_library(shader_compiler_lib STATIC
    src/compile.cpp
)
target_include_directories(shader_compiler_lib PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_features(shader_compiler_lib PUBLIC cxx_std_17)
gpu_driver_stack_enable_warnings(shader_compiler_lib)

add_executable(shader_compiler src/main.cpp)
target_link_libraries(shader_compiler PRIVATE shader_compiler_lib)
target_compile_definitions(shader_compiler PRIVATE SHADER_COMPILER_VERSION="${PROJECT_VERSION}")
gpu_driver_stack_enable_warnings(shader_compiler)

gpu_stack_compile_shaders(compile_sample_shaders
    OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}
    SOURCES
        shaders/triangle.glsl
        shaders/fullscreen.glsl
)
