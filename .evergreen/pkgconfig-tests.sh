#!/bin/bash

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

set -x

if ! have_command pkg-config; then
    echo "pkg-config not present on this platform; skipping test ..."
    exit 0
fi

pkgconfig_tests_root="$LIBMONGOCRYPT_DIR/cmake-build/pkgconfig_tests"

rm -rf "$pkgconfig_tests_root"
mkdir -p "$pkgconfig_tests_root"

# Build and install a version of libbson for testing
mongoc_dir="$pkgconfig_tests_root/mongo-c-driver"
run_chdir "$pkgconfig_tests_root" "$EVG_DIR/prep_c_driver_source.sh"
bson_install_dir="$pkgconfig_tests_root/bson-install"
bash "$EVG_DIR/build_one.sh" \
    --source-dir "$mongoc_dir" \
    --install-dir "$bson_install_dir" \
    --no-test \
    -D BUILD_TESTING=OFF \
    -D ENABLE_MONGOC=OFF

# Build libmongocrypt, static linking against libbson and configured for the PPA
mc_build_dir="$pkgconfig_tests_root/mc-cmake-build"
mc_install_dir="$pkgconfig_tests_root/mc-install"
bash "$EVG_DIR/build_one.sh" \
    --source-dir "$LIBMONGOCRYPT_DIR" \
    --build-dir "$mc_build_dir" \
    --install-dir "$mc_install_dir" \
    -D ENABLE_BUILD_FOR_PPA=ON \
    -D USE_SHARED_LIBBSON=OFF \
    -D CMAKE_PREFIX_PATH="$bson_install_dir"

# Find the directory that holds the libmongocrypt.pc file:
mc_pc_dir="$(dirname "$(find "$mc_install_dir" -name libmongocrypt.pc)")"
# Find the directory that contains the libbson pc file:
bson_pc_dir="$(dirname "$(find "$bson_install_dir" -name libbson-1.0.pc)")"

# Generate a library path for dynamic library lookup for our installed builds:
paths=({"$mc_install_dir","$bson_install_dir"}/{lib,lib64})
ld_lib_path="LD_LIBRARY_PATH=$(join_str ':' "${paths[@]}")"

# To validate the pkg-config scripts, we don't want the libbson scripts to be always visible, so we installed
# the components in diferent directories
echo "Validating pkg-config scripts"
export PKG_CONFIG_PATH
# Only libmongocrypt is visible:
PKG_CONFIG_PATH="$mc_pc_dir"
# Check that they resolve, even though libbson isn't visible (because libbson
# should not be a public requirement of the prior build)
pkg-config --debug --print-errors --exists libmongocrypt-static
pkg-config --debug --print-errors --exists libmongocrypt

# Make both visible simultaneously:
PKG_CONFIG_PATH="$mc_pc_dir:$bson_pc_dir"

# Attempt to build the libmongocrypt examples with out installed libraries:
pushd $LIBMONGOCRYPT_DIR
    # Build example-state-machine, static linking against libmongocrypt
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
    env "$ld_lib_path" ./example-state-machine
    env "$ld_lib_path" ./example-no-bson
    rm -f example-state-machine example-no-bson
popd

# Build libmongocrypt, this time dynamic linking agianst libbson, not for the PPA
bash "$EVG_DIR/build_one.sh" \
    --source-dir "$LIBMONGOCRYPT_DIR" \
    --build-dir "$mc_build_dir" \
    --install-dir "$mc_install_dir" \
    -D ENABLE_BUILD_FOR_PPA=OFF \
    -D USE_SHARED_LIBBSON=ON \
    -D CMAKE_PREFIX_PATH="$bson_install_dir"

# Again, attempt to build the libmongocrypt examples with out installed libraries:
pushd $LIBMONGOCRYPT_DIR
    gcc $(pkg-config --cflags libmongocrypt-static libbson-static-1.0) -o example-state-machine test/example-state-machine.c $(pkg-config --libs libmongocrypt-static)
    # Build example-no-bson, static linking against libmongocrypt
    gcc $(pkg-config --cflags libmongocrypt-static) -o example-no-bson test/example-no-bson.c $(pkg-config --libs libmongocrypt-static)
    env "$ld_lib_path" ./example-state-machine
    env "$ld_lib_path" ./example-no-bson
    rm -f example-state-machine example-no-bson

    # Build example-state-machine, dynamic linking against libmongocrypt
    gcc $(pkg-config --cflags libmongocrypt libbson-static-1.0) -o example-state-machine test/example-state-machine.c $(pkg-config --libs libmongocrypt)
    # Build example-no-bson, dynamic linking against libmongocrypt
    gcc $(pkg-config --cflags libmongocrypt) -o example-no-bson test/example-no-bson.c $(pkg-config --libs libmongocrypt)
    env "$ld_lib_path" ./example-state-machine
    env "$ld_lib_path" ./example-no-bson
    rm -f example-state-machine example-no-bson
popd


