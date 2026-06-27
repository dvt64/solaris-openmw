#!/usr/bin/env bash
# Build collada-dom + OpenMW/osg osgdb_dae plugin for IPS OpenSceneGraph 3.6.5.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/deps"
PATCHES="$ROOT/patches"
OSG_PLUGINS="$DEPS/osg-plugins/osgPlugins-3.6.5"
export PATH="${HOME}/local/bin:${PATH}"

"$PATCHES/apply-patches.sh" >/dev/null

CD="$DEPS/collada-dom"
OSG="$DEPS/osg"
OSG_BUILD="$OSG/build"

# collada-dom static libs for FindCOLLADA
mkdir -p "$CD/lib"
ln -sf "$CD/build/dom/src/1.5/libcolladadom150.a" "$CD/lib/libcollada14dom.a" 2>/dev/null || true
ln -sf "$CD/build/dom/external-libs/minizip-1.1/libminizip.a" "$CD/lib/libminizip.a" 2>/dev/null || true

if [ ! -f "$CD/build/dom/src/1.5/libcolladadom150.a" ]; then
  mkdir -p "$CD/build"
  cd "$CD/build"
  cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH=/usr/lib/amd64/cmake \
    -DBoost_DIR=/usr/lib/amd64/cmake/Boost-1.78.0 \
    -Dboost_filesystem_DIR=/usr/lib/amd64/cmake/boost_filesystem-1.78.0 \
    -Dboost_system_DIR=/usr/lib/amd64/cmake/boost_system-1.78.0 \
    -DCMAKE_INSTALL_PREFIX="$DEPS/collada-dom-install" \
    -DBUILD_SHARED_LIBS=ON \
    ..
  gmake -j"$(psrinfo | wc -l)" colladadom150 minizip
  ln -sf "$CD/build/dom/src/1.5/libcolladadom150.a" "$CD/lib/libcollada14dom.a"
  ln -sf "$CD/build/dom/external-libs/minizip-1.1/libminizip.a" "$CD/lib/libminizip.a"
fi

export COLLADA_DIR="$CD"
mkdir -p "$OSG_BUILD"
cd "$OSG_BUILD"
if [ ! -f osgdb_dae.so ] && [ ! -f lib/osgPlugins-3.6.5/osgdb_dae.so ]; then
  rm -f CMakeCache.txt
  cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH=/usr/lib/amd64/cmake \
    -DBoost_DIR=/usr/lib/amd64/cmake/Boost-1.78.0 \
    -DCOLLADA_MINIZIP_LIBRARY="$CD/lib/libminizip.a" \
    -DCOLLADA_BOOST_FILESYSTEM_LIBRARY=/usr/lib/amd64/libboost_filesystem.so \
    -DCOLLADA_BOOST_SYSTEM_LIBRARY=/usr/lib/amd64/libboost_system.so \
    -DCOLLADA_PCRECPP_LIBRARY=/usr/lib/amd64/libpcrecpp.so \
    -DCOLLADA_PCRE_LIBRARY=/usr/lib/amd64/libpcre.so \
    -DCOLLADA_ZLIB_LIBRARY=/usr/lib/amd64/libz.so \
    -DCOLLADA_DYNAMIC_LIBRARY="$CD/lib/libcollada14dom.a" \
    -DCOLLADA_STATIC_LIBRARY="$CD/lib/libcollada14dom.a" \
    -DCOLLADA_INCLUDE_DIR="$CD/dom/include" \
    -DBUILD_OSG_APPLICATIONS=OFF \
    -DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF \
    -DBUILD_OSG_PLUGIN_DAE=ON \
    -DBUILD_SHARED_LIBS=ON \
    ..
  gmake -j"$(psrinfo | wc -l)" osgdb_dae
fi

mkdir -p "$OSG_PLUGINS"
SO=$(find "$OSG_BUILD" -name osgdb_dae.so | head -1)
cp "$SO" "$OSG_PLUGINS/"
echo "Installed: $OSG_PLUGINS/osgdb_dae.so"
ls -lh "$OSG_PLUGINS/osgdb_dae.so"
