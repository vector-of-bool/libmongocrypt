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

build_dir="$(abspath "$LIBMONGOCRYPT_DIR/cmake-build")"

build_argv=(-D _unused=0)

if [ "$PPA_BUILD_ONLY" ]; then
    # Clean-up from previous build iteration
    rm -rf "$build_dir" "${MONGOCRYPT_INSTALL_PREFIX}"
    build_argv+=(-D ENABLE_BUILD_FOR_PPA=ON)
fi

bash "$CI_DIR/build_one.sh" "${build_argv[@]}" \
    --install-dir "$MONGOCRYPT_INSTALL_PREFIX"

if [ "$PPA_BUILD_ONLY" ]; then
    echo "Only building/installing for PPA";
    exit 0;
fi

# Build and install libmongocrypt without statically linking libbson
bash "$CI_DIR/build_one.sh" "${build_argv[@]}" \
    --install-dir "$MONGOCRYPT_INSTALL_PREFIX/sharedbson" \
    -D USE_SHARED_LIBBSON=ON

# Build and install libmongocrypt with no native crypto.
bash "$CI_DIR/build_one.sh" "${build_argv[@]}" \
    --install-dir "$MONGOCRYPT_INSTALL_PREFIX/nocrypto" \
    -D USE_SHARED_LIBBSON=OFF \
    -D DISABLE_NATIVE_CRYPTO=ON
