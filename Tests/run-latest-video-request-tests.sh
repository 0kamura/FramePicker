#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/objc-tests"
module_cache="$build_dir/ModuleCache"

mkdir -p "$build_dir" "$module_cache"

clang \
    -fobjc-arc \
    -fblocks \
    -fmodules \
    -fmodules-cache-path="$module_cache" \
    -target arm64-apple-macos14.0 \
    -I "$project_dir/Sources/FramePickerObjC" \
    -o "$build_dir/LatestVideoRequestTests" \
    "$project_dir/Tests/LatestVideoRequestTests.m" \
    "$project_dir/Sources/FramePickerObjC/LatestVideoRequest.m" \
    -framework Foundation \
    -framework AVFoundation \
    -framework Photos

"$build_dir/LatestVideoRequestTests"
