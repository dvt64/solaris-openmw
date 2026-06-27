#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/deps"
export PATH="${HOME}/local/bin:${PATH}"

if [ ! -d "$DEPS/mygui/.git" ]; then
  git clone --depth 1 --branch MyGUI3.4.3 https://github.com/MyGUI/mygui.git "$DEPS/mygui"
fi

mkdir -p "$DEPS/mygui/build"
cd "$DEPS/mygui/build"

cmake -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX="$DEPS/mygui-install" \
  -DMYGUI_RENDERSYSTEM=1 \
  -DMYGUI_BUILD_DEMOS=OFF \
  -DMYGUI_BUILD_TOOLS=OFF \
  -DMYGUI_BUILD_PLUGINS=OFF \
  -DMYGUI_DONT_USE_OBSOLETE=ON \
  ..

gmake -j"$(psrinfo | wc -l)"
gmake install
echo "MyGUI installed to $DEPS/mygui-install"
