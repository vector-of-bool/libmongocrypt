#!/bin/bash

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

# Change the path to the driver dir to a scratch-space clone
MONGO_C_DRIVER_DIR="${BUILD_ROOT}/mcd-clone"

# Clone mongo-c-driver and check out to a tagged version.
MONGO_C_DRIVER_VERSION=1.17.0

# Force checkout with lf endings since .sh must have lf, not crlf on Windows
if ! test -d "${MONGO_C_DRIVER_DIR}/.git"; then
    echo "Cloning mongo-c-driver@${MONGO_C_DRIVER_VERSION}"
    git clone https://github.com/mongodb/mongo-c-driver.git \
        --config core.eol=lf \
        --config core.autocrlf=false \
        --config advice.detachedHead=false \
        --quiet \
        --depth=1 \
        --branch="$MONGO_C_DRIVER_VERSION" \
        "${MONGO_C_DRIVER_DIR}"
fi
git -C "${MONGO_C_DRIVER_DIR}" fetch origin "${MONGO_C_DRIVER_VERSION}" --depth=1
git -C "${MONGO_C_DRIVER_DIR}" checkout "${MONGO_C_DRIVER_VERSION}"

echo $MONGO_C_DRIVER_VERSION > "${MONGO_C_DRIVER_DIR}/VERSION_CURRENT"

# Override the project's find-cmake to use the same one that we are using
echo "CMAKE=\"$(get_cmake_exe)\"" > "${MONGO_C_DRIVER_DIR}/.evergreen/find-cmake.sh"
