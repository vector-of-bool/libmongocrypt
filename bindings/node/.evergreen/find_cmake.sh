#!/usr/bin/env bash

# Copied from the mongo-c-driver
find_cmake ()
{
  # Check if on macOS with arm64. Use system cmake. See BUILD-14565.
  OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
  MARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
  if [ "darwin" = "$OS_NAME" -a "arm64" = "$MARCH" ]; then
      CMAKE=cmake
      return 0
  fi

  _get_version=3.22.2

  if [ ! -z "$CMAKE" ]; then
    return 0
  elif [ -f "/Applications/cmake-3.2.2-Darwin-x86_64/CMake.app/Contents/bin/cmake" ]; then
    CMAKE="/Applications/cmake-3.2.2-Darwin-x86_64/CMake.app/Contents/bin/cmake"
  elif [ -f "/Applications/Cmake.app/Contents/bin/cmake" ]; then
    CMAKE="/Applications/Cmake.app/Contents/bin/cmake"
  elif [ -f "/opt/cmake/bin/cmake" ]; then
    CMAKE="/opt/cmake/bin/cmake"
  elif [ -z "$IGNORE_SYSTEM_CMAKE" ] && command -v cmake 2>/dev/null; then
     CMAKE=cmake
  elif uname -a | grep -iq 'x86_64 GNU/Linux'; then
    _prefix=$PWD/_cmake
    curl "https://github.com/Kitware/CMake/releases/download/v${_get_version}/cmake-${_get_version}-linux-x86_64.sh" \
        -sLo "$PWD/cmake.sh"
    mkdir -p "${_prefix}"
    sh "$PWD/cmake.sh" --exclude-subdir "--prefix=${_prefix}" --skip-license
    CMAKE="${_prefix}/bin/cmake"
  fi
  if [ -z "$CMAKE" -o -z "$( $CMAKE --version 2>/dev/null )" ]; then
     # Some images have no cmake yet, or a broken cmake (see: BUILD-8570)
     echo "-- MAKE CMAKE --"
     CMAKE_INSTALL_DIR=$(owd)/cmake-install
     curl --retry 5 https://github.com/Kitware/CMake/releases/download/v${_get_version}/cmake-${_get_version}.tar.gz -sS --max-time 120 --fail --output cmake.tar.gz
     tar xzf cmake.tar.gz
     cd cmake-${_get_version}
     ./bootstrap --prefix="${CMAKE_INSTALL_DIR}"
     make -j8
     make install
     cd ..
     CMAKE="${CMAKE_INSTALL_DIR}/bin/cmake"
     echo "-- DONE MAKING CMAKE --"
  fi
}

find_cmake

export CMAKE=$CMAKE
