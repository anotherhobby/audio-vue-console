#!/bin/sh
# Refreshes the render bundle from audio-vue's checkout, then copies it and the Python runtime into
# the app's resources: the app target's build phase "Embed the render runtime", run on every build
# (`render-runtime`, design D1a; `track-audio-vue` design D3), so a rebuild carries the card code the
# checkout holds now. AUDIO_VUE names the checkout, as for tools/refresh-render-bundle.sh.
set -eu

audio_vue=${AUDIO_VUE:-"$SRCROOT/../audio-vue"}
runtime="$SRCROOT/local/python-runtime"
bundle="$SRCROOT/local/render-bundle"
resources="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"

if ! "$SRCROOT/tools/refresh-render-bundle.sh"; then
    echo "error: Couldn't refresh the render bundle from audio-vue's checkout at $audio_vue. Check it builds its render bundle (make render-bundle), or set AUDIO_VUE to the checkout."
    exit 1
fi

if [ ! -x "$runtime/bin/python3" ] || [ ! -f "$bundle/manifest.json" ]; then
    echo "error: The render runtime is missing. Run tools/refresh-render-bundle.sh, then build again."
    exit 1
fi

rsync -a --delete "$runtime/" "$resources/python/"
rsync -a --delete --exclude __pycache__ "$bundle/" "$resources/render-bundle/"
