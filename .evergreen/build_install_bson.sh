#!/bin/bash

. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

_build_flags=()

if [ "${OS:-}" = "Windows_NT" ]; then
    _build_flags+=(-T host=x64 -A x64)
fi

if [ "${MACOS_UNIVERSAL:-}" = "ON" ]; then
    _build_flags+=(-D CMAKE_OSX_ARCHITECTURES="amd64;x86_64")
fi

# Build and install libbson.
cmake_build_py \
    -D ENABLE_MONGOC=OFF \
    --config=RelWithDebInfo \
    -D ENABLE_EXTRA_ALIGNMENT=OFF \
    --install-prefix="${BSON_INSTALL_DIR}" \
    --source-dir="$(abspath "${MONGO_C_DRIVER_DIR}")" \
    --build-dir="$(abspath "${MONGO_C_DRIVER_BUILD_DIR}")" \
    "${_build_flags[@]}" \
    --install \
    --wipe
