#!/bin/sh
# Builds audio-vue's cal-play from its checkout and copies it into the app as a helper: the app
# target's build phase "Build and embed cal-play" (`calibration-player`, design D1), run on every
# build so cargo decides what changed. AUDIO_VUE names the checkout, CARGO the cargo to use.
set -eu

audio_vue=${AUDIO_VUE:-"$SRCROOT/../audio-vue"}
cargo=${CARGO:-"$HOME/.cargo/bin/cargo"}
target="$SRCROOT/local/cal-play-target"
helpers="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers"

if [ ! -f "$audio_vue/cal-play/Cargo.toml" ]; then
    echo "error: cal-play's sources are missing at $audio_vue/cal-play. Check out audio-vue beside this repository, or set AUDIO_VUE to the checkout."
    exit 1
fi

if [ ! -x "$cargo" ]; then
    echo "error: cal-play needs Rust to build, and no cargo was found at $cargo. Install it from https://rustup.rs, or set CARGO to its path."
    exit 1
fi

"$cargo" build --release --quiet --manifest-path "$audio_vue/cal-play/Cargo.toml" --target-dir "$target"
mkdir -p "$helpers"
cp "$target/release/cal-play" "$helpers/cal-play"
