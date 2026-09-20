#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$DIR/libflecs.a" ]; then
    echo "==> Compiling vendored Flecs C library ($DIR/flecs.c)..."
    CC="${CC:-gcc}"
    $CC -c -O3 -fPIC "$DIR/flecs.c" -I "$DIR" -o "$DIR/flecs.o"
    ar rcs "$DIR/libflecs.a" "$DIR/flecs.o"
    rm -f "$DIR/flecs.o"
    echo "==> Built $DIR/libflecs.a successfully."
fi
