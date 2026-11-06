#!/bin/sh
# Refreshes the host contract the app's client is generated from, from audio-vue's code.
#
#   tools/refresh-contract.sh          regenerate audio-vue's contract and copy it over the saved one
#   tools/refresh-contract.sh --check  regenerate it and print how it differs from the saved one,
#                                      copying nothing; exits 1 on a difference
#
# The saved copy is never edited by hand (`host-client`). audio-vue's `make openapi` writes the
# contract from its code with no host, to `local/openapi.json`, and `optional_nullables.py` writes
# its nullable fields as optional ones, which the generator reads, refusing a contract where that
# would lose meaning; a refusal leaves the saved copy as it was (design D9).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
audio_vue=${AUDIO_VUE:-"$root/../audio-vue"}
saved="$root/ConsoleCore/Sources/HostAPI/openapi.json"
written="$audio_vue/local/openapi.json"

case "${1:-}" in
    "") mode=refresh ;;
    --check) mode=check ;;
    *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

make -s -C "$audio_vue" openapi >/dev/null
rewritten=$(mktemp)
trap 'rm -f "$rewritten"' EXIT
python3 -I "$root/tools/optional_nullables.py" <"$written" >"$rewritten"

if [ "$mode" = check ]; then
    if [ ! -f "$saved" ]; then
        echo "No saved contract at $saved" >&2
        exit 1
    fi
    if diff -u "$saved" "$rewritten"; then
        echo "The saved contract matches audio-vue's, as the refresh writes it."
    else
        exit 1
    fi
else
    mkdir -p "$(dirname "$saved")"
    cp "$rewritten" "$saved"
    echo "Saved audio-vue's contract to ${saved#"$root"/}."
fi
