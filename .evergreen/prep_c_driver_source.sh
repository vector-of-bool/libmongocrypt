#!/bin/bash

set -o xtrace
set -o errexit

# Download mongo-c-driver source at pinned version for testing
MONGO_C_DRIVER_VERSION=1.17.0

mkdir -p mongo-c-driver
curl -sL "https://github.com/mongodb/mongo-c-driver/archive/refs/tags/${MONGO_C_DRIVER_VERSION}.tar.gz" | \
    tar -xzf - --strip-components=1 -C mongo-c-driver
echo $MONGO_C_DRIVER_VERSION > mongo-c-driver/VERSION_CURRENT
