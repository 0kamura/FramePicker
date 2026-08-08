#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/dist/FramePicker.app"
build_dir="$project_dir/.build/objc"
module_cache="$project_dir/.build/objc/ModuleCache"

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$build_dir" "$module_cache"

clang \
    -fobjc-arc \
    -fblocks \
    -fmodules \
    -fmodules-cache-path="$module_cache" \
    -O2 \
    -target arm64-apple-macos14.0 \
    -o "$build_dir/FramePicker" \
    "$project_dir/Sources/FramePickerObjC/main.m" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework AVKit \
    -framework Photos \
    -framework UniformTypeIdentifiers

cp "$build_dir/FramePicker" "$app_dir/Contents/MacOS/FramePicker"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - \
    --requirements '=designated => identifier "com.0kamura.FramePicker"' \
    "$app_dir"

echo "$app_dir"
