#!/bin/bash

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

# Clone mongo-c-driver and check out to a tagged version.
MONGO_C_DRIVER_VERSION=1.17.0

# Force checkout with lf endings since .sh must have lf, not crlf on Windows
echo "Cloning mongo-c-driver@${MONGO_C_DRIVER_VERSION}"
git clone git@github.com:mongodb/mongo-c-driver.git \
    --config core.eol=lf \
    --config core.autocrlf=false \
    --config advice.detachedHead=false \
    --quiet \
    --depth=1 \
    --branch="$MONGO_C_DRIVER_VERSION" \
    "mongo-c-driver"
echo $MONGO_C_DRIVER_VERSION > mongo-c-driver/VERSION_CURRENT

echo "CMAKE=\"$(get_cmake_exe)\"" > mongo-c-driver/.evergreen/find-cmake.sh
