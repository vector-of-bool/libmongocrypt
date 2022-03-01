#!/bin/bash

# Test the Java bindings for libmongocrypt

set -e
. "$(dirname "${BASH_SOURCE[0]}")/../../../../.evergreen/init.sh"

set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

if [ "${OS_NAME}" = "windows" ]; then
   : "${JAVA_HOME:=/cygdrive/c/java/jdk8}"
else
   : "${JAVA_HOME:=/opt/java/jdk8}"
fi

export JAVA_HOME

./gradlew -version

_lib="$(native_path "${LIBMONGOCRYPT_INSTALL_ROOT}/lib")"
_lib64="$(native_path "${LIBMONGOCRYPT_INSTALL_ROOT}/lib64")"
./gradlew clean check --info -Djna.debug_load=true "-Djna.library.path=${_lib}:${_lib64}"
