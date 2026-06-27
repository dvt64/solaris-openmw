#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build}"
SRC="$ROOT"
DEPS="$ROOT/deps"
MYGUI_INSTALL="$DEPS/mygui-install"
UNSHIELD_INSTALL="$DEPS/unshield-install"
SHIMS="$DEPS/ffmpeg-shims"
PATCHES="$ROOT/patches"

OSG_COMMIT=01cc2b585c8456a4ff843066b7e1a8715558289f
COLLADA_TAG=v2.5.0

export PATH="${HOME}/local/bin:${PATH}"

apply_git_patch() {
  local repo="$1" patch="$2" label="$3"
  if [ ! -d "$repo/.git" ]; then
    echo "error: git repo not found: $repo ($label)" >&2
    exit 1
  fi
  cd "$repo"
  if git apply --reverse --check "$patch" 2>/dev/null; then
    echo "already applied: $(basename "$patch") -> $label"
    return 0
  fi
  git apply --check "$patch"
  git apply "$patch"
  echo "applied: $(basename "$patch") -> $label"
}

if [ ! -d "$MYGUI_INSTALL/lib/cmake/MyGUI" ]; then
  "$PATCHES/build-mygui.sh"
fi

if [ ! -f "$UNSHIELD_INSTALL/lib/libunshield.a" ]; then
  "$PATCHES/build-unshield.sh"
fi

echo "==> deps: OpenMW/osg (osgdb_dae plugin)"
if [ ! -d "$DEPS/osg/.git" ]; then
  git clone https://github.com/OpenMW/osg.git "$DEPS/osg"
  git -C "$DEPS/osg" checkout "$OSG_COMMIT"
fi
apply_git_patch "$DEPS/osg" "$PATCHES/osg-dae-plugin.patch" "osg"

echo "==> deps: collada-dom (minizip / zlib 1.3)"
if [ ! -d "$DEPS/collada-dom/.git" ]; then
  git clone --depth 1 --branch "$COLLADA_TAG" https://github.com/rdiankov/collada-dom.git "$DEPS/collada-dom" || \
    git clone https://github.com/rdiankov/collada-dom.git "$DEPS/collada-dom"
  git -C "$DEPS/collada-dom" checkout "$COLLADA_TAG" 2>/dev/null || true
fi
cd "$DEPS/collada-dom"
COLLADA_ZIP="dom/external-libs/minizip-1.1/zip.c"
if grep -q "(const unsigned long \\*)get_crc_table()" "$COLLADA_ZIP" 2>/dev/null; then
  echo "already applied: collada-dom-minizip.patch"
else
  patch -p1 -N < "$PATCHES/collada-dom-minizip.patch"
  echo "applied: collada-dom-minizip.patch -> collada-dom"
fi

"$PATCHES/build-osg-dae.sh"

mkdir -p "$SHIMS"
ln -sf /usr/lib/amd64/libvpx.so.12.0.0 "$SHIMS/libvpx.so.8"
ln -sf /usr/lib/amd64/libtheoradec.so.2.1.1 "$SHIMS/libtheoradec.so.1"
ln -sf /usr/lib/amd64/libtheoraenc.so.2.2.1 "$SHIMS/libtheoraenc.so.1"
ln -sf /usr/lib/amd64/librtmp.so.1 "$SHIMS/librtmp.so.0"

if [ ! -d "$DEPS/recastnavigation/.git" ]; then
  git clone https://github.com/OpenMW/recastnavigation.git "$DEPS/recastnavigation"
  git -C "$DEPS/recastnavigation" checkout 03259f3287ff8330f0d66fcd98d022edddffaa97
fi

if [ ! -d "$DEPS/bullet3/.git" ]; then
  git clone --depth 1 --branch 3.17 https://github.com/bulletphysics/bullet3.git "$DEPS/bullet3"
fi

mkdir -p "$BUILD"
cd "$BUILD"

cmake -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_PREFIX_PATH="$MYGUI_INSTALL;$UNSHIELD_INSTALL;/usr/lib/qt/6.10/lib/amd64/cmake/Qt6;/usr/lib/amd64/cmake" \
  -DBoost_DIR=/usr/lib/amd64/cmake/Boost-1.78.0 \
  -Dboost_iostreams_DIR=/usr/lib/amd64/cmake/boost_iostreams-1.78.0 \
  -Dboost_program_options_DIR=/usr/lib/amd64/cmake/boost_program_options-1.78.0 \
  -DMyGUI_DIR="$MYGUI_INSTALL/lib/cmake/MyGUI" \
  -Dyaml-cpp_DIR=/usr/lib/amd64/cmake/yaml-cpp \
  -DFETCHCONTENT_SOURCE_DIR_RECASTNAVIGATION="$DEPS/recastnavigation" \
  -DFETCHCONTENT_SOURCE_DIR_BULLET="$DEPS/bullet3" \
  -DOPENMW_USE_SYSTEM_BULLET=OFF \
  -DBUILD_LAUNCHER=OFF \
  -DBUILD_OPENCS=OFF \
  -DBUILD_WIZARD=ON \
  -DPKG_CONFIG_PATH="$UNSHIELD_INSTALL/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
  -DCMAKE_LIBRARY_PATH="/usr/lib/amd64;$SHIMS" \
  -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib/amd64 -L$SHIMS -R/usr/lib/amd64 -R$SHIMS" \
  -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib/amd64 -L$SHIMS" \
  "$SRC"

gmake -j"$(psrinfo | wc -l)"

echo
echo "Binary: $BUILD/openmw"
ls -lh "$BUILD/openmw"
echo "Run: $ROOT/run-openmw.sh"
if [ -f "$BUILD/openmw-wizard" ]; then
  echo "Wizard: $BUILD/openmw-wizard"
  ls -lh "$BUILD/openmw-wizard"
  echo "Run wizard: $ROOT/run-wizard.sh"
fi
