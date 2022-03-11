#!/usr/bin/env bash -x

set -e

_node_etc_dir="$(dirname "${BASH_SOURCE[0]}")"
. "${_node_etc_dir}/../../../.evergreen/init.sh"
_node_dir="$(abspath "$_node_etc_dir/..")"

DEPS_PREFIX="$_node_dir/deps"
BUILD_DIR=$DEPS_PREFIX/tmp

_common_cmake_flags=(
  -D CMAKE_PREFIX_PATH="${DEPS_PREFIX}"
  # NOTE: we are setting -DCMAKE_INSTALL_LIBDIR=lib to ensure that the built
  # files are always installed to lib instead of alternate directories like
  # lib64.
  -D CMAKE_INSTALL_LIBDIR=lib
  # NOTE: On OSX, -DCMAKE_OSX_DEPLOYMENT_TARGET can be set to an OSX version
  # to suppress build warnings. However, doing that tends to break some
  # of the versions that can be built
  -D CMAKE_OSX_DEPLOYMENT_TARGET=10.12
)

_bson_cmake_flags=("${_common_cmake_flags[@]}")

if [ "${OS_NAME}" = "windows" ]; then
  # Link libbson with the static CRT
  _bson_cmake_flags+=(-D CMAKE_C_FLAGS="-MT")
fi

# build and install bson in our deps prefix for use by libmongocrypt
env BSON_INSTALL_DIR=$DEPS_PREFIX \
  bash "${CI_DIR}/build_install_bson.sh" \
    "${_bson_cmake_flags[@]}"

# build and install libmongocrypt
_lmcr_cmake_flags=(
  "${_common_cmake_flags[@]}"
  -D DISABLE_NATIVE_CRYPTO=1
  -D ENABLE_MORE_WARNINGS_AS_ERRORS=ON
)

if [ "${OS_NAME}" = "windows" ]; then
  # Set a toolset+platform for libmongocrypt
  _lmcr_cmake_flags+=(-Thost=x64 -A x64)
  # TODO: add support for clang-cl which is detected as MSVC
  # Link with the static CRT
  _compile_flags="-MT"
else
  # GNU, Clang, AppleClang, enable position-independent-code
  _compile_flags="-fPIC"
fi

_lmcr_cmake_flags+=(-D CMAKE_C_FLAGS="${_compile_flags}")

cmake_build_py \
  --source-dir "${LIBMONGOCRYPT_DIR}" \
  --build-dir "${DEPS_PREFIX}/tmp/libmongocrypt-build" \
  --config RelWithDebInfo \
  "${_lmcr_cmake_flags[@]}" \
  --install-prefix="${DEPS_PREFIX}" \
  --install

# build the `mongodb-client-encryption` addon
# note the --unsafe-perm parameter to make the build work
# when running as root. See https://github.com/npm/npm/issues/3497
run_chdir "$_node_dir" \
  env BUILD_TYPE=static \
  npm install --unsafe-perm --build-from-source
