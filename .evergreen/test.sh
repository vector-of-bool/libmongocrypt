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

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

if [ "${OS_NAME}" = "windows" ]; then
    # Make sure libbson dll is in the path
    export PATH=${BSON_INSTALL_PREFIX}/bin:$PATH
fi

function run_test() {
    local _name="$1"
    shift
    if test -n "${VALGRIND:-}"; then
        log "Running test under valgrind: ${_name}"
        ${VALGRIND} "${@}"
    else
        log "Running test: ${_name}"
        command "${@}"
    fi
}

pushd "${LIBMONGOCRYPT_DIR}/kms-message"
run_test "kms-message" \
    "${LIBMONGOCRYPT_BUILD_ROOT}/default/kms-message/${BUILD_DIR_INFIX}/test_kms_request"
popd

pushd "${LIBMONGOCRYPT_DIR}"
run_test "libmongocrypt main" \
    env MONGOCRYPT_TRACE=ON \
    "${LIBMONGOCRYPT_BUILD_ROOT}/default/${BUILD_DIR_INFIX}/test-mongocrypt"

run_test "Example state machine" \
    "${LIBMONGOCRYPT_BUILD_ROOT}/default/${BUILD_DIR_INFIX}/example-state-machine"

run_test "Example state machine (statically linked)" \
    "${LIBMONGOCRYPT_BUILD_ROOT}/default/${BUILD_DIR_INFIX}/example-state-machine-static"

run_test "libmongocrypt with no native crypto" \
    env MONGOCRYPT_TRACE=ON  \
    "${LIBMONGOCRYPT_BUILD_ROOT}/nocrypto/${BUILD_DIR_INFIX}/test-mongocrypt"
popd
