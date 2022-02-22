#!/bin/bash

set -o xtrace
set -o errexit

evergreen_root="$(pwd)"
pushd $evergreen_root

. ${evergreen_root}/libmongocrypt/.evergreen/setup-env.sh

# Build and install libbson.
pushd mongo-c-driver

. "${evergreen_root}/libmongocrypt/.evergreen/get-cmake.sh"
if [ "${OS}" = "Windows_NT" ]; then
    ADDITIONAL_CMAKE_FLAGS="-T host=x64 -A x64"
fi

if [ "$MACOS_UNIVERSAL" = "ON" ]; then
    ADDITIONAL_CMAKE_FLAGS="$ADDITIONAL_CMAKE_FLAGS -DCMAKE_OSX_ARCHITECTURES='arm64;x86_64'"
fi

$CMAKE --version

# Remove remnants of any earlier build
[ -d cmake-build ] && rm -rf cmake-build

mkdir cmake-build
pushd cmake-build
$CMAKE -DENABLE_MONGOC=OFF ${ADDITIONAL_CMAKE_FLAGS} ${BSON_EXTRA_CMAKE_FLAGS} -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_EXTRA_ALIGNMENT=OFF -DCMAKE_C_FLAGS="${BSON_EXTRA_CFLAGS}" -DCMAKE_INSTALL_PREFIX="${BSON_INSTALL_PREFIX}" ../
echo "Installing libbson"
$CMAKE --build . --parallel --target install --config RelWithDebInfo

popd
popd
popd

