# Confirms the add_custom_command codegen step actually ran and produced
# real artifacts, not just that shader_compiler compiled.
#   cmake -DSHADER_DIR=<dir> -DSHADERS=a,b -P check_shader_artifacts.cmake
string(REPLACE "," ";" _shaders "${SHADERS}")
foreach(_shader IN LISTS _shaders)
    set(_file ${SHADER_DIR}/${_shader}.spv)
    if(NOT EXISTS ${_file})
        message(FATAL_ERROR "missing shader artifact: ${_file}")
    endif()
    # 4d535056 = "MSPV", then format version byte 01.
    file(READ ${_file} _header LIMIT 5 HEX)
    if(NOT _header STREQUAL "4d53505601")
        message(FATAL_ERROR "${_file} has header ${_header}, expected 4d53505601 (MSPV v1)")
    endif()
endforeach()
message(STATUS "shader artifacts OK: ${_shaders}")
