#!/bin/bash

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

. "${CI_DIR}/prep_c_driver_source.sh"

_build_flags=(
    -D ENABLE_MONGOC=OFF
    -D ENABLE_EXTRA_ALIGNMENT=OFF
)

if [ "${OS:-}" = "Windows_NT" ]; then
    _build_flags+=(-T host=x64 -A x64)
fi

if [ "${MACOS_UNIVERSAL:-}" = "ON" ]; then
    _build_flags+=(-D CMAKE_OSX_ARCHITECTURES="arm64;x86_64")
fi

if ! test -d "${MONGO_C_DRIVER_DIR}"; then
    fail "No mongo-c-driver directory available (Expected [${MONGO_C_DRIVER_DIR}])"
fi

if test -n "${BSON_EXTRA_CMAKE_FLAGS:-}"; then
    _build_flags+=(${BSON_EXTRA_CMAKE_FLAGS})
fi

# Build and install libbson.
cmake_build_py \
    --config="${DEFAULT_CMAKE_BUILD_TYPE}" \
    --install-prefix="${BSON_INSTALL_DIR}" \
    --source-dir="${MONGO_C_DRIVER_DIR}" \
    --build-dir="${MONGO_C_DRIVER_BUILD_DIR}" \
    "${_build_flags[@]}" \
    --install \
    --wipe
