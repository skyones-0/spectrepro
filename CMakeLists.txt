# CMake wrapper for libspectrepro-vt
#
# This file delegates to `zig build -Demit-lib-vt` to produce the shared library,
# headers, and pkg-config file. It exists so that CMake-based projects can
# consume libspectrepro-vt without interacting with the Zig build system
# directly. However, downstream users do still require `zig` on the PATH.
# Please consult the SpectrePro docs for the required Zig version:
#
# https://spectrepro.org/docs/install/build
#
# Building within the SpectrePro repo
# ---------------------------------
#
#   cmake -B build
#   cmake --build build
#   cmake --install build --prefix /usr/local
#
# Pass extra flags to the Zig build with SPECTREPRO_ZIG_BUILD_FLAGS:
#
#   cmake -B build -DSPECTREPRO_ZIG_BUILD_FLAGS="-Demit-macos-app=false"
#
# Integrating into a downstream CMake project
# ---------------------------------------------
#
# Option 1 — FetchContent (recommended, no manual install step):
#
#   include(FetchContent)
#   FetchContent_Declare(spectrepro
#       GIT_REPOSITORY https://github.com/spectrepro-org/spectrepro.git
#       GIT_TAG main
#   )
#   FetchContent_MakeAvailable(spectrepro)
#
#   target_link_libraries(myapp PRIVATE spectrepro-vt)        # shared
#   target_link_libraries(myapp PRIVATE spectrepro-vt-static) # static
#
# To use a local checkout instead of fetching:
#
#   cmake -B build -DFETCHCONTENT_SOURCE_DIR_SPECTREPRO=/path/to/spectrepro
#
# Option 2 — find_package (after installing to a prefix):
#
#   find_package(spectrepro-vt REQUIRED)
#   target_link_libraries(myapp PRIVATE spectrepro-vt::spectrepro-vt)        # shared
#   target_link_libraries(myapp PRIVATE spectrepro-vt::spectrepro-vt-static) # static
#
# Cross-compilation
# -------------------
#
# For building libspectrepro-vt for a non-native Zig target (e.g. cross-
# compiling), use the spectrepro_vt_add_target() function after FetchContent:
#
#   FetchContent_MakeAvailable(spectrepro)
#   spectrepro_vt_add_target(NAME linux-amd64 ZIG_TARGET x86_64-linux-gnu)
#
#   target_link_libraries(myapp PRIVATE spectrepro-vt-static-linux-amd64) # static
#   target_link_libraries(myapp PRIVATE spectrepro-vt-linux-amd64)        # shared
#
# This handles zig discovery, build-type-to-optimize mapping, and output
# path conventions internally. Extra flags can be forwarded with ZIG_FLAGS:
#
#   spectrepro_vt_add_target(NAME linux-amd64 ZIG_TARGET x86_64-linux-gnu
#                         ZIG_FLAGS -Dsimd=false)
#
# See dist/cmake/README.md for more details, example/c-vt-cmake/ for a
# complete working example, and example/c-vt-cmake-cross/ for a cross-
# compilation example.

cmake_minimum_required(VERSION 3.19)
project(spectrepro-vt VERSION 0.1.0 LANGUAGES C)

# --- Options ----------------------------------------------------------------

set(SPECTREPRO_ZIG_BUILD_FLAGS "" CACHE STRING "Additional flags to pass to zig build")

# Map CMake build types to Zig optimization levels. The result is stored in
# _SPECTREPRO_ZIG_OPT_FLAG so both the native build and spectrepro_vt_add_target()
# can reuse it without duplicating the mapping logic.
set(_SPECTREPRO_ZIG_OPT_FLAG "")
if(CMAKE_BUILD_TYPE)
    string(TOUPPER "${CMAKE_BUILD_TYPE}" _bt)
    if(_bt STREQUAL "RELEASE" OR _bt STREQUAL "MINSIZEREL" OR _bt STREQUAL "RELWITHDEBINFO")
        set(_SPECTREPRO_ZIG_OPT_FLAG "-Doptimize=ReleaseFast")
    endif()
    unset(_bt)
endif()

if(_SPECTREPRO_ZIG_OPT_FLAG)
    list(APPEND SPECTREPRO_ZIG_BUILD_FLAGS "${_SPECTREPRO_ZIG_OPT_FLAG}")
endif()

# --- Find Zig ----------------------------------------------------------------

