#!/bin/sh
# Build runner_near_core for all Apple platforms and assemble
# Frameworks/RunnerNearCoreFFI.xcframework + generated Swift bindings.
# Re-run after any change under rust/. Outputs are checked in so
# `swift test` needs no Rust toolchain.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRATE="$ROOT/rust/runner-near-core"
OUT="$ROOT/Frameworks/RunnerNearCoreFFI.xcframework"
GEN="$ROOT/Sources/RunnerNearCore"
BUILD="$CRATE/target/xc"

export PATH="$HOME/.cargo/bin:$PATH"
# Match the Swift package floors so linked objects agree on availability.
export MACOSX_DEPLOYMENT_TARGET=15.0
export IPHONEOS_DEPLOYMENT_TARGET=26.0

build() {
  echo "-> cargo build --release --target $1"
  (cd "$CRATE" && cargo build --release --target "$1")
}

build aarch64-apple-darwin
build x86_64-apple-darwin
build aarch64-apple-ios
build aarch64-apple-ios-sim
build x86_64-apple-ios

LIBNAME="librunner_near_core.a"
MACOS_UNIVERSAL="$BUILD/macos-universal"
SIM_UNIVERSAL="$BUILD/ios-sim-universal"
HEADERS="$BUILD/headers"

mkdir -p "$MACOS_UNIVERSAL" "$SIM_UNIVERSAL" "$HEADERS"
lipo -create \
  "$CRATE/target/aarch64-apple-darwin/release/$LIBNAME" \
  "$CRATE/target/x86_64-apple-darwin/release/$LIBNAME" \
  -output "$MACOS_UNIVERSAL/$LIBNAME"
lipo -create \
  "$CRATE/target/aarch64-apple-ios-sim/release/$LIBNAME" \
  "$CRATE/target/x86_64-apple-ios/release/$LIBNAME" \
  -output "$SIM_UNIVERSAL/$LIBNAME"

GENTMP="$BUILD/uniffi"
rm -rf "$GENTMP"
mkdir -p "$GENTMP"
(cd "$CRATE" && uniffi-bindgen-swift --swift-sources \
  "target/aarch64-apple-darwin/release/$LIBNAME" "$GENTMP")
(cd "$CRATE" && uniffi-bindgen-swift --headers \
  "target/aarch64-apple-darwin/release/$LIBNAME" "$GENTMP")
(cd "$CRATE" && uniffi-bindgen-swift --modulemap --xcframework \
  --module-name runner_near_coreFFI \
  "target/aarch64-apple-darwin/release/$LIBNAME" "$GENTMP")
rm -f "$GEN"/runner_near_core*.swift
cp "$GENTMP"/*.swift "$GEN/"
cp "$GENTMP"/*.h "$HEADERS/"
MODMAP="$(ls "$GENTMP"/*.modulemap | head -1)"
cp "$MODMAP" "$HEADERS/module.modulemap"
sed -i '' 's/^framework module /module /' "$HEADERS/module.modulemap"

rm -rf "$OUT"
xcodebuild -create-xcframework \
  -library "$CRATE/target/aarch64-apple-ios/release/$LIBNAME" -headers "$HEADERS" \
  -library "$SIM_UNIVERSAL/$LIBNAME" -headers "$HEADERS" \
  -library "$MACOS_UNIVERSAL/$LIBNAME" -headers "$HEADERS" \
  -output "$OUT"

du -sh "$OUT"
echo OK
