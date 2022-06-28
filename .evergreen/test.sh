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

set -o errexit
set -o xtrace

evergreen_root="$(pwd)"

. ${evergreen_root}/libmongocrypt/.evergreen/setup-env.sh

KMS_BIN_DIR=./cmake-build/kms-message

echo "Running kms-message tests."
cd libmongocrypt/kms-message
$VALGRIND ../${KMS_BIN_DIR}/test_kms_request
cd ../..
