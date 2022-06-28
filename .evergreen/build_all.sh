#!/bin/bash
# Compiles libmongocrypt dependencies and targets.
#
# Assumes the current working directory contains libmongocrypt.
# So script should be called like: ./libmongocrypt/.evergreen/build_all.sh
# The current working directory should be empty aside from 'libmongocrypt'
# since this script creates new directories/files (e.g. mongo-c-driver, venv).
#

. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

set +u

echo "Begin compile process"

. "$CI_DIR/setup-env.sh"

# We may need some more C++ flags
_cxxflags=""

build_dir="$(abspath "$LIBMONGOCRYPT_DIR/cmake-build")"
build_argv=(--config "RelWithDebInfo" --build-dir "$build_dir")

# Use C driver helper script to find cmake binary, stored in $CMAKE.
if [ "$OS_NAME" == "windows" ]; then
    : "${CMAKE:=/cygdrive/c/cmake/bin/cmake}"
    build_argv+=(--msvs)
    if [ "$WINDOWS_32BIT" = "ON" ]; then
        build_argv+=(--msvs-target-arch x86)
    fi
else
    # Amazon Linux 2 (arm64) has a very old system CMake we want to ignore
    IGNORE_SYSTEM_CMAKE=1 . $CI_DIR/find-cmake.sh
    # Check if on macOS with arm64. Use system cmake. See BUILD-14565.
    OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
    MARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
    if [ "darwin" = "$OS_NAME" -a "arm64" = "$MARCH" ]; then
        CMAKE=cmake
    fi
fi

export CMAKE

if [ "$PPA_BUILD_ONLY" ]; then
    # Clean-up from previous build iteration
    cd $EVERGREEN_DIR
    rm -rf "$build_dir" "${MONGOCRYPT_INSTALL_PREFIX}"
    build_argv+=(-D ENABLE_BUILD_FOR_PPA=ON)
fi

if [ "$MACOS_UNIVERSAL" = "ON" ]; then
    build_argv+=(-D "CMAKE_OSX_ARCHITECTURES=arm64;x86_64")
fi

if test "${MONGOCRYPT_SANITIZE:-}" != ""; then
    build_argv+=(-D MONGOCRYPT_SANITIZE="$MONGOCRYPT_SANITIZE")
fi

cd $EVERGREEN_DIR

for suffix in "dll" "dylib" "so"; do
    if test -f "mongo_crypt_v1.$suffix"; then
        # Give the build the path to a crypt_shared library
        build_argv+=(-D MONGOCRYPT_TESTING_CRYPT_SHARED_FILE="$PWD/mongo_crypt_v1.$suffix")
    fi
done

# Enable some more warnings
build_argv+=(-D ENABLE_MORE_WARNINGS_AS_ERRORS=ON)

bash "$CI_DIR/turnkey-build-install.bash" "${build_argv[@]}" \
    --install-dir "$MONGOCRYPT_INSTALL_PREFIX"

# MONGOCRYPT-372, ensure macOS universal builds contain both x86_64 and arm64 architectures.
if [ "$MACOS_UNIVERSAL" = "ON" ]; then
    echo "Checking if libmongocrypt.dylib contains both x86_64 and arm64 architectures..."
    ARCHS=$(lipo -archs $MONGOCRYPT_INSTALL_PREFIX/lib/libmongocrypt.dylib)
    if [[ "$ARCHS" == *"x86_64"* && "$ARCHS" == *"arm64"* ]]; then
        echo "Checking if libmongocrypt.dylib contains both x86_64 and arm64 architectures... OK"
    else
        echo "Checking if libmongocrypt.dylib contains both x86_64 and arm64 architectures... ERROR. Got: $ARCHS"
        exit 1
    fi
fi

if [ "$PPA_BUILD_ONLY" ]; then
    echo "Only building/installing for PPA";
    exit 0;
fi

# Build and install libmongocrypt without statically linking libbson
bash "$CI_DIR/turnkey-build-install.bash" "${build_argv[@]}" \
    --install-dir "$MONGOCRYPT_INSTALL_PREFIX/sharedbson" \
    -D USE_SHARED_LIBBSON=ON

# Build and install libmongocrypt with no native crypto.
bash "$CI_DIR/turnkey-build-install.bash" "${build_argv[@]}" \
    --install-dir "$MONGOCRYPT_INSTALL_PREFIX/nocrypto" \
    -D USE_SHARED_LIBBSON=OFF \
    -D DISABLE_NATIVE_CRYPTO=ON
