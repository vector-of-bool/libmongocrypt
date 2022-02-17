#!/bin/bash
set -o xtrace
set -o errexit

system_path () {
    if [ "$OS" == "Windows_NT" ]; then
        cygpath -a "$1" -w
    else
        echo $1
    fi
}

# Directory layout
# .evergreen
# -linker_tests_deps
# --app
# --bson_patches
#
# linker_tests (created by this script)
# -libmongocrypt-cmake-build (for artifacts built from libmongocrypt source)
# -app-cmake-build
# -mongo-c-driver
# --cmake-build
# -install
# --bson1
# --bson2
# --libmongocrypt
#

if [ ! -e ./.evergreen ]; then
    echo "Error: run from libmongocrypt root"
    exit 1;
fi

libmongocrypt_root=$(pwd)
linker_tests_root=${libmongocrypt_root}/linker_tests
linker_tests_deps_root=${libmongocrypt_root}/.evergreen/linker_tests_deps

rm -rf linker_tests
mkdir -p linker_tests/{install,libmongocrypt-cmake-build,app-cmake-build}
cd linker_tests

# Make libbson1 and libbson2
$libmongocrypt_root/.evergreen/prep_c_driver_source.sh
mcd_dir=$(readlink -m mongo-c-driver)

. "${libmongocrypt_root}/.evergreen/get-cmake.sh"

if [ "$MACOS_UNIVERSAL" = "ON" ]; then
    ADDITIONAL_CMAKE_FLAGS="$ADDITIONAL_CMAKE_FLAGS -DCMAKE_OSX_ARCHITECTURES='arm64;x86_64'"
fi

# Create a libbson installation that prints 'from libbson1' in bson_malloc0
patch --unified --ignore-whitespace --strip=1 \
    --directory="$mcd_dir" \
    --input "$(system_path $linker_tests_deps_root/bson_patches/libbson1.patch)"
_build_dir="$mcd_dir/_build"
# Build and install into a scratch directory
BSON1_INSTALL_PREFIX=$(system_path $linker_tests_root/install/bson1)
$CMAKE \
    -D ENABLE_MONGOC=OFF \
    -D CMAKE_BUILD_TYPE=RelWithDebInfo \
    -D CMAKE_INSTALL_PREFIX="$BSON1_INSTALL_PREFIX" \
    -S "$mcd_dir" \
    -B "$_build_dir"
$CMAKE --build "$_build_dir" --target install -j8 --config RelWithDebInfo

# Now tweak to print 'from libbson2' in bson_malloc0
patch -u --ignore-whitespace -p1 \
    --director="$mcd_dir" \
    --input "$(system_path $linker_tests_deps_root/bson_patches/libbson2.patch)"

# Build libmongocrypt, injecting our new patched libbson2
PATCHED_MONGOCRYPT_INSTALL_DIR="$(system_path $linker_tests_root/install/libmongocrypt)"
$CMAKE \
    -D CMAKE_BUILD_TYPE=RelWithDebInfo \
    -D MONGOCRYPT_MONGOC_DIR="$mcd_dir" \
    -D CMAKE_INSTALL_PREFIX="$PATCHED_MONGOCRYPT_INSTALL_DIR" \
    -S "$(system_path $libmongocrypt_root)" \
    -B "$linker_tests_root/libmongocrypt-cmake-build"
$CMAKE \
    --build "$linker_tests_root/libmongocrypt-cmake-build" \
    -j8 \
    --target install \
    --config RelWithDebInfo

echo "Test case: Modelling libmongoc's use"
# app links against libbson1.so
# app links against libmongocrypt.so
PREFIX_PATH="$BSON1_INSTALL_PREFIX;$PATCHED_MONGOCRYPT_INSTALL_DIR"
app_build_dir="$linker_tests_root/app-cmake-build"
$CMAKE \
    -D CMAKE_BUILD_TYPE=RelWithDebInfo \
    -D CMAKE_PREFIX_PATH="$PREFIX_PATH" \
    $ADDITIONAL_CMAKE_FLAGS \
    -S "$(system_path $linker_tests_deps_root/app)" \
    -B "$app_build_dir"
$CMAKE --build "$app_build_dir" -j8 --target app --config RelWithDebInfo

if [ "$OS" == "Windows_NT" ]; then
    export PATH="$PATH:$linker_tests_root/install/bson1/bin:$linker_tests_root/install/libmongocrypt/bin"
    APP_CMD="$app_build_dir/RelWithDebInfo/app.exe"
else
    APP_CMD="$app_build_dir/app"
fi

check_output () {
    output="$($APP_CMD)"
    if [[ "$output" != *"$1"* ]]; then
        echo -e "got:      '$output'\nexpected: '$1'"
        exit 1;
    fi
    echo "ok"
}

# Both the bson_malloc0 patched versions will print. libmongocrypt dylib contains the second patched
# version, and the app refers to the first patched version
check_output ".calling bson_malloc0..from libbson1..calling mongocrypt_binary_new..from libbson2."
exit 0
