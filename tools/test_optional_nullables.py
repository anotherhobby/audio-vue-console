"""Tests for `optional_nullables`: run `python3 -I tools/test_optional_nullables.py`."""

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))

from optional_nullables import Refused, rewrite

NULL = {"type": "null"}


def schema(properties, required=()):
    """A contract with one object schema, `Probe`."""
    probe = {"type": "object", "properties": properties}
    if required:
        probe["required"] = list(required)
    return {"openapi": "3.1.0", "components": {"schemas": {"Probe": probe}}}


def probe(contract):
    return contract["components"]["schemas"]["Probe"]["properties"]


def refusal(contract):
    """The reason `rewrite` refuses `contract`, or None where it does not."""
    try:
        rewrite(contract)
    except Refused as refused:
        return str(refused)
    return None


def test_a_nullable_primitive_becomes_its_type():
    field = {"anyOf": [{"type": "integer"}, NULL], "title": "Width", "description": "Px."}
    written = probe(rewrite(schema({"width": field})))["width"]
    assert written == {"type": "integer", "title": "Width", "description": "Px."}


def test_the_branch_takes_the_unions_place_in_key_order():
    field = {"title": "Width", "anyOf": [{"type": "integer"}, NULL], "description": "Px."}
    written = probe(rewrite(schema({"width": field})))["width"]
    assert list(written) == ["title", "type", "description"]


def test_a_nullable_reference_becomes_the_reference():
    capture = {"$ref": "#/components/schemas/Capture"}
    field = {"anyOf": [capture, NULL]}
    assert probe(rewrite(schema({"capture": field})))["capture"] == capture


def test_one_of_is_rewritten_too():
    field = {"oneOf": [{"type": "string"}, NULL]}
    assert probe(rewrite(schema({"name": field})))["name"] == {"type": "string"}


def test_a_nullable_union_of_several_keeps_the_rest():
    rest = [{"type": "string"}, {"type": "number"}]
    field = {"anyOf": [*rest, NULL], "title": "Value"}
    assert probe(rewrite(schema({"value": field})))["value"] == {"anyOf": rest, "title": "Value"}


def test_a_nested_nullable_is_rewritten():
    inner = {"type": "object", "properties": {"rate": {"anyOf": [{"type": "number"}, NULL]}}}
    written = probe(rewrite(schema({"capture": inner})))["capture"]
    assert written["properties"]["rate"] == {"type": "number"}


def test_a_required_nullable_property_is_refused():
    field = {"anyOf": [{"type": "integer"}, NULL]}
    reason = refusal(schema({"width": field}, required=["width"]))
    assert reason is not None
    assert "Probe/properties/width" in reason
    assert "required" in reason


def test_an_optional_nullable_request_body_is_rewritten():
    start = {"$ref": "#/components/schemas/Start"}
    body = {"content": {"application/json": {"schema": {"anyOf": [start, NULL]}}}}
    contract = {"paths": {"/v1/panel/start": {"post": {"requestBody": body}}}}
    written = rewrite(contract)["paths"]["/v1/panel/start"]["post"]["requestBody"]
    assert written["content"]["application/json"]["schema"] == start


def test_a_required_nullable_request_body_is_refused():
    nullable = {"anyOf": [{"type": "string"}, NULL]}
    body = {"required": True, "content": {"application/json": {"schema": nullable}}}
    reason = refusal({"paths": {"/v1/x": {"post": {"requestBody": body}}}})
    assert reason is not None
    assert "required" in reason


def test_null_elsewhere_is_refused():
    items = {"type": "array", "items": {"anyOf": [{"type": "integer"}, NULL]}}
    reason = refusal(schema({"levels": items}))
    assert reason is not None
    assert "not a property's" in reason


def test_a_branch_clashing_with_its_schema_is_refused():
    field = {"anyOf": [{"type": "integer", "title": "A"}, NULL], "title": "B"}
    reason = refusal(schema({"width": field}))
    assert reason is not None
    assert "clash" in reason


def test_a_contract_with_no_nullable_is_unchanged_to_the_byte():
    contract = schema({"name": {"type": "string", "description": "é"}}, required=["name"])
    raw = json.dumps(contract, indent=2) + "\n"
    assert json.dumps(rewrite(json.loads(raw)), indent=2) + "\n" == raw


def main():
    tests = [test for name, test in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()
    print(f"{len(tests)} passed")


if __name__ == "__main__":
    main()