find_program(ZIG_EXECUTABLE zig REQUIRED)
message(STATUS "Found zig: ${ZIG_EXECUTABLE}")

# --- Build via zig build -----------------------------------------------------

# The zig build installs into zig-out/ relative to the source tree.
set(ZIG_OUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/zig-out")

# Shared library names (zig build produces both shared and static).
if(APPLE)
    set(SPECTREPRO_VT_LIBNAME "${CMAKE_SHARED_LIBRARY_PREFIX}spectrepro-vt${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(SPECTREPRO_VT_SONAME "${CMAKE_SHARED_LIBRARY_PREFIX}spectrepro-vt.0${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(SPECTREPRO_VT_REALNAME "${CMAKE_SHARED_LIBRARY_PREFIX}spectrepro-vt.0.1.0${CMAKE_SHARED_LIBRARY_SUFFIX}")
elseif(WIN32)
    set(SPECTREPRO_VT_LIBNAME "spectrepro-vt.dll")
    set(SPECTREPRO_VT_REALNAME "spectrepro-vt.dll")
    set(SPECTREPRO_VT_IMPLIB "spectrepro-vt.lib")
else()
    set(SPECTREPRO_VT_LIBNAME "${CMAKE_SHARED_LIBRARY_PREFIX}spectrepro-vt${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(SPECTREPRO_VT_SONAME "${CMAKE_SHARED_LIBRARY_PREFIX}spectrepro-vt${CMAKE_SHARED_LIBRARY_SUFFIX}.0")
    set(SPECTREPRO_VT_REALNAME "${CMAKE_SHARED_LIBRARY_PREFIX}spectrepro-vt${CMAKE_SHARED_LIBRARY_SUFFIX}.0.1.0")
endif()

if(WIN32)
    set(SPECTREPRO_VT_SHARED_LIBRARY "${ZIG_OUT_DIR}/bin/${SPECTREPRO_VT_REALNAME}")
else()
    set(SPECTREPRO_VT_SHARED_LIBRARY "${ZIG_OUT_DIR}/lib/${SPECTREPRO_VT_REALNAME}")
endif()

# Static library name.
# On Windows, the static lib is named "spectrepro-vt-static.lib" to avoid
# colliding with the DLL import library "spectrepro-vt.lib".
if(WIN32)
    set(SPECTREPRO_VT_STATIC_REALNAME "spectrepro-vt-static.lib")
else()
    set(SPECTREPRO_VT_STATIC_REALNAME "libspectrepro-vt.a")
endif()
set(SPECTREPRO_VT_STATIC_LIBRARY "${ZIG_OUT_DIR}/lib/${SPECTREPRO_VT_STATIC_REALNAME}")

# Ensure the output directories exist so CMake doesn't reject the
# INTERFACE_INCLUDE_DIRECTORIES before the zig build has run.
file(MAKE_DIRECTORY "${ZIG_OUT_DIR}/include")

# Custom command: run zig build -Demit-lib-vt (produces both shared and static)
add_custom_command(
    OUTPUT "${SPECTREPRO_VT_SHARED_LIBRARY}" "${SPECTREPRO_VT_STATIC_LIBRARY}" "${ZIG_OUT_DIR}/lib/${SPECTREPRO_VT_IMPLIB}"
    COMMAND "${ZIG_EXECUTABLE}" build -Demit-lib-vt ${SPECTREPRO_ZIG_BUILD_FLAGS}
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "Building libspectrepro-vt via zig build..."
    USES_TERMINAL
)

add_custom_target(zig_build_lib_vt ALL
    DEPENDS "${SPECTREPRO_VT_SHARED_LIBRARY}" "${SPECTREPRO_VT_STATIC_LIBRARY}"
)

# Tell CMake's clean target to also remove Zig's output directory.
set_property(DIRECTORY APPEND PROPERTY
    ADDITIONAL_CLEAN_FILES "${ZIG_OUT_DIR}"
)

# --- IMPORTED library targets ------------------------------------------------

# Shared
add_library(spectrepro-vt SHARED IMPORTED GLOBAL)
set_target_properties(spectrepro-vt PROPERTIES
    IMPORTED_LOCATION "${SPECTREPRO_VT_SHARED_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${ZIG_OUT_DIR}/include"
)
if(APPLE)
    set_target_properties(spectrepro-vt PROPERTIES
        IMPORTED_SONAME "@rpath/${SPECTREPRO_VT_SONAME}"
    )
elseif(WIN32)
    set_target_properties(spectrepro-vt PROPERTIES
        IMPORTED_IMPLIB "${ZIG_OUT_DIR}/lib/${SPECTREPRO_VT_IMPLIB}"
    )
else()
    set_target_properties(spectrepro-vt PROPERTIES
        IMPORTED_SONAME "${SPECTREPRO_VT_SONAME}"
    )
endif()
add_dependencies(spectrepro-vt zig_build_lib_vt)

# Static
#
# On Linux and macOS, the static library is a fat archive that bundles
# the vendored SIMD dependencies (highway, simdutf). Consumers
# only need to link libc.
#
# On Windows, the SIMD dependencies are not bundled and must be linked
# separately.
#
# Building with -Dsimd=false removes all runtime dependencies.
add_library(spectrepro-vt-static STATIC IMPORTED GLOBAL)
set_target_properties(spectrepro-vt-static PROPERTIES
    IMPORTED_LOCATION "${SPECTREPRO_VT_STATIC_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${ZIG_OUT_DIR}/include"
    INTERFACE_COMPILE_DEFINITIONS "SPECTREPRO_STATIC"
)
if(WIN32)
    # On Windows, the Zig standard library uses NT API functions
    # (NtClose, NtCreateSection, etc.) and kernel32 functions that
    # consumers must link when using the static library.
    set_target_properties(spectrepro-vt-static PROPERTIES
        INTERFACE_LINK_LIBRARIES "ntdll;kernel32"
    )
endif()
add_dependencies(spectrepro-vt-static zig_build_lib_vt)

# --- Install ------------------------------------------------------------------

include(GNUInstallDirs)

# Install shared library
if(WIN32)
    # On Windows, install the DLL and PDB to bin/ and the import library to lib/
    install(FILES "${SPECTREPRO_VT_SHARED_LIBRARY}" "${ZIG_OUT_DIR}/bin/spectrepro-vt.pdb" TYPE BIN)
    install(FILES "${ZIG_OUT_DIR}/lib/${SPECTREPRO_VT_IMPLIB}" TYPE LIB)
else()
    install(FILES "${SPECTREPRO_VT_SHARED_LIBRARY}" TYPE LIB)
    # Install symlinks
    install(CODE "
        execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
            \"${SPECTREPRO_VT_REALNAME}\"
            \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/${SPECTREPRO_VT_SONAME}\")
        execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
            \"${SPECTREPRO_VT_SONAME}\"
            \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/${SPECTREPRO_VT_LIBNAME}\")
    ")
endif()

# Install static library
install(FILES "${SPECTREPRO_VT_STATIC_LIBRARY}" TYPE LIB)

# Install headers
install(DIRECTORY "${ZIG_OUT_DIR}/include/spectrepro" DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

# --- CMake package config for find_package() ----------------------------------

include(CMakePackageConfigHelpers)

# Generate the config file
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/dist/cmake/spectrepro-vt-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/spectrepro-vt-config.cmake"
    INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/spectrepro-vt"
)

# Generate the version file
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/spectrepro-vt-config-version.cmake"
    VERSION "${PROJECT_VERSION}"
    COMPATIBILITY SameMajorVersion
)

# Install the config files
install(
    FILES
        "${CMAKE_CURRENT_BINARY_DIR}/spectrepro-vt-config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/spectrepro-vt-config-version.cmake"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/spectrepro-vt"
)

# --- Cross-compilation helper ------------------------------------------------
#
# For downstream projects that need to build libspectrepro-vt for a specific
# Zig target triple. For native builds, use the IMPORTED targets above
# (spectrepro-vt, spectrepro-vt-static) directly.
#
# Usage (in a downstream CMakeLists.txt after FetchContent_MakeAvailable):
#
#   spectrepro_vt_add_target(NAME linux-amd64 ZIG_TARGET x86_64-linux-gnu)
#
# Creates:
#   spectrepro-vt-static-linux-amd64   (IMPORTED STATIC library)
#   spectrepro-vt-linux-amd64          (IMPORTED SHARED library)
#
# Optional ZIG_FLAGS to pass additional flags to zig build:
#
#   spectrepro_vt_add_target(NAME linux-amd64 ZIG_TARGET x86_64-linux-gnu
#                         ZIG_FLAGS -Dsimd=false)

function(spectrepro_vt_add_target)
    cmake_parse_arguments(PARSE_ARGV 0 _GVT "" "NAME;ZIG_TARGET" "ZIG_FLAGS")

    if(NOT _GVT_NAME)
        message(FATAL_ERROR "spectrepro_vt_add_target: NAME is required")
    endif()
    if(NOT _GVT_ZIG_TARGET)
        message(FATAL_ERROR "spectrepro_vt_add_target: ZIG_TARGET is required")
    endif()

    set(_src_dir "${CMAKE_CURRENT_FUNCTION_LIST_DIR}")
    set(_prefix "${CMAKE_CURRENT_BINARY_DIR}/spectrepro-${_GVT_NAME}")

    # Build flags
    set(_flags
        -Demit-lib-vt
        -Dtarget=${_GVT_ZIG_TARGET}
        --prefix "${_prefix}"
    )

    # Default to ReleaseFast when no build type is set. Debug builds enable
    # UBSan in zig, and the sanitizer runtime is not available for all
    # cross-compilation targets.
    if(_SPECTREPRO_ZIG_OPT_FLAG)
        list(APPEND _flags "${_SPECTREPRO_ZIG_OPT_FLAG}")
    else()
        list(APPEND _flags "-Doptimize=ReleaseFast")
    endif()

    if(_GVT_ZIG_FLAGS)
        list(APPEND _flags ${_GVT_ZIG_FLAGS})
    endif()

    # Output paths
    set(_include_dir "${_prefix}/include")

    if(_GVT_ZIG_TARGET MATCHES "windows")
        set(_static_lib "${_prefix}/lib/spectrepro-vt-static.lib")
        set(_shared_lib "${_prefix}/bin/spectrepro-vt.dll")
        set(_implib "${_prefix}/lib/spectrepro-vt.lib")
    elseif(_GVT_ZIG_TARGET MATCHES "darwin|macos")
        set(_static_lib "${_prefix}/lib/libspectrepro-vt.a")
        set(_shared_lib "${_prefix}/lib/libspectrepro-vt.0.1.0.dylib")
    else()
        set(_static_lib "${_prefix}/lib/libspectrepro-vt.a")
        set(_shared_lib "${_prefix}/lib/libspectrepro-vt.so.0.1.0")
    endif()

    file(MAKE_DIRECTORY "${_include_dir}")

    # Custom command: invoke zig build
    add_custom_command(
        OUTPUT "${_static_lib}" "${_shared_lib}"
        COMMAND "${ZIG_EXECUTABLE}" build ${_flags}
        WORKING_DIRECTORY "${_src_dir}"
        COMMENT "Building libspectrepro-vt for ${_GVT_ZIG_TARGET}..."
        USES_TERMINAL
    )

    set(_build_target "zig_build_lib_vt_${_GVT_NAME}")
    add_custom_target(${_build_target} ALL
        DEPENDS "${_static_lib}" "${_shared_lib}"
    )

    # Static target
    set(_static_target "spectrepro-vt-static-${_GVT_NAME}")
    add_library(${_static_target} STATIC IMPORTED GLOBAL)
    set_target_properties(${_static_target} PROPERTIES
        IMPORTED_LOCATION "${_static_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}"
        INTERFACE_COMPILE_DEFINITIONS "SPECTREPRO_STATIC"
    )
    if(_GVT_ZIG_TARGET MATCHES "windows")
        set_target_properties(${_static_target} PROPERTIES
            INTERFACE_LINK_LIBRARIES "ntdll;kernel32"
        )
    endif()
    add_dependencies(${_static_target} ${_build_target})

    # Shared target
    set(_shared_target "spectrepro-vt-${_GVT_NAME}")
    add_library(${_shared_target} SHARED IMPORTED GLOBAL)
    set_target_properties(${_shared_target} PROPERTIES
        IMPORTED_LOCATION "${_shared_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}"
    )
    if(_GVT_ZIG_TARGET MATCHES "windows")
        set_target_properties(${_shared_target} PROPERTIES
            IMPORTED_IMPLIB "${_implib}"
        )
    elseif(_GVT_ZIG_TARGET MATCHES "darwin|macos")
        set_target_properties(${_shared_target} PROPERTIES
            IMPORTED_SONAME "@rpath/libspectrepro-vt.0.dylib"
        )
    else()
        set_target_properties(${_shared_target} PROPERTIES
            IMPORTED_SONAME "libspectrepro-vt.so.0"
        )
    endif()
    add_dependencies(${_shared_target} ${_build_target})
endfunction()
