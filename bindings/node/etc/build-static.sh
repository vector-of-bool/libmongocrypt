#!/usr/bin/env bash -x

LIBMONGOCRYPT_DIR="$(pwd)/../../"
. "$LIBMONGOCRYPT_DIR/.evergreen/init.sh"
set +u

DEPS_PREFIX="$(pwd)/deps"
BUILD_DIR=$DEPS_PREFIX/tmp
TOP_DIR="$(pwd)/../../../"

if [[ -z $CMAKE ]]; then
  CMAKE=`type -P cmake`
fi

# build and install libmongocrypt
mkdir -p $BUILD_DIR/libmongocrypt-build
pushd $BUILD_DIR/libmongocrypt-build  #./deps/tmp/libmongocrypt-build

flags=(
  -D DISABLE_NATIVE_CRYPTO=TRUE
  -D CMAKE_INSTALL_LIBDIR=lib
  -D ENABLE_MORE_WARNINGS_AS_ERRORS=ON
  -D CMAKE_OSX_DEPLOYMENT_TARGET=10.12
  -D CMAKE_PREFIX_PATH="$(native_path "$DEPS_PREFIX")"
  --install-dir "$(native_path "$DEPS_PREFIX")"
  --build-dir "$PWD"
)

if test "$OS" = "Windows_NT"; then
  flags+=(
    -D "CMAKE_C_FLAGS_RELWITHDEBINFO=-MT"
  )
fi

bash "$LIBMONGOCRYPT_DIR/.evergreen/build_one.sh" "${flags[@]}"

popd #./

# build the `mongodb-client-encryption` addon
# note the --unsafe-perm parameter to make the build work
# when running as root. See https://github.com/npm/npm/issues/3497
BUILD_TYPE=static npm install --unsafe-perm --build-from-source
