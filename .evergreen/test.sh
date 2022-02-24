#!/bin/bash
#
# Sets up a testing environment and runs test_kms_request and test-mongocrypt.
#
# Assumes the current working directory contains libmongocrypt.
# So script should be called like: ./libmongocrypt/.evergreen/test.sh
# The current working directory should be empty aside from 'libmongocrypt'.
#
# Set the VALGRIND environment variable to "valgrind <opts>" to run through valgrind.
#

. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

if [ "${OS_NAME}" = "windows" ]; then
    # Make sure libbson dll is in the path
    export PATH=${BSON_INSTALL_PREFIX}/bin:$PATH
fi

function run_test() {
    local _name="$1"
    shift
    if have_command valgrind; then
        echo "Running test under valgrind: ${_name}"
        valgrind "${@}"
    else
        echo "Running test: ${_name}"
        command "${@}"
    fi
}

run_test "kms-message" \
    "${LIBMONGOCRYPT_BUILD_DIR}/default/kms-message/${BUILD_DIR_INFIX}/test_kms_request"

run_test "libmongocrypt main" \
    env MONGOCRYPT_TRACE=ON \
    "${LIBMONGOCRYPT_BUILD_DIR}/default/${BUILD_DIR_INFIX}/test-mongocrypt"

run_test "Example state machine" \
    "${LIBMONGOCRYPT_BUILD_DIR}/default/${BUILD_DIR_INFIX}/example-state-machine"

run_test "Example state machine (statically linked)" \
    "${LIBMONGOCRYPT_BUILD_DIR}/default/${BUILD_DIR_INFIX}/example-state-machine-static"

run_test "libmongocrypt with no native crypto" \
    env MONGOCRYPT_TRACE=ON  \
    "${LIBMONGOCRYPT_BUILD_DIR}/nocrypto/${BUILD_DIR_INFIX}/test-mongocrypt"
