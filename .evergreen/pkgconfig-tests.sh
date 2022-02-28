#!/bin/bash

set -e
set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

set -o xtrace

if ! have_command pkg-config; then
    echo "pkg-config not present on this platform; skipping test ..."
    exit 0
fi

pkgconfig_tests_root=${LIBMONGOCRYPT_DIR}/pkgconfig_tests

rm -rf "${pkgconfig_tests_root}"
mkdir -p ${pkgconfig_tests_root}/{install,libmongocrypt-cmake-build}
cd "${pkgconfig_tests_root}"

_bson_install_dir="$(native_path $pkgconfig_tests_root/install/libbson)"
_mongocrypt_install_dir="$(native_path $pkgconfig_tests_root/install/libmongocrypt)"

_cmake_flags=(
    --config="${DEFAULT_CMAKE_BUILD_TYPE}"
    # Always start fresh:
    --wipe
)

if [ "$OS_NAME" = "windows" ]; then
    _cmake_flags+=(-T host=x64 -A x64)
fi

if [ "${MACOS_UNIVERSAL:-}" = "ON" ]; then
    _cmake_flags+=(-D CMAKE_OSX_ARCHITECTURES="arm64;x86_64")
fi

# Build and install a libbson to use for the tests
$CI_DIR/prep_c_driver_source.sh
cmake_build_py \
    --source-dir "${MONGO_C_DRIVER_DIR}" \
    --build-dir "${MONGO_C_DRIVER_BUILD_DIR}" \
    "${_cmake_flags[@]}" \
    -D ENABLE_MONGOC=OFF \
    --install-prefix="${_bson_install_dir}" \
    --install

_cmake_flags+=(
    # Subsequent builds use our generated libbson:
    -DCMAKE_PREFIX_PATH="${_bson_install_dir}"
    # Install them to a subdirectory:
    --install-prefix="${_mongocrypt_install_dir}"
)

# Build libmongocrypt, static linking against libbson and configured for the PPA
cmake_build_py \
    --source-dir="${LIBMONGOCRYPT_DIR}" \
    --build-dir "$pkgconfig_tests_root/libmongocrypt-cmake-build" \
    "${_cmake_flags[@]}" \
    -D ENABLE_SHARED_BSON=OFF \
    -D ENABLE_BUILD_FOR_PPA=ON \
    --install

find ${_bson_install_dir} -name libbson-static-1.0.a \
    -execdir cp {} $(dirname $(find ${_mongocrypt_install_dir} -name libmongocrypt-static.a )) \;

# To validate the pkg-config scripts, we don't want the libbson script to be visible
export PKG_CONFIG_PATH="$(native_path $(/usr/bin/dirname $(/usr/bin/find $_mongocrypt_install_dir -name libmongocrypt.pc)))"

echo "Validating pkg-config scripts"
pkg-config --debug --print-errors --exists libmongocrypt-static
pkg-config --debug --print-errors --exists libmongocrypt

export PKG_CONFIG_PATH="$(native_path $(/usr/bin/dirname $(/usr/bin/find $_bson_install_dir -name libbson-1.0.pc))):$(native_path $(/usr/bin/dirname $(/usr/bin/find $_mongocrypt_install_dir -name libmongocrypt.pc)))"

# Build example-state-machine, static linking against libmongocrypt
cd $LIBMONGOCRYPT_DIR
gcc $(pkg-config --cflags libmongocrypt-static libbson-static-1.0) -o example-state-machine test/example-state-machine.c $(pkg-config --libs libmongocrypt-static)
./example-state-machine
# Build example-no-bson, static linking against libmongocrypt
gcc $(pkg-config --cflags libmongocrypt-static) -o example-no-bson test/example-no-bson.c $(pkg-config --libs libmongocrypt-static)
./example-no-bson

rm -f example-state-machine example-no-bson

# Build example-state-machine, dynamic linking against libmongocrypt
gcc $(pkg-config --cflags libmongocrypt libbson-static-1.0) -o example-state-machine test/example-state-machine.c $(pkg-config --libs libmongocrypt)
# Build example-no-bson, dynamic linking against libmongocrypt
gcc $(pkg-config --cflags libmongocrypt) -o example-no-bson test/example-no-bson.c $(pkg-config --libs libmongocrypt)
export LD_LIBRARY_PATH="$(native_path $_mongocrypt_install_dir/lib):$(native_path $_mongocrypt_install_dir/lib64)"
./example-state-machine
./example-no-bson
unset LD_LIBRARY_PATH

rm -f example-state-machine example-no-bson

# Build libmongocrypt, dynamic linking against libbson.
cmake_build_py \
    --source-dir="${LIBMONGOCRYPT_DIR}" \
    --build-dir="$pkgconfig_tests_root/libmongocrypt-cmake-build" \
    "${_cmake_flags[@]}" \
    -D ENABLE_SHARED_BSON=ON \
    --install

# Build example-state-machine, static linking against libmongocrypt
cd $LIBMONGOCRYPT_DIR
gcc $(pkg-config --cflags libmongocrypt-static libbson-static-1.0) -o example-state-machine test/example-state-machine.c $(pkg-config --libs libmongocrypt-static)
# Build example-no-bson, static linking against libmongocrypt
gcc $(pkg-config --cflags libmongocrypt-static) -o example-no-bson test/example-no-bson.c $(pkg-config --libs libmongocrypt-static)
export LD_LIBRARY_PATH="$(native_path $_bson_install_dir/lib):$(native_path $_bson_install_dir/lib64)"
./example-state-machine
./example-no-bson
unset LD_LIBRARY_PATH

rm -f example-state-machine example-no-bson

# Build example-state-machine, dynamic linking against libmongocrypt
gcc $(pkg-config --cflags libmongocrypt libbson-static-1.0) -o example-state-machine test/example-state-machine.c $(pkg-config --libs libmongocrypt)
# Build example-no-bson, dynamic linking against libmongocrypt
gcc $(pkg-config --cflags libmongocrypt) -o example-no-bson test/example-no-bson.c $(pkg-config --libs libmongocrypt)
export LD_LIBRARY_PATH="$(native_path $_bson_install_dir/lib):$(native_path $_bson_install_dir/lib64):$(native_path $_mongocrypt_install_dir/lib):$(native_path $_mongocrypt_install_dir/lib64)"
./example-state-machine
./example-no-bson
unset LD_LIBRARY_PATH

rm -f example-state-machine example-no-bson

