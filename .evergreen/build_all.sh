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

# Clean-up from previous build iteration
rm -rf "${INSTALL_ROOT}" "${BUILD_ROOT}"

bash "${CI_DIR}/build_install_bson.sh"

_build_flags=(
    ${LIBMONGOCRYPT_EXTRA_CMAKE_FLAGS:-}
    --config=${DEFAULT_CMAKE_BUILD_TYPE}
)

if [ "${PPA_BUILD_ONLY:-}" ]; then
    _build_flags+=("-DENABLE_BUILD_FOR_PPA=ON")
fi

# Build and install libmongocrypt.
if [ "${OS_NAME}" = "windows" -a "${WINDOWS_32BIT:-}" != "ON" ]; then
    _build_flags+=(-T host=x64 -A x64)
fi

if test -n "${CONFIGURE_ONLY:-}"; then
    _build_flags+=("--no-build")
fi

for suffix in "dll" "dylib" "so"; do
    if test -f "mongo_csfle_v1.$suffix"; then
        _build_flags+=(-D MONGOCRYPT_TESTING_CSFLE_FILE="$(native_path "$PWD/mongo_csfle_v1.$suffix")")
    fi
done

_build_flags+=(
    -DCMAKE_C_FLAGS="${LIBMONGOCRYPT_EXTRA_CFLAGS:-}"
)

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
