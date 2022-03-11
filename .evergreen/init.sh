#!/bin/bash

# Initial variables and helper functions for the libmongocrypt build

## Variables set by this file:

# CI_DIR = The path to the directory containing this script file
# LIBMONGOCRYPT_DIR = The path to the libmongocrypt source directory
# BUILD_ROOT = A scratch directory prefix for all build results
# INSTALL_ROOT = A scratch directory prefix for temporary installs
# OS_NAME = One of 'windows', 'linux', 'macos', or 'unknown'

## Variables set by this file that may be overridden:

# EVERGREEN_DIR = The evergreen workspace directory.
#       Default is the parent of LIBMONGOCRYPT_DIR
# MONGO_C_DRIVER_DIR = A directory containing the mongo-c-driver source code to
#       use for the build. Default is ${EVERGREEN_DIR}/mongo-c-driver
# LIBMONGOCRYPT_BUILD_ROOT = Prefix for all build results of libmongocrypt.
#       Further subdirectories will be created for different build variants.
#       Default is ${BUILD_ROOT}/libmongocrypt
# MONGO_C_DRIVER_BUILD_DIR = Scratch directory where mongo-c-driver will be
#       built. Default is ${BUILD_ROOT}/mongo-c-driver
# LIBMONGOCRYPT_INSTALL_ROOT = Scratch directory where libmongocrypt variants
#       will be installed for testing.
# BSON_INSTALL_DIR = Scratch directory where libbson will be installed for use
#       by libmongocrypt.
# DEFAULT_CMAKE_BUILD_TYPE = The CMake build type to use when building components.
#       Default is 'RelWithDebInfo'
# BUILD_DIR_INFIX = A path segment inserted by certain CMake build generators
#       of build results in their output directory. Default on Windows is
#       ${DEFAULT_CMAKE_BUILD_TYPE}, otherwise "."

## (All of the above directory paths are absolute paths)

## This script defines the following commands:

# * cmake_build_py --source-dir=<dir> --build-dir=<dir>
#       Runs a full CMake configure/build/install in one command.
#       See `python .evergreen/build.py --help` for more usage.
#
# * abspath <path>
#       Convert a given path into an absolute path. Relative paths are
#       resolved relative to the working directory.
#
# * get_cmake_exe
#       Echo the path to the preferred CMake executable for the build. If the
#       CMAKE environment variable is set, returns that instead.
#
# * have_command <command>
#       Return zero if <command> is the name of a command that can be executed,
#       returns non-zero otherwise.
#
# * run_chdir <dirpath> <command> [args ...]
#       Run the given command with a working directory given by <dirpath>
#
# * log <message>
#       Print <message> to stderr
#
# * fail <message>
#       Print <message> to stderr and return non-zero
#
# * native_path <path>
#       On MinGW/Cygwin/MSYS, convert the given Cygwin path to a Windows-native
#       path. NOTE: the MinGW runtime will almost always automatically convert
#       filepaths automatically when passed to non-MinGW programs, so this
#       utility is not usually needed.

set -o errexit
set -o pipefail
set -o nounset

# Inhibit msys path conversion
export MSYS2_ARG_CONV_EXCL="*"

if test "${TRACE:-0}" != "0"; then
    set -o xtrace
fi

# Write a message to stderr
function log() {
    echo "${@}" 1>&2
    return 0
}

function debug() {
    if test "${DEBUG:-0}" != "0"; then
        log "${@}"
    fi
}

