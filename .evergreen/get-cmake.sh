#!/bin/bash

set -ex

# The version of CMake that we will be downloading
_version=3.22.2

# Given a path string, convert it to an absolute path
function abspath() {
    set +x
    set -eu
    local ret
    local arg="$1"
    # The parent path:
    local _parent="$(dirname "$arg")"
    # The filename part:
    local _fname="$(basename "$arg")"
    if test "$_parent" = "."; then
        # Replace the leading '.' with the working directory
        _parent="$PWD"
    elif test "$_parent" = ".."; then
        # Replace a leading '..' with the parent of the working directory
        _parent="$(dirname "$PWD")"
    elif test "$arg" = "/"; then
        # A top-level '/' is just the top
        _parent="/"
    else
        # Resolve the parent path
        _parent="$(abspath "$_parent")"
    fi
    if test "$_fname" = ".."; then
        # Strip one component
        ret="$(dirname "$_parent")"
    elif test "$_fname" = "."; then
        # Drop a '.' in the middle of a path
        ret="$_parent"
    else
        # Join the result
        ret="$_parent/$_fname"
    fi
    # Remove duplicate dir separators
    while [[ "$ret" =~ "//" ]]; do
        ret="${ret//\/\//\/}"
    done
    echo "$ret"
}

# Find the user-local caches directory
if test -n "${XDG_CACHE_HOME:-}"; then
    _caches_root="${XDG_CACHE_HOME}"
elif test -n "${AppDataLocal:-}"; then
    _caches_root="${LocalAppData}"
elif test -d "$HOME/Library/Caches"; then
    _caches_root="${HOME}/Library/Caches"
elif test -d "$HOME/.cache"; then
    _caches_root="${HOME}/.cache"
else
    echo "No caching directory found for this platform" 2>&1
    _caches_root="$(pwd)/_cache"
fi

_caches_root="$(abspath "$_caches_root")"

_cmake_prefix=${_caches_root}/mongocrypt-build/_cmake-${_version}
_cmake_tmp="${_cmake_prefix}.tmp"
test -d "${_cmake_tmp}" && rm -r "${_cmake_tmp}"

if test -d "${_cmake_prefix}"; then
    # We already have a CMake cached and downloaded
    true
elif test -d /Applications/; then
    # We're on macOS
    curl "https://github.com/Kitware/CMake/releases/download/v${_version}/cmake-${_version}-macos-universal.tar.gz" \
        -sLo "$PWD/cmake.tgz"
    mkdir -p "${_cmake_tmp}"
    tar -x --strip-components=3 \
        -C "${_cmake_tmp}" \
        -f "$PWD/cmake.tgz"
    mv "${_cmake_tmp}" "${_cmake_prefix}"
    CMAKE="${_cmake_prefix}/bin/cmake"
elif test -d /cygdrive/c/; then
    # We are on Windows
    curl "https://github.com/Kitware/CMake/releases/download/v${_version}/cmake-${_version}-windows-x86_64.zip" \
        -sLo "$PWD/cmake.zip"
    mkdir -p "${_cmake_tmp}"
    unzip -d "${_cmake_tmp}" "$PWD/cmake.zip"
    mv "${_cmake_tmp}/cmake-${_version}-windows-x86_64" "${_cmake_prefix}"
    CMAKE="${_cmake_prefix}/bin/cmake.exe"
elif type uname > /dev/null && test "$(uname -s)" = "Linux"; then
    _arch=$(uname -p)
    if test "${_arch}" = "unknown"; then
        echo "uname reported arch to be 'unknown'. We'll default to x86_64 for now"
        _arch="x86_64"
    fi
    curl "https://github.com/Kitware/CMake/releases/download/v${_version}/cmake-${_version}-linux-${_arch}.sh" \
        -sLo "$PWD/cmake.sh"
    mkdir -p "${_cmake_tmp}"
    sh "$PWD/cmake.sh" --exclude-subdir "--prefix=${_cmake_tmp}" --skip-license
    mv "${_cmake_tmp}" "${_cmake_prefix}"
    CMAKE="${_cmake_prefix}/bin/cmake"
else
    echo "Don't know how to get a CMake for this platform" 1>&2
    exit 1
fi

CMAKE="${_cmake_prefix}/bin/cmake"

THIS_FILE="$(abspath "${BASH_SOURCE[0]}")"
THIS_DIR="$(dirname "${THIS_FILE}")"
_CMAKE_BUILD_PY="${THIS_DIR}/build.py"

function cmake_build_py() {
    set -e
    python -u "${_CMAKE_BUILD_PY}" --cmake="${CMAKE}" "${@}"
}

echo $(abspath ../foo/bar)