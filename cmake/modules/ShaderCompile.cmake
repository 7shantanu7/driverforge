# gpu_stack_compile_shaders(<target> OUTPUT_DIR <dir> SOURCES <files...>)
#
# Creates <target>, which runs our own just-built shader_compiler over every
# source at build time. DEPENDS on the shader_compiler target is what forces
# "build the tool" before "run the tool": CMake does not infer that ordering
# on its own for custom commands. When cross-compiling, CMake prefixes the
# tool with CMAKE_CROSSCOMPILING_EMULATOR (qemu), so this still works.
function(gpu_stack_compile_shaders target)
    cmake_parse_arguments(ARG "" "OUTPUT_DIR" "SOURCES" ${ARGN})
    if(NOT ARG_SOURCES)
        message(FATAL_ERROR "gpu_stack_compile_shaders(${target}) needs SOURCES")
    endif()

    set(_outputs "")
    foreach(_source IN LISTS ARG_SOURCES)
        get_filename_component(_abs ${_source} ABSOLUTE)
        get_filename_component(_name ${_source} NAME_WE)
        set(_output ${ARG_OUTPUT_DIR}/${_name}.spv)
        add_custom_command(
            OUTPUT ${_output}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${ARG_OUTPUT_DIR}
            COMMAND shader_compiler ${_abs} ${_output}
            DEPENDS shader_compiler ${_abs}
            COMMENT "Compiling ${_name}.glsl -> ${_name}.spv (mock)"
            VERBATIM
        )
        list(APPEND _outputs ${_output})
    endforeach()

    add_custom_target(${target} ALL DEPENDS ${_outputs})
    set_target_properties(${target} PROPERTIES GPU_STACK_SHADER_OUTPUTS "${_outputs}")
endfunction()
