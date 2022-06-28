#!/bin/bash

# Initial variables and helper functions for the libmongocrypt build

## Variables set by this file:

# CI_DIR = The path to the directory containing this script file
# LIBMONGOCRYPT_DIR = The path to the libmongocrypt source directory
# OS_NAME = One of 'windows', 'linux', 'macos', or 'unknown'

## Variables set by this file that may be overridden:

# EVERGREEN_DIR = The evergreen workspace directory.
#       Default is the parent of LIBMONGOCRYPT_DIR
# LIBMONGOCRYPT_BUILD_ROOT = Prefix for all build results of libmongocrypt.
#       Further subdirectories will be created for different build variants.
#       Default is ${LIBMONGOCRYPT_DIR}/_build
# LIBMONGOCRYPT_INSTALL_ROOT = Scratch directory where libmongocrypt variants
#       will be installed. Default is ${LIBMONGOCRYPT_DIR}/_install

## (All of the above directory paths are absolute paths)

## This script defines the following commands:

# * abspath <path>
#       Convert a given path into an absolute path. Relative paths are
#       resolved relative to the working directory.
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

# Join the given arguments with the given joiner string. Writes to stdout
# Usage: join_str <joiner> [argv [...]]
function join_str() {
    local joiner first
    joiner="$1"
    first="${2-}"
    if shift 2; then
        # Print each element. Do a string-replace of the beginning of each
        # subsequent string with the joiner.
        printf "%s" "$first" "${@/#/$joiner}"
    fi
}

OS_NAME="$(os_name)"

_init_sh_this_file="$(abspath "${BASH_SOURCE[0]}")"
_init_sh_ci_dir="$(dirname "${_init_sh_this_file}")"

# Get the CI dir as a native absolute path. All other path vars are derived from
# this one, and will therefore remain as native paths
CI_DIR="$(native_path "${_init_sh_ci_dir}")"
LIBMONGOCRYPT_DIR="$(dirname "${CI_DIR}")"

: "${EVERGREEN_DIR:="$(native_path "$(dirname "${LIBMONGOCRYPT_DIR}")")"}"
: "${LIBMONGOCRYPT_BUILD_ROOT:="${LIBMONGOCRYPT_DIR}/_build"}"
: "${LIBMONGOCRYPT_INSTALL_ROOT:="${LIBMONGOCRYPT_DIR}/_install"}"
