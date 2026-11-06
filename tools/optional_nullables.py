"""Writes a host contract's nullable fields as optional ones, for swift-openapi-generator.

The host's contract marks a nullable field as `anyOf` (or `oneOf`) of its types and
`{"type": "null"}`. That is correct OpenAPI 3.1, but the generator drops such a property whole.
It reads an optional property, and for a field that is not required, `anyOf [X, null]` means the
same as an optional `X`: a null and an absent key both read as nil, and a nil is sent as an absent
key, which the host reads as null. So each such union becomes its other types, and nothing else
changes (`host-client`, "The refresh writes nullable fields as optional"; design D9).

Where that would lose meaning, the contract is refused and nothing is written: a nullable property
or request body that is required, a null branch anywhere but in a property's or a request body's
schema, or a branch whose keys clash with the schema around it.

Reads the contract on stdin and writes it on stdout as audio-vue does: two-space JSON and a newline.
"""

import json
import sys

NULL = {"type": "null"}
UNIONS = ("anyOf", "oneOf")


class Refused(Exception):
    """A nullable field that cannot be written as optional without losing meaning."""


def rewrite(contract):
    """The contract with each nullable union written as its other types."""
    return _walk(contract, [])


def _walk(node, path, slot=None):
    """Rewrites `node`. `slot` says whether it is a property's or a request body's schema, which
    may be nullable: None where it is neither, else whether the property or body is required."""
    if isinstance(node, list):
        return [_walk(item, [*path, str(index)]) for index, item in enumerate(node)]
    if not isinstance(node, dict):
        return node
    if _union_key(node):
        node = _without_null(node, path, slot)
    return {key: _child(node, key, [*path, key]) for key in node}


def _child(node, key, path):
    """`node[key]` rewritten, knowing which of its schemas are properties or request bodies."""
    value = node[key]
    if key == "properties" and isinstance(value, dict):
        required = set(node.get("required", []))
        return {name: _walk(schema, [*path, name], name in required)
                for name, schema in value.items()}
    if key == "content" and path[-2:-1] == ["requestBody"]:
        required = node.get("required") is True
        return {media: _media(entry, [*path, media], required) for media, entry in value.items()}
    return _walk(value, path)


def _media(entry, path, required):
    """A request body's media entry, whose `schema` may be nullable."""
    return {key: _walk(value, [*path, key], required if key == "schema" else None)
            for key, value in entry.items()}


def _union_key(node):
    """The union key whose branches include null, or None."""
    return next((key for key in UNIONS if NULL in node.get(key, [])), None)


def _check_optional(slot, where):
    """Refuses a nullable schema that is not an optional property's or request body's."""
    if slot is None:
        raise Refused(f"{where}: null in a union that is not a property's or a request body's")
    if slot:
        raise Refused(f"{where}: a nullable field that is required cannot be written as optional")


def _without_null(node, path, slot):
    where = "/".join(path)
    _check_optional(slot, where)
    key = _union_key(node)
    rest = [branch for branch in node[key] if branch != NULL]
    if not rest:
        raise Refused(f"{where}: a union of null alone")
    if len(rest) > 1:
        return {name: (rest if name == key else value) for name, value in node.items()}
    return _merged(node, key, rest[0], where)


def _merged(node, key, branch, where):
    """`node` with its one-branch union replaced, in place, by that branch's keys."""
    clash = set(branch) & (set(node) - {key})
    if clash:
        raise Refused(f"{where}: the branch's {sorted(clash)} clash with the schema around it")
    merged = {}
    for name, value in node.items():
        if name == key:
            merged.update(branch)
        else:
            merged[name] = value
    return merged


def main():
    contract = json.load(sys.stdin)
    try:
        written = rewrite(contract)
    except Refused as refusal:
        print(f"Refused: {refusal}", file=sys.stderr)
        return 1
    sys.stdout.write(json.dumps(written, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
