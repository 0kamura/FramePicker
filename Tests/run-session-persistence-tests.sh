#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/objc-tests"
module_cache="$build_dir/ModuleCache"
sample_video="$build_dir/session-sample.mp4"

mkdir -p "$build_dir" "$module_cache"

clang \
    -fobjc-arc \
    -fmodules \
    -fmodules-cache-path="$module_cache" \
    -target arm64-apple-macos14.0 \
    -o "$build_dir/make-session-sample-video" \
    "$project_dir/Tests/make-sample-video.m" \
    -framework AVFoundation \
    -framework Foundation

"$build_dir/make-session-sample-video" "$sample_video"

clang \
    -fobjc-arc \
    -fblocks \
    -fmodules \
    -fmodules-cache-path="$module_cache" \
    -target arm64-apple-macos14.0 \
    -I "$project_dir/Sources/FramePickerObjC" \
    -o "$build_dir/SessionPersistenceTests" \
    "$project_dir/Tests/SessionPersistenceTests.m" \
    "$project_dir/Sources/FramePickerObjC/LatestVideoRequest.m" \
    "$project_dir/Sources/FramePickerObjC/ClipboardEncoder.m" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework AVKit \
    -framework Photos \
    -framework UniformTypeIdentifiers

"$build_dir/SessionPersistenceTests" "$sample_video"
