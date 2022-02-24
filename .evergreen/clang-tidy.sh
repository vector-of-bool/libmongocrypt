#!/bin/bash
# Run after running "CONFIGURE_ONLY=ON compile.sh" to run the clang-tidy
# static analyzer.
#

. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

: "${CLANG_TIDY_EXECUTABLE:=/opt/mongodbtoolchain/v3/bin/clang-tidy}"

have_command "${CLANG_TIDY_EXECUTABLE}" || fail "No clang-tidy executable"

python "${LIBMONGOCRYPT_DIR}/etc/list-compile-files.py" "${LIBMONGOCRYPT_BUILD_DIR}/default/" \
    | xargs "$CLANG_TIDY_EXECUTABLE" -p "${LIBMONGOCRYPT_BUILD_DIR}/default/"
