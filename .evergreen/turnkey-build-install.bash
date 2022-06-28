#!/bin/bash

# This script will configure, build, and install libmongocrypt, all in a single go.
# Usage:
#
#   turnkey-build-install.bash
#       [--build-dir <dirpath>]
#           Set the path for ephemeral build results. Default is '_build/'
#       [--install-dir <dirpath>]
#           Set the install prefix. Default is '_install/'
#       [--config {RelWithDebInfo,Debug,Release}]
#           Set the CMake configuration to build. Default is 'RelWithDebInfo'
#       [--msvs]
#           Load the VS environment for the build.
#       [--msvs-version <version-pattern>]
#           Set the VS version to try and load. Supports wildcards. Default is '*'
#       [--msvs-target-arch {amd64,x86}]
#           Set the VS target architecture. Default is 'amd64'
#       [-D <key=val> [-D ...]]
#           Specify CMake '-D' options. Can be provided multiple times.
#

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

# We can't init to empty arrays, as very old bash versions will not appreciate that.
# We use two separate arrays to represent the args to CMake directly, or to the PowerShell script
cmake_settings=("_unused=_")
cmake_argv=("-D_unused=1")

while (($# > 0)); do
    case "$1" in
    --build-dir)
        shift
        build_dir="$1"
        shift
        ;;
    --config)
        shift
        config="$1"
        shift
        ;;
    --install-dir)
        shift
        install_dir="$1"
        shift
        ;;
    --msvs)
        msvs="true"
        shift
        ;;
    --msvs-target-arch)
        shift
        arch="$1"
        shift
        ;;
    --msvs-version)
        shift
        vs_version="$1"
        shift
        ;;
    -D)
        shift
        cmake_settings+=("$1")
        cmake_argv+=("-D$1")
        shift
        ;;
    *)
        fail "Unknown argument '$1'"
        ;;
    esac
done

# Defaults:
build_dir="${build_dir:-"$LIBMONGOCRYPT_BUILD_ROOT"}"
config="${config:-RelWithDebInfo}"
install_dir="${install_dir:-"$LIBMONGOCRYPT_INSTALL_ROOT"}"

cmake="${CMAKE:-cmake}"

# Resolve the build directory path
build_dir="$(native_path "$(abspath "$build_dir")")"

log "Building [$config] into [$build_dir]"

if test "$OS_NAME" = "windows" && "${msvs:-${LOAD_VS_ENV:-false}}"; then
    # We're going to do something more fancy for msvs+Windows, and PowerShell is more suitable.
    # PowerShell concatenates everything after -Command as if it were typed on the CLI.
    # This might break for tricky command line arguments, but is stable for our purposes.
    powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Unrestricted \
        -Command "$CI_DIR/quick-build-msvc.ps1" \
            -Config "$config" \
            -BuildDir "$build_dir" \
            -InstallDir "$install_dir" \
            -TargetArch "${arch:-amd64}" \
            -VSVersion "${vs_version:-*}" \
            -Settings "$(join_str ", " "${cmake_settings[@]}")"
else
    if have_command ninja || have_command ninja-build; then
        cmake_argv+=(-GNinja)
    fi
    $cmake -DCMAKE_BUILD_TYPE="$config" \
           -DCMAKE_INSTALL_PREFIX="$install_dir" \
           "${cmake_argv[@]}" \
           "-B$build_dir" \
           "-H$LIBMONGOCRYPT_DIR"
    $cmake --build "$build_dir" --config "$config"
    $cmake --build "$build_dir" --config "$config" --target test
    $cmake --install "$build_dir" --config "$config"
fi
