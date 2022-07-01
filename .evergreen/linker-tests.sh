#!/bin/bash

. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

# Directory layout
# .evergreen
# -linker_tests_deps
# --app
# --bson_patches
#
# linker_tests (created by this script)
#   lmc-build/ (for artifacts built from libmongocrypt source)
#   app-cmake-build/
#   mongo-c-driver/
#       _build/
#   installed/
#

linker_tests_root="$LIBMONGOCRYPT_DIR/_build/linker_tests"
linker_tests_deps_root="$CI_DIR/linker_tests_deps"

# Directory where temporary build results will be installed for use in subsequent steps
install_dir="$linker_tests_root/installed"
rm -rf -- "$install_dir"

mkdir -p -- "$linker_tests_root"

# Clone mongo-c-driver for libbson
patched_mongoc_dir="$(native_path "$linker_tests_root/mongo-c-driver")"
rm -rf "$patched_mongoc_dir"
# Clones mongoc into the $patched_mongoc_dir:
run_chdir "$linker_tests_root" "$CI_DIR/prep_c_driver_source.sh"
mongoc_build_dir="$patched_mongoc_dir/_build"

# Patch and build libbson1
run_chdir "$patched_mongoc_dir" \
    git apply --ignore-whitespace "$(native_path $linker_tests_deps_root/bson_patches/libbson1.patch)"
bash "$CI_DIR/build_one.sh" \
    --source-dir "$patched_mongoc_dir" \
    --install-dir "$install_dir" \
    --no-test \
    -D ENABLE_MONGOC=OFF

# Re-patch to libbson2
# (No need to build. We can inject it directly into the next libmongocrypt build.)
run_chdir "$patched_mongoc_dir" git reset --hard
run_chdir "$patched_mongoc_dir" git apply --ignore-whitespace "$(native_path $linker_tests_deps_root/bson_patches/libbson2.patch)"

# Build and install libmongocrypt, static linking against the patched libbson2
bash "$CI_DIR/build_one.sh" \
    --source-dir "$LIBMONGOCRYPT_DIR" \
    --build-dir "$linker_tests_root/lmc-build" \
    --install-dir "$install_dir" \
    --no-test \
    -D USE_SHARED_LIBBSON=OFF \
    -D BUILD_TESTING=OFF \
    -D MONGOCRYPT_MONGOC_DIR="$patched_mongoc_dir"

echo "Test case: Modelling libmongoc's use"
# app links against libbson1.so
# app links against libmongocrypt.so
app_build_dir="$linker_tests_root/app-cmake-build"
bash "$CI_DIR/build_one.sh" \
    --source-dir "$linker_tests_deps_root/app" \
    --build-dir "$app_build_dir" \
    --no-test \
    -D CMAKE_PREFIX_PATH="$install_dir"

if [ "$OS_NAME" == "windows" ]; then
    export PATH="$PATH:$install_dir/bin"
fi
APP_CMD="$app_build_dir/app"

check_output () {
    output="$("$APP_CMD")"
    if [[ "$output" != *"$1"* ]]; then
        printf "     Got: %s\nExpected: %s\n" "$output" "$1"
        exit 1;
    fi
    echo "ok"
}
check_output ".calling bson_malloc0..from libbson1..calling mongocrypt_binary_new..from libbson2."
exit 0
