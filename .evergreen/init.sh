#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

# Print a message and return non-zero
function fail() {
    echo "${@}" 1>&2
    return 1
}

# Determine whether we can execute the given name as a command
function have_command() {
    test "$#" -eq 1 || fail "have_command expects a single argument"
    if type "${1}" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Given a path string, convert it to an absolute path with no redundant components or directory separators
function abspath() {
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
    elif test "$arg" = "$_parent"; then
        # A root directory is its own parent acording to 'dirname'
        _parent="$_parent"
    else
        # Resolve the parent path
        _parent="$(abspath "$_parent")"
    fi
    # At this point $_parent is an absolute path
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
        ret="${ret//\/\///}"
    done
    echo "$ret"
}

# Get the platform name: One of 'windows', 'macos', 'linux', or 'unknown'
function os_name() {
    test "$#" -eq 0 || fail "os_name accepts no arguments"
    have_command uname || fail "No 'uname' executable found"

    local _uname="$(uname | tr '[:upper:]' '[:lower:]')"
    local _os_name="unknown"

    if [[ "$_uname" =~ 'cywin|windows|mingw|msys' ]]; then
        _os_name="windows"
    elif test "$_uname" = 'darwin'; then
        _os_name='macos'
    elif test "$_uname" = 'linux'; then
        _os_name='linux'
    fi

    echo $_os_name
}

OS_NAME="$(os_name)"

_this_file="$(abspath "${BASH_SOURCE[0]}")"
_this_dir="$(dirname "${_this_file}")"

CI_DIR="${_this_dir}"
LIBMONGOCRYPT_DIR="$(dirname "${CI_DIR}")"

BUILD_DIR="${LIBMONGOCRYPT_DIR}/_build"
INSTALL_DIR="${LIBMONGOCRYPT_DIR}/_install"

: "${EVERGREEN_DIR:="$(dirname "${LIBMONGOCRYPT_DIR}")"}"
: "${MONGO_C_DRIVER_DIR:-"$EVERGREEN_DIR/mongo-c-driver"}"
: "${LIBMONGOCRYPT_BUILD_DIR:="${BUILD_DIR}/libmongocrypt"}"
: "${LIBMONGOCRYPT_INSTALL_DIR:="${INSTALL_DIR}/libmongocrypt"}"
: "${MONGO_C_DRIVER_DIR:="${EVERGREEN_DIR}/mongo-c-driver"}"
: "${MONGO_C_DRIVER_BUILD_DIR:="${BUILD_DIR}/mongo-c-driver"}"
: "${BSON_INSTALL_DIR:="${INSTALL_DIR}/mongo-c-driver"}"

if test "${OS_NAME}" = "windows"; then
    : "${BUILD_DIR_INFIX:="RelWithDebInfo"}"
else
    : "${BUILD_DIR_INFIX:="."}"
fi

function get_cmake_exe() {
    set +x
    set -eu

    # The version of CMake that we will be downloading
    local _version=3.22.2
    local _caches_root

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
        echo "No caching directory found for this platform" 1>&2
        _caches_root="$(pwd)/_cache"
    fi

    _caches_root="$(abspath "$_caches_root")"

    local _cmake_prefix=${_caches_root}/mongocrypt-build/_cmake-${_version}
    local _cmake_tmp="${_cmake_prefix}.tmp"
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
    elif test -d /cygdrive/c/; then
        # We are on Windows
        curl "https://github.com/Kitware/CMake/releases/download/v${_version}/cmake-${_version}-windows-x86_64.zip" \
            -sLo "$PWD/cmake.zip"
        mkdir -p "${_cmake_tmp}"
        unzip -d "${_cmake_tmp}" "$PWD/cmake.zip"
        mv "${_cmake_tmp}/cmake-${_version}-windows-x86_64" "${_cmake_prefix}"
    elif type uname > /dev/null && test "$(uname -s)" = "Linux"; then
        _arch=$(uname -p)
        if test "${_arch}" = "unknown"; then
            echo "uname reported arch to be 'unknown'. We'll default to x86_64 for now" 1>&2
            _arch="x86_64"
        fi
        curl "https://github.com/Kitware/CMake/releases/download/v${_version}/cmake-${_version}-linux-${_arch}.sh" \
            -sLo "$PWD/cmake.sh"
        mkdir -p "${_cmake_tmp}"
        sh "$PWD/cmake.sh" --exclude-subdir "--prefix=${_cmake_tmp}" --skip-license 1> /dev/null
        mv "${_cmake_tmp}" "${_cmake_prefix}"
    else
        echo "Don't know how to get a CMake for this platform" 1>&2
        exit 1
    fi

    echo "$_cmake_prefix/bin/cmake"
}

_CMAKE_BUILD_PY="${CI_DIR}/build.py"

function cmake_build_py() {
    set -eu
    local _cmake="$(get_cmake_exe)"
    python -u "${_CMAKE_BUILD_PY}" --cmake="${_cmake}" --generator=Ninja "${@}"
}
