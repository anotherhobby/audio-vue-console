#!/bin/sh
# Copies the Python runtime and the render bundle into the app's resources, the app target's build
# phase "Embed the render runtime" (`render-runtime`, design D1a). Both are built by
# tools/refresh-render-bundle.sh, which a build needs run first.
set -eu

runtime="$SRCROOT/local/python-runtime"
bundle="$SRCROOT/local/render-bundle"
resources="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"

if [ ! -x "$runtime/bin/python3" ] || [ ! -f "$bundle/manifest.json" ]; then
    echo "error: The render runtime is missing. Run tools/refresh-render-bundle.sh, then build again."
    exit 1
fi

rsync -a --delete "$runtime/" "$resources/python/"
rsync -a --delete --exclude __pycache__ "$bundle/" "$resources/render-bundle/"
