#!/bin/bash

set -ex

_version=3.22.2
_prefix=$PWD/_cmake

if test -n "${CMAKE:-}" && test -f "${CMAKE}"; then
    # Do nothing. CMake is already found
    true
elif test -d /Applications/; then
    # We're on macOS
    curl "https://github.com/Kitware/CMake/releases/download/v${_version}/cmake-${_version}-macos-universal.tar.gz" \
        -sLo "$PWD/cmake.tgz"
    mkdir -p "${_prefix}"
    tar -x --strip-components=3 \
        -C "${_prefix}" \
        -f "$PWD/cmake.tgz"
    CMAKE=${_prefix}/bin/cmake
elif test -d /cygdrive/c/; then
    # We are on Windows
    curl "https://github.com/Kitware/CMake/releases/download/v${_version}/cmake-${_version}-windows-x86_64.zip" \
        -sLo "$PWD/cmake.zip"
    mkdir -p "${_prefix}"
    unzip -d "${_prefix}" "$PWD/cmake.zip"
    CMAKE="${_prefix}/cmake-${_version}-windows-x86_64/bin/cmake.exe"
elif type uname > /dev/null && test "$(uname -s)" = "Linux"; then
    _arch=$(uname -p)
    if test "${_arch}" = "unknown"; then
        echo "uname reported arch to be 'unknown'. We'll default to x86_64 for now"
        _arch="x86_64"
    fi
    curl "https://github.com/Kitware/CMake/releases/download/v${_version}/cmake-${_version}-linux-${_arch}.sh" \
        -sLo "$PWD/cmake.sh"
    mkdir -p "${_prefix}"
    sh "$PWD/cmake.sh" --exclude-subdir "--prefix=${_prefix}" --skip-license
    CMAKE="${_prefix}/bin/cmake"
else
    echo "Don't know how to get a CMake for this platform" 1>&2
    exit 1
fi
