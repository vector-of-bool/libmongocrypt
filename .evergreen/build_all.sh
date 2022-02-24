#!/bin/bash
# Compiles libmongocrypt dependencies and targets.
#
# Assumes the current working directory contains libmongocrypt.
# So script should be called like: ./libmongocrypt/.evergreen/build_all.sh
# The current working directory should be empty aside from 'libmongocrypt'
# since this script creates new directories/files (e.g. mongo-c-driver, venv).
#
# Set extra cflags for libmongocrypt variables by setting LIBMONGOCRYPT_EXTRA_CFLAGS.
#

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

log "Begin compile process"

_build_flags=()

_build_flags+=(${ADDITIONAL_CMAKE_FLAGS:-} ${LIBMONGOCRYPT_EXTRA_CMAKE_FLAGS:-})

if [ "${PPA_BUILD_ONLY:-}" ]; then
    # Clean-up from previous build iteration
    rm -rf "${INSTALL_ROOT}" "${BUILD_ROOT}"
    _build_flags+=("--set=ENABLE_BUILD_FOR_PPA=ON")
fi

bash "${CI_DIR}/build_install_bson.sh"

# Build and install libmongocrypt.
if [ "${OS:-}" = "Windows_NT" ]; then
    # W4996 - POSIX name for this item is deprecated
    # TODO: add support for clang-cl which is detected as MSVC
    LIBMONGOCRYPT_CFLAGS="/WX"
else
    # GNU, Clang, AppleClang
    LIBMONGOCRYPT_CFLAGS="-Werror"
fi

if test "${CONFIGURE_ONLY:-}"; then
    _build_flags+=("--no-build")
fi

_build_flags+=("--config=${DEFAULT_CMAKE_BUILD_TYPE}")

cmake_build_py \
    -D CMAKE_PREFIX_PATH="${BSON_INSTALL_DIR}" \
    --install-prefix=${LIBMONGOCRYPT_INSTALL_ROOT} \
    --source-dir="${LIBMONGOCRYPT_DIR}" \
    --build-dir="${LIBMONGOCRYPT_BUILD_ROOT}/default" \
    "${_build_flags[@]}" \
    --install \
    --wipe

if [ "${CONFIGURE_ONLY:-}" ]; then
    echo "Only running configure";
    exit 0;
fi

# CDRIVER-3187, ensure the final distributed tarball contains the libbson static
# library to support consumers that static link to libmongocrypt
find ${BSON_INSTALL_DIR} \( -name libbson-static-1.0.a -o -name bson-1.0.lib -o -name bson-static-1.0.lib \) -execdir cp {} $(dirname $(find ${LIBMONGOCRYPT_INSTALL_ROOT} -name libmongocrypt-static.a -o -name mongocrypt-static.lib)) \;

# MONGOCRYPT-372, ensure macOS universal builds contain both x86_64 and arm64 architectures.
if [ "${MACOS_UNIVERSAL:-}" = "ON" ]; then
    echo "Checking if libmongocrypt.dylib contains both x86_64 and arm64 architectures..."
    ARCHS=$(lipo -archs $LIBMONGOCRYPT_INSTALL_ROOT/lib/libmongocrypt.dylib)
    if [[ "$ARCHS" == *"x86_64"* && "$ARCHS" == *"arm64"* ]]; then
        echo "Checking if libmongocrypt.dylib contains both x86_64 and arm64 architectures... OK"
    else
        echo "Checking if libmongocrypt.dylib contains both x86_64 and arm64 architectures... ERROR. Got: $ARCHS"
        exit
    fi
fi

if [ "${PPA_BUILD_ONLY:-}" ]; then
    echo "Only building/installing for PPA";
    exit 0;
fi

# Build and install libmongocrypt with no native crypto.
cmake_build_py \
    -D CMAKE_PREFIX_PATH="${BSON_INSTALL_DIR}" \
    -D DISABLE_NATIVE_CRYPTO=YES \
    --install-prefix="${LIBMONGOCRYPT_INSTALL_ROOT}/nocrypto" \
    --source-dir="${LIBMONGOCRYPT_DIR}" \
    --build-dir="${LIBMONGOCRYPT_BUILD_ROOT}/nocrypto" \
    "${_build_flags[@]}" \
    --install \
    --wipe

# Build and install libmongocrypt without statically linking libbson
cmake_build_py \
    -D CMAKE_PREFIX_PATH="${BSON_INSTALL_DIR}" \
    -D ENABLE_SHARED_BSON=YES \
    --install-prefix=${LIBMONGOCRYPT_INSTALL_ROOT}/sharedbson \
    --source-dir="${LIBMONGOCRYPT_DIR}" \
    --build-dir="${LIBMONGOCRYPT_BUILD_ROOT}/sharedbson" \
    "${_build_flags[@]}" \
    --install \
    --wipe
