extends TestCase
## CanonicalJson (05 §3.3 Nr. 9, §11.4): key order, integer formatting, nested arrays, Unicode / control character
## escapes, "/" unescaped, non-integral numbers → error, stable JSON.parse round trip; fixed SHA-256 reference values
## shared with the Python/JS/Go implementations (tests/fixtures/live/canonical_vectors.json).

const VECTORS: String = "res://tests/fixtures/live/canonical_vectors.json"


func _vectors() -> Dictionary:
	var raw: Variant = JsonUtil.read_file(VECTORS)
	if not (raw is Dictionary):
		fail("canonical_vectors.json does not parse")
		return {}
	return raw


func test_shared_reference_vectors() -> void:
	var d: Dictionary = _vectors()
	var vectors: Array = d.get("vectors", [])
	assert_gt(vectors.size(), 8, "reference vectors present")
	for v: Variant in vectors:
		var vd: Dictionary = v
		var name: String = str(vd["name"])
		assert_eq(CanonicalJson.stringify(vd["input"]), str(vd["canonical"]), name)
		assert_eq(CanonicalJson.last_error, "", name + ": no error")
		assert_eq(CanonicalJson.sha256_hex(vd["input"]), str(vd["sha256"]), name + ": SHA-256 = reference")


func test_shared_error_vectors() -> void:
	for v: Variant in _vectors().get("errors", []):
		var vd: Dictionary = v
		assert_eq(CanonicalJson.stringify(vd["input"]), "", str(vd["name"]))
		assert_has(CanonicalJson.last_error, "non-integral", str(vd["name"]))
		assert_eq(CanonicalJson.sha256_hex(vd["input"]), "", str(vd["name"]) + ": no hash")


func test_key_order_and_no_whitespace() -> void:
	var d: Dictionary = {"zeta": 1, &"alpha": {"b": [1, 2], "a": null}, "Beta": true, "_x": "y", "10": 0, "9": 0}
	var want: String = "{\"10\":0,\"9\":0,\"Beta\":true,\"_x\":\"y\"," \
		+ "\"alpha\":{\"a\":null,\"b\":[1,2]},\"zeta\":1}"
	assert_eq(CanonicalJson.stringify(d), want,
		"code point order, StringName keys as strings, no spaces")


func test_integer_formatting() -> void:
	assert_eq(CanonicalJson.stringify(12), "12")
	assert_eq(CanonicalJson.stringify(12.0), "12", "integral float → int")
	assert_eq(CanonicalJson.stringify(-0.0), "0")
	assert_eq(CanonicalJson.stringify(-7), "-7")
	assert_eq(CanonicalJson.stringify(CanonicalJson.MAX_SAFE_INT), "9007199254740992", "2^53 allowed")
	assert_eq(CanonicalJson.stringify(-CanonicalJson.MAX_SAFE_INT), "-9007199254740992")
	assert_eq(CanonicalJson.stringify(CanonicalJson.MAX_SAFE_INT + 1), "", "beyond 2^53 → error")
	assert_has(CanonicalJson.last_error, "outside")
	assert_eq(CanonicalJson.stringify(1.0e300), "", "huge float → error")
	assert_eq(CanonicalJson.stringify(INF), "")
	assert_eq(CanonicalJson.stringify(NAN), "")
	assert_eq(CanonicalJson.stringify([1, 2.0, [3, [4.0]]]), "[1,2,[3,[4]]]", "nested arrays")


func test_string_escapes() -> void:
	assert_eq(CanonicalJson.stringify("a/b"), "\"a/b\"", "slash is not escaped")
	assert_eq(CanonicalJson.stringify("q\"b\\"), "\"q\\\"b\\\\\"")
	assert_eq(CanonicalJson.stringify("\t\n\r\b\f"), "\"\\t\\n\\r\\b\\f\"", "short escapes")
	assert_eq(CanonicalJson.stringify(String.chr(1) + String.chr(0x1f)), "\"\\u0001\\u001f\"", "lower-case \\u00xx")
	assert_eq(CanonicalJson.stringify("Grüße €😀"), "\"Grüße €😀\"", "UTF-8 unescaped")
	assert_eq(CanonicalJson.stringify(String.chr(0x7f)), "\"" + String.chr(0x7f) + "\"", "DEL is not a control char")
	assert_eq(CanonicalJson.stringify(&"name"), "\"name\"", "StringName value")


func test_rejected_values() -> void:
	assert_eq(CanonicalJson.stringify({"ä": 1}), "", "non-ASCII key")
	assert_has(CanonicalJson.last_error, "non-ASCII")
	assert_eq(CanonicalJson.stringify({1: 2}), "", "non-string key")
	assert_has(CanonicalJson.last_error, "non-string key")
	assert_eq(CanonicalJson.stringify({"v": Vector2(1, 2)}), "", "Vector2 is not JSON")
	assert_has(CanonicalJson.last_error, "$.v", "error names the path")
	assert_eq(CanonicalJson.stringify([RefCounted.new()]), "", "objects are not JSON")
	assert_eq(CanonicalJson.stringify({"a": [0.5]}), "")
	assert_has(CanonicalJson.last_error, "$.a[0]")
	assert_eq(CanonicalJson.stringify({"ok": 1}), "{\"ok\":1}", "a valid call resets last_error")
	assert_eq(CanonicalJson.last_error, "")


func test_packed_arrays_and_normalize() -> void:
	assert_eq(CanonicalJson.stringify(PackedStringArray(["b", "a"])), "[\"b\",\"a\"]", "order kept")
	assert_eq(CanonicalJson.stringify(PackedInt32Array([3, -1])), "[3,-1]")
	var n: Variant = CanonicalJson.normalize({&"k": [1.0, 2.5, &"s", PackedInt32Array([4])]})
	assert_true(n is Dictionary and (n as Dictionary).has("k"), "StringName key → String")
	var arr: Array = (n as Dictionary)["k"]
	assert_eq(typeof(arr[0]), TYPE_INT, "integral float → int")
	assert_eq(typeof(arr[1]), TYPE_FLOAT, "non-integral float kept")
	assert_eq(typeof(arr[2]), TYPE_STRING)
	assert_eq(typeof(arr[3]), TYPE_ARRAY, "packed → Array")


func test_json_round_trip_is_stable() -> void:
	var v: Dictionary = {"seed": 424242, "list": [1, 2, {"x": -3, "y": [true, null, "s"]}], "nested": {"b": {}, "a": []},
		"text": "Gleis 9 / \"Rattenkönigin\"\n", "big": 9007199254740991}
	var c1: String = CanonicalJson.stringify(v)
	var parsed: Variant = JSON.parse_string(JSON.stringify(v))
	assert_true(parsed is Dictionary)
	assert_eq(CanonicalJson.stringify(parsed), c1, "ints become floats in JSON.parse — canonical form unchanged")
	assert_eq(CanonicalJson.sha256_hex(parsed), CanonicalJson.sha256_hex(v))
	var reparsed: Variant = JSON.parse_string(c1)
	assert_eq(CanonicalJson.stringify(reparsed), c1, "canonical text parses back to itself")


func test_sha256_text() -> void:
	assert_eq(CanonicalJson.sha256_text(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
	assert_eq(CanonicalJson.sha256_text("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
	assert_eq(CanonicalJson.sha256_hex({"a": 1}), CanonicalJson.sha256_text("{\"a\":1}"))
