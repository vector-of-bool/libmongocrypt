#!/bin/bash

# This script will configure, build, and install libmongocrypt, all in a single go.
# Usage:
#
#   turnkey-build-install.bash
#       [--source-dir <dirpath>]
#           Set the path to the source directory to build. Default is $LIBMONGOCRYPT_DIR
#       [--build-dir <dirpath>]
#           Set the path for ephemeral build results. Default is '$source_dir/cmake-build/'
#       [--install-dir <dirpath>]
#           Set the install prefix. Default is none (no install will be performed).
#       [-no-test]
#           Do not run CTest.
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
# This script does not provide any implicit configuration options to CMake.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

# We can't init to empty arrays, as very old bash versions will not appreciate that.
# We use two separate arrays to represent the args to CMake directly, or to the PowerShell script
cmake_settings=("_unused=_")
cmake_argv=("-D_unused=1")

no_test=false

while (($# > 0)); do
    case "$1" in
    --source-dir)
        shift
        source_dir="$1"
        shift
        ;;
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
        install_dir="$(native_path "$1")"
        shift
        ;;
    --no-test)
        no_test="true"
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
source_dir="${source_dir:-"$LIBMONGOCRYPT_DIR"}"
build_dir="${build_dir:-"$source_dir/cmake-build"}"
config="${config:-RelWithDebInfo}"

cmake="${CMAKE:-cmake}"

# Resolve the build directory path
build_dir="$(native_path "$(abspath "$build_dir")")"

log "Building [$config] into [$build_dir]"

if test "$OS_NAME" = "windows" && "${msvs:-${LOAD_VS_ENV:-false}}"; then
    # We're going to do something more fancy for msvs+Windows, and PowerShell is more suitable.
    # PowerShell concatenates everything after -Command as if it were typed on the CLI.
    # This might break for tricky command line arguments, but is stable for our purposes.
    install_dir="${install_dir:-"''"}"  # (We need a special string to indicate 'empty' (PowerShell bug))
    set -x
    powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Unrestricted \
        -Command "$CI_DIR/quick-build-msvc.ps1" \
            -SourceDir "$(native_path "$source_dir")" \
            -BuildDir "$(native_path "$build_dir")" \
            -InstallDir "$install_dir" \
            -Config "$config" \
            -VSVersion "${vs_version:-*}" \
            -TargetArch "${arch:-amd64}" \
            -SkipTests:"\$$no_test" \
            -Settings "$(join_str ", " "${cmake_settings[@]}")"
else
    if have_command ninja || have_command ninja-build; then
        cmake_argv+=(-GNinja)
    else
        if test -f /proc/cpuinfo; then
            jobs="$(grep -c '^processor' /proc/cpuinfo)"
            if have_command bc; then
                jobs="$(echo "$jobs+2" | bc)"
            fi
            export MAKEFLAGS="-j$jobs ${MAKEFLAGS-}"
        else
            export MAKEFLAGS="-j8 ${MAKEFLAGS-}"
        fi
    fi
    $cmake -DCMAKE_BUILD_TYPE="$config" \
           -DCMAKE_INSTALL_PREFIX="${install_dir-}" \
           "${cmake_argv[@]}" \
           "-B$build_dir" \
           "-H$source_dir"
    $cmake --build "$build_dir" --config "$config"
    if ! $no_test; then
        env CTEST_OUTPUT_ON_FAILURE=1 \
            $cmake --build "$build_dir" --config "$config" --target test
    fi
    if ! test -z "${install_dir-}"; then
        $cmake -D CMAKE_INSTALL_CONFIG_NAME="$config" -P "$build_dir/cmake_install.cmake"
    fi
fi
