#!/bin/bash
# Downloads and prepares the C driver source, then compiles libmongocrypt's
# dependencies and targets.
#
# Assumes the current working directory contains libmongocrypt.
# So script should be called like: ./libmongocrypt/.evergreen/compile.sh
# The current working directory should be empty aside from 'libmongocrypt'
# since this script creates new directories/files (e.g. mongo-c-driver, venv).
#
# NOTE: This script is not meant to be invoked for Evergreen builds.  It is a
# convenience script for users of libmongocrypt

. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

bash "${CI_DIR}/prep_c_driver_source.sh"
bash "${CI_DIR}/build_all.sh"
