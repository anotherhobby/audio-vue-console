#!/bin/sh
# Refreshes what the app carries to draw scenes, from audio-vue's checkout (`render-runtime`).
#
#   tools/refresh-render-bundle.sh          mirror audio-vue's render bundle into local/render-bundle/,
#                                           then build local/python-runtime/ if it is out of date
#   tools/refresh-render-bundle.sh --check  regenerate audio-vue's bundle and list how the mirror
#                                           differs, copying nothing; exits 1 on a difference
#
# audio-vue's `make render-bundle` writes `local/render-bundle/`: the card code and analysis at their
# repository paths, `manifest.json` and `requirements.txt`. local/render-bundle/ is its mirror, never
# edited by hand. local/python-runtime/ is a relocatable CPython, the version the checkout's .venv
# runs, fetched by uv, with requirements.txt installed into it, rebuilt only when that version or the
# requirements change. Neither is committed: both come from the checkout, which a build needs anyway,
# and audio-vue's code is held to audio-vue's checks, not this repository's. AUDIO_VUE names the
# checkout.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
audio_vue=${AUDIO_VUE:-"$root/../audio-vue"}
written="$audio_vue/local/render-bundle"
mirror="$root/local/render-bundle"
runtime="$root/local/python-runtime"
downloads="$root/local/python-downloads"

case "${1:-}" in
    "") mode=refresh ;;
    --check) mode=check ;;
    *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

make -s -C "$audio_vue" render-bundle >/dev/null

if [ "$mode" = check ]; then
    if diff -rq --exclude=__pycache__ "$written" "$mirror"; then
        echo "The render bundle matches audio-vue's."
        exit 0
    fi
    exit 1
fi

mkdir -p "$mirror"
rsync -a --delete --exclude __pycache__ "$written/" "$mirror/"
echo "Mirrored audio-vue's render bundle to ${mirror#"$root"/}."

# The runtime: the interpreter audio-vue's tests run the bundle under, with its pinned libraries.
version=$("$audio_vue/.venv/bin/python" -c 'import platform; print(platform.python_version())')
stamp="$version $(shasum -a 256 "$mirror/requirements.txt" | cut -d' ' -f1)"
if [ -f "$runtime/.stamp" ] && [ "$(cat "$runtime/.stamp")" = "$stamp" ]; then
    echo "The Python runtime is current ($version)."
    exit 0
fi

mkdir -p "$downloads"
UV_PYTHON_INSTALL_DIR="$downloads" uv python install --quiet "$version"
fetched=$(find "$downloads" -maxdepth 1 -type d -name "cpython-$version-macos-*" | head -n 1)
if [ -z "$fetched" ]; then
    echo "uv installed no CPython $version under $downloads" >&2
    exit 1
fi

building="$runtime.building"
rm -rf "$building"
cp -R "$fetched" "$building"
# Every distribution must match one of the hashes audio-vue's uv.lock gives it.
uv pip install --quiet --python "$building/bin/python3" --system --break-system-packages \
    --require-hashes -r "$mirror/requirements.txt"
find "$building" -type d -name __pycache__ -prune -exec rm -rf {} +
echo "$stamp" >"$building/.stamp"
rm -rf "$runtime"
mv "$building" "$runtime"
echo "Built the Python runtime ($version) in ${runtime#"$root"/}."
