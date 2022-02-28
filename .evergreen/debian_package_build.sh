#!/bin/sh

#
# Test mongocxx's Debian packaging scripts.
#
# Supported/used environment variables:
#   IS_PATCH    If "true", this is an Evergreen patch build.

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

on_exit () {
  if [ -e ./unstable-chroot/debootstrap/debootstrap.log ]; then
    echo "Dumping debootstrap.log"
    cat ./unstable-chroot/debootstrap/debootstrap.log
  fi
}
trap on_exit EXIT

_scratch_dir="${BUILD_ROOT}/deb"
export DEBOOTSTRAP_DIR="${_scratch_dir}/debootstrap.git"
_chroot="${_scratch_dir}/unstable-chroot"

if [ "${IS_PATCH:-}" = "true" ]; then
  _clean_clone="${_scratch_dir}/clean-clone"
  git clone "file://${LIBMONGOCRYPT_DIR}" "${_clean_clone}" --depth=1
  git -C "${_clean_clone}" diff HEAD -- . ':!debian' > "${_scratch_dir}/upstream.patch"
  git -C "${_clean_clone}" diff HEAD -- debian > "${_scratch_dir}/debian.patch"
  git -C "${_clean_clone}" clean -fdx
  git -C "${_clean_clone}" reset --hard HEAD
  if [ -s "${_scratch_dir}/upstream.patch" ]; then
    [ -d debian/patches ] || mkdir debian/patches
    mv "${_scratch_dir}/upstream.patch" debian/patches/
    echo upstream.patch >> debian/patches/series
    git add debian/patches/*
    git commit -m 'Evergreen patch build - upstream changes'
    git log -n1 -p
  fi
  if [ -s ../debian.patch ]; then
    git apply --index ../debian.patch
    git commit -m 'Evergreen patch build - Debian packaging changes'
    git log -n1 -p
  fi
fi


if ! test -d "${DEBOOTSTRAP_DIR}/.git"; then
  git clone https://salsa.debian.org/installer-team/debootstrap.git "${DEBOOTSTRAP_DIR}"
fi
git -C "${DEBOOTSTRAP_DIR}" pull
sudo -E "$DEBOOTSTRAP_DIR/debootstrap" unstable "${_chroot}/" http://cdn-aws.deb.debian.org/debian
cp -a "${LIBMONGOCRYPT_DIR}" "${_chroot}/tmp/"
sudo chroot "${_chroot}" /bin/bash -c "(set -o xtrace && \
  apt-get install -y build-essential git-buildpackage fakeroot debhelper cmake curl ca-certificates libssl-dev pkg-config libbson-dev && \
  cd /tmp/libmongocrypt && \
  git clean -fdx && \
  git reset --hard HEAD && \
  cmake -P ./cmake/GetVersion.cmake > VERSION_CURRENT 2>&1 && \
  git add --force VERSION_CURRENT && \
  git commit VERSION_CURRENT -m 'Set current version' && \
  LANG=C /bin/bash ./debian/build_snapshot.sh && \
  debc ../*.changes && \
  dpkg -i ../*.deb && \
  /usr/bin/gcc -I/usr/include/mongocrypt -I/usr/include/libbson-1.0 -o example-state-machine test/example-state-machine.c -lmongocrypt -lbson-1.0 )"

[ -e "${_chroot}/tmp/libmongocrypt/example-state-machine" ] || (echo "Example 'example-state-machine' was not built!" ; exit 1)
(cd "${_chroot}/tmp/" ; tar zcvf ../../deb.tar.gz *.dsc *.orig.tar.gz *.debian.tar.xz *.build *.deb)

