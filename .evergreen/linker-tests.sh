#!/bin/bash

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

# This script tests that a program can successfully link to a dynamic
# libmongocrypt that was statically linked with libbson, while that program
# also statically links to a *different* set of libbson code, and the resulting
# symbols do not conflict.

have_command git || fail "linker-tests.sh requires a Git executable on the PATH"

. "${CI_DIR}/prep_c_driver_source.sh"

# A scratch directory where we will do our work:
_scratch_dir="${BUILD_ROOT}/linker_tests"
# Patches and the test app:
_linker_tests_deps_dir="${CI_DIR}/linker_tests_deps"

# Directory where we will put a temporary copy of mongo-c-driver to patch over it for testing
_mcd_clone_dir="${_scratch_dir}/mongo-c-driver"

# Destination of temporary builds and installs
_build_prefix="${_scratch_dir}/build"
_install_prefix="${_scratch_dir}/install"

# Tell mongo-c-driver what version it is via the BUILD_VERSION setting
_mcd_version="1.17.0"

# Create a clean scratch directory
rm -rf "${_scratch_dir}"
mkdir -p "${_scratch_dir}"

# Clone the MONGO_C_DRIVER that we have been using for CI
debug "Cloning mongo-c-driver from directory [${MONGO_C_DRIVER_DIR}]"
git clone --quiet "file://${MONGO_C_DRIVER_DIR}" --depth=1 "${_mcd_clone_dir}"

# Setup common build options, passed to cmake_build_py
_build_flags=(--config="${DEFAULT_CMAKE_BUILD_TYPE}")
if [ "${OS_NAME}" = "Windows_NT" -a "${WINDOWS_32BIT:-}" != "ON" ]; then
    debug "Building for Windows x64"
    _build_flags+=(-T host=x64 -A x64)
fi

if [ "${MACOS_UNIVERSAL:-}" = "ON" ]; then
    debug "Building for macOS universal arm64+x86_64"
    _build_flags+=(-D "CMAKE_OSX_ARCHITECTURES=arm64;x86_64")
fi

# Make libbson1
debug "Creating libbson1"
_bson1_install_dir="$_install_prefix/bson1"
git -C "${_mcd_clone_dir}" apply \
    --ignore-whitespace \
    "$_linker_tests_deps_dir/bson_patches/libbson1.patch"
cmake_build_py \
    -D ENABLE_MONGOC=OFF \
    -D BUILD_VERSION="${_mcd_version}" \
    "${_build_flags[@]}" \
    --install-prefix="${_bson1_install_dir}" \
    --source-dir="${_mcd_clone_dir}" \
    --build-dir="${_build_prefix}/bson1" \
    --install

# Make libbson2
# Reset the source and apply a different patch
debug "Creating libbson2"
git -C "${_mcd_clone_dir}" checkout --force -- "${_mcd_clone_dir}"
git -C "${_mcd_clone_dir}" apply \
    --ignore-whitespace \
    "$_linker_tests_deps_dir/bson_patches/libbson2.patch"
# Build and install that into another directory:
_bson2_install_dir="$_install_prefix/bson2"
cmake_build_py \
    -D ENABLE_MONGOC=OFF \
    "${_build_flags[@]}" \
    --install-prefix="${_bson2_install_dir}" \
    --source-dir="${_mcd_clone_dir}" \
    --build-dir="${_build_prefix}/bson2" \
    --install

# Build dynamic libmongocrypt that static links against our libbson2
debug "Creating libmongocrypt linking statically against libbson2"
_lmcr_install_dir="${_install_prefix}/libmongocrypt"
cmake_build_py \
    "${_build_flags[@]}" \
    -D CMAKE_PREFIX_PATH="$_bson2_install_dir" \
    -D MONGOCRYPT_MONGOC_DIR="${_mcd_clone_dir}" \
    --install-prefix="${_lmcr_install_dir}" \
    --source-dir="${LIBMONGOCRYPT_DIR}" \
    --build-dir="${_build_prefix}/libmongocrypt" \
    --install

# Now build an application that links both to dynamic libbson1 and the dynamic
# libmongocrypt that was statically linked to libbson2
debug "Creating test application static linking to libbson1 and dynamic linking to libmongocrypt"
_app_build_dir="${_build_prefix}/app"
cmake_build_py \
    "${_build_flags[@]}" \
    -D CMAKE_PREFIX_PATH="$_bson1_install_dir;$_lmcr_install_dir" \
    --source-dir="${_linker_tests_deps_dir}/app" \
    --build-dir="${_app_build_dir}"

if [ "${OS_NAME}" = "windows" ]; then
    # Make sure the dlls are in the path
    export PATH="$_lmcr_install_dir/bin:$_bson1_install_dir/bin:$PATH"
fi

# Check that the built app gives the right output
debug "Testing created application..."
_app_output="$(command "${_app_build_dir}/${BUILD_DIR_INFIX}/app")"
_expect_output=".calling bson_malloc0..from libbson1..calling mongocrypt_binary_new..from libbson2."
if test "${_app_output}" != "${_expect_output}"; then
    echo "Got '${_app_output}', expected '${_expect_output}'" 1>&2
    exit 1
fi

echo "linker-tests pass!"
