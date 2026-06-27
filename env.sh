export PATH="$HOME/local/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/deps/ffmpeg-shims:/usr/lib/amd64:${LD_LIBRARY_PATH:-}"
export OPENMW_RESOURCE_FILES="$HOME/build/resources"

# Solaris libc allocator fail, use mimalloc
export LD_PRELOAD="/usr/lib/libmimalloc.so${LD_PRELOAD:+:$LD_PRELOAD}"