# Print a message and return non-zero
function fail() {
    log "${@}"
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

# Run a command in a different directory:
# * run_chdir <dir> [command ...]
function run_chdir() {
    test "$#" -gt 2 || fail "run_chdir expects at least two arguments"
    local _dir="$1"
    shift
    pushd "$_dir"
    debug "Run in directory [$_dir]: $@"
    set +e
    command "$@"
    local _rc=$?
    set -e
    popd
    return $_rc
}

# Given a path string, convert it to an absolute path with no redundant components or directory separators
function abspath() {
    set -eu
    local ret
    local arg="$1"
    debug "Resolve path [$arg]"
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
        echo "$arg"
        return 0
    else
        # Resolve the parent path
        _parent="$(DEBUG=0 abspath "$_parent")"
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
    debug "Resolved to: [$arg] -> [$ret]"
    echo "$ret"
}

# Get the platform name: One of 'windows', 'macos', 'linux', or 'unknown'
function os_name() {
    test "$#" -eq 0 || fail "os_name accepts no arguments"
    have_command uname || fail "No 'uname' executable found"

    debug "Uname is [$(uname -a)]"
    local _uname="$(uname | tr '[:upper:]' '[:lower:]')"
    local _os_name="unknown"

    if [[ "$_uname" =~ '.*cywin|windows|mingw|msys.*' ]] || have_command cmd.exe; then
        _os_name="windows"
    elif test "$_uname" = 'darwin'; then
        _os_name='macos'
    elif test "$_uname" = 'linux'; then
        _os_name='linux'
    fi

    echo $_os_name
}

# Ensure the given path is in a native format (converts cygwin paths to Windows-local paths)
function native_path() {
    test "$#" -eq 1 || fail "native_path expects one argument"
    if test "${OS_NAME}" = "windows" && have_command cygpath; then
        debug "Convert path [$1]"
        local r="$(cygpath -w "${1}")"
        debug "Convert to [$r]"
        echo "$r"
    else
        echo "${1}"
    fi
}

OS_NAME="$(os_name)"

_init_sh_this_file="$(abspath "${BASH_SOURCE[0]}")"
_init_sh_ci_dir="$(dirname "${_init_sh_this_file}")"

# Get the CI dir as a native absolute path. All other path vars are derived from
# this one, and will therefore remain as native paths
CI_DIR="$(native_path "${_init_sh_ci_dir}")"
LIBMONGOCRYPT_DIR="$(dirname "${CI_DIR}")"

BUILD_ROOT="${LIBMONGOCRYPT_DIR}/_build"
INSTALL_ROOT="${LIBMONGOCRYPT_DIR}/_install"

: "${EVERGREEN_DIR:="$(native_path "$(dirname "${LIBMONGOCRYPT_DIR}")")"}"
: "${LIBMONGOCRYPT_BUILD_ROOT:="${BUILD_ROOT}/libmongocrypt"}"
: "${LIBMONGOCRYPT_INSTALL_ROOT:="${INSTALL_ROOT}/libmongocrypt"}"
: "${MONGO_C_DRIVER_DIR:="${BUILD_ROOT}/mongo-c-driver-src"}"
: "${MONGO_C_DRIVER_BUILD_DIR:="${BUILD_ROOT}/mongo-c-driver-bld"}"
: "${BSON_INSTALL_DIR:="${INSTALL_ROOT}/mongo-c-driver"}"

: "${DEFAULT_CMAKE_BUILD_TYPE:=RelWithDebInfo}"

# On Windows, we use a multi-conf CMake generator by default, which inserts a
# directory over build artifacts qualified by the CMake configuration type
if test "${OS_NAME}" = "windows"; then
    : "${BUILD_DIR_INFIX:="${DEFAULT_CMAKE_BUILD_TYPE}"}"
else
    : "${BUILD_DIR_INFIX:="."}"
fi

# Find (or get) a CMake executable for the build
function get_cmake_exe() {
    # Based on find-cmake.sh from the mongo-c-driver
    set -eu

    local _found
    local _version="3.11.0"

    # Check if on macOS with arm64. Use system cmake. See BUILD-14565.
    local _march=$(uname -m | tr '[:upper:]' '[:lower:]')
    if [ "darwin" = "$OS_NAME" -a "arm64" = "$_march" ]; then
        debug "Using system's CMake"
        echo "cmake"  # Just use the one on the PATH
        return 0
    fi

    if [ ! -z "${CMAKE:-}" ]; then
        # Use the one in the environment
        debug "Using environment \$CMAKE: [$CMAKE]"
        _found="$CMAKE"
    elif [ -f "/Applications/cmake-3.2.2-Darwin-x86_64/CMake.app/Contents/bin/cmake" ]; then
        _found="/Applications/cmake-3.2.2-Darwin-x86_64/CMake.app/Contents/bin/cmake"
    elif [ -f "/Applications/Cmake.app/Contents/bin/cmake" ]; then
        _found="/Applications/Cmake.app/Contents/bin/cmake"
    elif [ -f "/opt/cmake/bin/cmake" ]; then
        _found="/opt/cmake/bin/cmake"
    elif [ "${OS_NAME}" = "windows" ] && have_command cmake; then
        _found=cmake
    elif [ -f "/cygdrive/c/cmake/bin/cmake" ]; then
        _found="$(native_path /cygdrive/c/cmake/bin/cmake)"
    elif uname -a | grep -iq 'x86_64 GNU/Linux'; then
        local _expect="${BUILD_ROOT}/cmake-${_version}/bin/cmake"
        if ! test -f "${_expect}"; then
            debug "Downloading CMake binaries for Linux"
            curl --retry 5 "https://cmake.org/files/v3.11/cmake-${_version}-Linux-x86_64.tar.gz" -sS --max-time 120 --fail --output cmake.tar.gz
            mkdir "${BUILD_ROOT}/cmake-${_version}"
            tar xzf cmake.tar.gz -C "${BUILD_ROOT}/cmake-${_version}" --strip-components=1
        fi
        _found="${_expect}"
    elif [ -z "${CMAKE:-}" -o -z "$( ${CMAKE:-} --version 2>/dev/null )" ]; then
        # Some images have no cmake yet, or a broken cmake (see: BUILD-8570)
        CMAKE_INSTALL_DIR="${INSTALL_ROOT}/cmake-install"
        local _expect="${CMAKE_INSTALL_DIR}/bin/cmake"
        if ! test -f "$_expect"; then
            debug "Building CMake from source..."
            curl --retry 5 "https://cmake.org/files/v3.11/cmake-${_version}.tar.gz" -sS --max-time 120 --fail --output cmake.tar.gz
            tar xzf cmake.tar.gz
            run_chdir "cmake-${_version}" \
                ./bootstrap --prefix="${CMAKE_INSTALL_DIR}" 1>&2
            make -C "cmake-${_version}" -j8 1>&2
            make -C "cmake-${_version}" install 1>&2
            debug "CMake build finished"
        fi
        _found="${_expect}"
    fi

    debug "Using CMake: [${_found}]"
    echo "${_found}"
}

_CMAKE_BUILD_PY="${CI_DIR}/build.py"

function cmake_build_py() {
    set -eu
    local _cmake="$(get_cmake_exe)"
    if have_command py; then
        _py=py
    elif have_command python; then
        _py=python
    elif have_command python3; then
        _py=python3
    elif have_command python2; then
        _py=python2
    else
        fail "No 'python' is available to run the cmake_build_py script"
    fi
    debug "Running CMake configure/build/install process with args: ${@}"
    command "${_py}" -u "${_CMAKE_BUILD_PY}" --cmake="${_cmake}" "${@}"
}
