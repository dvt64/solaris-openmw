#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/deps"
SRC="$DEPS/unshield"
INSTALL="$DEPS/unshield-install"
PATCHES="$ROOT/patches"

export PATH="${HOME}/local/bin:${PATH}"

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 --branch 1.6.2 https://github.com/twogood/unshield.git "$SRC"
fi

cd "$SRC"
git checkout -- lib/CMakeLists.txt 2>/dev/null || true
patch -p1 -N < "$PATCHES/unshield-static-md5.patch"

rm -rf build
mkdir -p build && cd build

cmake -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_STATIC=ON \
  -DUSE_OUR_OWN_MD5=ON \
  -DBUILD_TESTING=OFF \
  -DCMAKE_INSTALL_PREFIX="$INSTALL" \
  ..

# Only the static library is needed for openmw-wizard (CLI fails on illumos iconv)
gmake -j"$(psrinfo | wc -l)" libunshield

mkdir -p "$INSTALL/lib/pkgconfig" "$INSTALL/include"
cp lib/libunshield.a "$INSTALL/lib/"
cp ../lib/libunshield.h "$INSTALL/include/"
sed "s|@CMAKE_INSTALL_PREFIX@|$INSTALL|g; s|@PROJECT_VERSION@|1.6.2|g" \
  ../libunshield.pc.in > "$INSTALL/lib/pkgconfig/libunshield.pc"

if ! nm "$INSTALL/lib/libunshield.a" 2>/dev/null | grep MD5Init >/dev/null; then
  echo "ERROR: MD5 symbols missing from libunshield.a" >&2
  exit 1
fi

echo "Installed: $INSTALL/lib/libunshield.a"
