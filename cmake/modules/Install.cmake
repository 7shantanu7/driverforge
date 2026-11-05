# Install rules, split into three components that map 1:1 onto packages:
#
#   Runtime      what end users need: the plugin, driverforge-info, shaders
#   Development  headers, static libs, CMake package config (the SDK)
#   Tools        shader_compiler
#
# Everything is relative to CMAKE_INSTALL_PREFIX, so the same rules drive
# `cmake --install`, the .deb, the .rpm and the relocatable tarball.
include(CMakePackageConfigHelpers)

set(DRIVERFORGE_CMAKE_INSTALL_DIR ${CMAKE_INSTALL_LIBDIR}/cmake/driverforge)

set(_exported_targets gpu_core plugin_abi)
if(TARGET software_rasterizer)
    list(APPEND _exported_targets software_rasterizer)
endif()

install(TARGETS ${_exported_targets}
    EXPORT driverforgeTargets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Runtime
        NAMELINK_COMPONENT Development
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(DIRECTORY ${PROJECT_SOURCE_DIR}/core/include/gpu_core
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    COMPONENT Development
    FILES_MATCHING PATTERN "*.h"
)
install(DIRECTORY ${PROJECT_BINARY_DIR}/core/generated/include/gpu_core
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    COMPONENT Development
)
if(TARGET software_rasterizer)
    install(DIRECTORY ${PROJECT_SOURCE_DIR}/drivers/software/include/software_rasterizer
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        COMPONENT Development
    )
endif()

if(TARGET nvk_driver)
    install(TARGETS nvk_driver
        LIBRARY DESTINATION ${DRIVERFORGE_PLUGIN_INSTALL_DIR} COMPONENT Runtime
    )
    # The SONAME symlink the host actually loads.
    install(FILES $<TARGET_FILE_DIR:nvk_driver>/${NVK_DRIVER_SONAME}
        DESTINATION ${DRIVERFORGE_PLUGIN_INSTALL_DIR}
        COMPONENT Runtime
    )
endif()

install(TARGETS driverforge_info
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime
)

install(FILES $<TARGET_PROPERTY:compile_sample_shaders,DRIVERFORGE_SHADER_OUTPUTS>
    DESTINATION ${CMAKE_INSTALL_DATADIR}/driverforge/shaders
    COMPONENT Runtime
)

# Tools get their own export set: the -dev package must not reference a
# binary that only the -tools package installs.
install(TARGETS shader_compiler
    EXPORT driverforgeToolsTargets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Tools
)
install(EXPORT driverforgeToolsTargets
    NAMESPACE driverforge::
    DESTINATION ${DRIVERFORGE_CMAKE_INSTALL_DIR}
    COMPONENT Tools
)

install(EXPORT driverforgeTargets
    NAMESPACE driverforge::
    DESTINATION ${DRIVERFORGE_CMAKE_INSTALL_DIR}
    COMPONENT Development
)

configure_package_config_file(
    ${PROJECT_SOURCE_DIR}/cmake/driverforgeConfig.cmake.in
    ${PROJECT_BINARY_DIR}/driverforgeConfig.cmake
    INSTALL_DESTINATION ${DRIVERFORGE_CMAKE_INSTALL_DIR}
    PATH_VARS DRIVERFORGE_PLUGIN_INSTALL_DIR
)
# SameMajorVersion: 1.x consumers accept any 1.y, refuse 2.0. That is the
# promise semantic versioning makes, encoded where find_package checks it.
write_basic_package_version_file(
    ${PROJECT_BINARY_DIR}/driverforgeConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)
install(FILES
    ${PROJECT_BINARY_DIR}/driverforgeConfig.cmake
    ${PROJECT_BINARY_DIR}/driverforgeConfigVersion.cmake
    DESTINATION ${DRIVERFORGE_CMAKE_INSTALL_DIR}
    COMPONENT Development
)

# Debian policy wants /usr/share/doc/<package>/copyright in every package.
foreach(_component IN ITEMS Runtime Development Tools)
    string(TOUPPER ${_component} _upper)
    install(FILES ${PROJECT_SOURCE_DIR}/LICENSE
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/doc/${DRIVERFORGE_PACKAGE_NAME_${_upper}}
        RENAME copyright
        COMPONENT ${_component}
    )
endforeach()
# Debian policy also wants a compressed changelog per package and a man page
# per program. Both are generated deterministically (gzip -n drops the
# timestamp and file name, the date comes from the commit), so packages stay
# reproducible.
find_program(DRIVERFORGE_GZIP gzip)
if(DRIVERFORGE_GZIP)
    set(_pkg_dir ${PROJECT_BINARY_DIR}/packaging)
    file(MAKE_DIRECTORY ${_pkg_dir})
    if(DEFINED ENV{SOURCE_DATE_EPOCH})
        set(_epoch $ENV{SOURCE_DATE_EPOCH})
    else()
        execute_process(COMMAND git log -1 --format=%ct
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
            OUTPUT_VARIABLE _epoch OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    endif()
    if(NOT _epoch)
        set(_epoch 0)
    endif()
    execute_process(COMMAND date -u -R -d @${_epoch}
        OUTPUT_VARIABLE _changelog_date OUTPUT_STRIP_TRAILING_WHITESPACE)

    function(_driverforge_gzip input output)
        execute_process(COMMAND ${DRIVERFORGE_GZIP} -9 -n -c ${input}
            OUTPUT_FILE ${output} RESULT_VARIABLE _rc)
        if(NOT _rc EQUAL 0)
            message(FATAL_ERROR "gzip failed for ${input}")
        endif()
    endfunction()

    foreach(_component IN ITEMS Runtime Development Tools)
        string(TOUPPER ${_component} _upper)
        set(_pkg ${DRIVERFORGE_PACKAGE_NAME_${_upper}})
        file(READ ${PROJECT_SOURCE_DIR}/packaging/debian-changelog.in _text)
        string(REPLACE "@PKG@" "${_pkg}" _text "${_text}")
        string(REPLACE "@VERSION@" "${PROJECT_VERSION}" _text "${_text}")
        string(REPLACE "@MAINTAINER@" "${DRIVERFORGE_MAINTAINER}" _text "${_text}")
        string(REPLACE "@DATE@" "${_changelog_date}" _text "${_text}")
        file(WRITE ${_pkg_dir}/${_pkg}.changelog "${_text}")
        _driverforge_gzip(${_pkg_dir}/${_pkg}.changelog ${_pkg_dir}/${_pkg}.changelog.Debian.gz)
        install(FILES ${_pkg_dir}/${_pkg}.changelog.Debian.gz
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/doc/${_pkg}
            RENAME changelog.Debian.gz
            COMPONENT ${_component})
    endforeach()

    foreach(_page IN ITEMS driverforge-info:Runtime shader_compiler:Tools)
        string(REPLACE ":" ";" _parts ${_page})
        list(GET _parts 0 _name)
        list(GET _parts 1 _component)
        _driverforge_gzip(${PROJECT_SOURCE_DIR}/packaging/man/${_name}.1 ${_pkg_dir}/${_name}.1.gz)
        install(FILES ${_pkg_dir}/${_name}.1.gz
            DESTINATION ${CMAKE_INSTALL_MANDIR}/man1
            COMPONENT ${_component})
    endforeach()
endif()

install(FILES ${PROJECT_SOURCE_DIR}/README.md
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/doc/${DRIVERFORGE_PACKAGE_NAME_RUNTIME}
    COMPONENT Runtime
)
