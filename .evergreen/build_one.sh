#!/bin/bash

# Compiles one variant of libmongocrypt, setting all the command arguments for the host platform.
# All arguments to this script are forwarded to turnkey-build-install.bash
# This script inserts platform-specific configuration options regardless of the.

. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

set +u

build_dir="$(abspath "$LIBMONGOCRYPT_DIR/cmake-build")"
build_argv=(--config "RelWithDebInfo" --build-dir "$build_dir" "$@")

# Use C driver helper script to find cmake binary, stored in $CMAKE.
if [ "$OS_NAME" == "windows" ]; then
    : "${CMAKE:="$(native_path /cygdrive/c/cmake/bin/cmake)"}"
    build_argv+=(--msvs -D CMAKE_C_COMPILER=cl -D CMAKE_CXX_COMPILER=cl)
    if [ "${WINDOWS_32BIT:-}" = "ON" ]; then
        build_argv+=(--msvs-target-arch x86)
    fi
    build_argv+=(--msvs-version "${MSVS_VERSION:-*}.*")
else
    # Amazon Linux 2 (arm64) has a very old system CMake we want to ignore
    IGNORE_SYSTEM_CMAKE=1 . $CI_DIR/find-cmake.sh
    # Check if on macOS with arm64. Use system cmake. See BUILD-14565.
    MARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
    if [ "macos" = "$OS_NAME" -a "arm64" = "$MARCH" ]; then
        CMAKE=cmake
    fi
fi

export CMAKE

if [ "${MACOS_UNIVERSAL-}" = "ON" ]; then
    # Enable macOS universal binaries
    build_argv+=(-D "CMAKE_OSX_ARCHITECTURES=arm64;x86_64")
fi

if test "${MONGOCRYPT_SANITIZE:-}" != ""; then
    # Tell mongocrypt to use ASan
    build_argv+=(-D MONGOCRYPT_SANITIZE="$MONGOCRYPT_SANITIZE")
fi

for suffix in "dll" "dylib" "so"; do
    if test -f "mongo_crypt_v1.$suffix"; then
        # Give the build the path to a crypt_shared library
        build_argv+=(-D MONGOCRYPT_TESTING_CRYPT_SHARED_FILE="$PWD/mongo_crypt_v1.$suffix")
    fi
done

# Enable warnings as errors
build_argv+=(
    -D ENABLE_MORE_WARNINGS_AS_ERRORS=ON
    -D CMAKE_EXPORT_COMPILE_COMMANDS=TRUE
)

bash "$CI_DIR/turnkey-build-install.bash" "${build_argv[@]}"
