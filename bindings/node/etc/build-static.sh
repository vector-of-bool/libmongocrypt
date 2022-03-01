#!/usr/bin/env bash -x

DEPS_PREFIX="$(pwd)/deps"
BUILD_DIR=$DEPS_PREFIX/tmp
LIBMONGOCRYPT_DIR="$(pwd)/../../"
TOP_DIR="$(pwd)/../../../"
# Install libbson in our deps prefix for use by libmongocrypt
BSON_INSTALL_DIR=$DEPS_PREFIX

# create relevant folders
mkdir -p $DEPS_PREFIX
mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/libmongocrypt-build

. "${LIBMONGOCRYPT_DIR}/.evergreen/init.sh"

pushd $DEPS_PREFIX #./deps
pushd $BUILD_DIR #./deps/tmp

pushd $TOP_DIR
# build and install bson

# NOTE: we are setting -DCMAKE_INSTALL_LIBDIR=lib to ensure that the built
# files are always installed to lib instead of alternate directories like
# lib64.
# NOTE: On OSX, -DCMAKE_OSX_DEPLOYMENT_TARGET can be set to an OSX version
# to suppress build warnings. However, doing that tends to break some
# of the versions that can be built
export BSON_EXTRA_CMAKE_FLAGS="-DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_OSX_DEPLOYMENT_TARGET=10.12"
if [ "${OS_NAME}" = "windows" ]; then
  # Older mongoc project does not respect MSVC_RUNTIME_LIBRARY. Set it with a flag:
  export BSON_EXTRA_CMAKE_FLAGS="${BSON_EXTRA_CMAKE_FLAGS} -DCMAKE_C_FLAGS_RELWITHDEBINFO=/MT"
fi

. ${TOP_DIR}/libmongocrypt/.evergreen/build_install_bson.sh

popd #./deps/tmp

# build and install libmongocrypt
pushd libmongocrypt-build #./deps/tmp/libmongocrypt-build

if [ "${OS_NAME}" = "windows" ]; then
    # W4996 - POSIX name for this item is deprecated
    # TODO: add support for clang-cl which is detected as MSVC
    LIBMONGOCRYPT_CFLAGS="/WX"
else
    # GNU, Clang, AppleClang
    LIBMONGOCRYPT_CFLAGS="-fPIC -Werror"
fi

_cmake_flags=(-DDISABLE_NATIVE_CRYPTO=1 -DCMAKE_INSTALL_LIBDIR=lib)
if [ "${OS_NAME}" = "windows" ]; then
  # Set a platform+toolset
  _cmake_flags+=(-Thost=x64 -A x64)
  # Enable the static CRT
  LIBMONGOCRYPT_CFLAGS="${LIBMONGOCRYPT_CFLAGS} /MT"
fi

cmake_build_py \
  --source-dir "${LIBMONGOCRYPT_DIR}" \
  --build-dir "$(pwd)" \
  --config RelWithDebInfo \
  "${_cmake_flags[@]}" \
  -D CMAKE_C_FLAGS="${LIBMONGOCRYPT_CFLAGS}" \
  -D CMAKE_PREFIX_PATH="${DEPS_PREFIX}" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.12" \
  --install-prefix="${DEPS_PREFIX}" \
  --install

popd #./deps/tmp

popd #./deps
popd #./

# build the `mongodb-client-encryption` addon
# note the --unsafe-perm parameter to make the build work
# when running as root. See https://github.com/npm/npm/issues/3497
BUILD_TYPE=static npm install --unsafe-perm --build-from-source
