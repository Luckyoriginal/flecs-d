#!/usr/bin/env bash
set -euo pipefail

mkdir -p bin

echo "==> [1/3] Building and running basics.d..."
ldc2 -betterC -O2 -Isource \
    -L-L/usr/local/lib64 \
    -L-rpath=/usr/local/lib64 \
    -L-lflecs \
    source/flecs/c.d \
    source/flecs/package.d \
    examples/basics.d \
    -of=bin/basics
./bin/basics

echo ""
echo "==> [2/3] Building and running core_features.d (full ECS test suite)..."
ldc2 -betterC -O2 -Isource \
    -L-L/usr/local/lib64 \
    -L-rpath=/usr/local/lib64 \
    -L-lflecs \
    source/flecs/c.d \
    source/flecs/package.d \
    examples/core_features.d \
    -of=bin/core_features
./bin/core_features

echo ""
echo "==> [3/3] Building and running DUB example project (examples/dub_example)..."
(cd examples/dub_example && dub run --compiler=ldc2)

echo ""
echo "==> All builds and tests passed successfully!"
