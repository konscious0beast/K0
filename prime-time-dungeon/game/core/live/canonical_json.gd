class_name CanonicalJson extends RefCounted
## Canonical serialization for hashes and signatures (05 §3.3 Nr. 9, §11.2): a profile of RFC 8785 (JCS).
##
## - Only integers (|n| <= 2^53), strings, bools, null, arrays and objects. Integral floats (JSON.parse returns every
##   number as float, 02_TECH §4.1) are normalized to int; non-integral, infinite or NaN numbers are an error.
## - Object keys: String/StringName, ASCII only, sorted by code point; no whitespace anywhere.
## - Strings: UTF-8 without \u escapes except for the control characters U+0000–U+001F (short forms \b \f \n \r \t,
##   else \u00xx with lower-case hex); `"` and `\` are escaped, `/` is NOT escaped.
## - Packed arrays are arrays; every other Variant type (Object, Vector2, …) is an error.
## `last_error` is static: the static functions set it, callers read `CanonicalJson.last_error` ("" = last call ok).
## For the allowed value space the output is byte-identical to Python
## `json.dumps(v, sort_keys=True, separators=(",", ":"), ensure_ascii=False)` (shared vectors:
## tests/fixtures/live/canonical_vectors.json).

const MAX_SAFE_INT: int = 9007199254740992   # 2^53
const MAX_DEPTH: int = 256
const _SHORT_ESCAPES: Dictionary = {8: "\\b", 9: "\\t", 10: "\\n", 12: "\\f", 13: "\\r"}

static var last_error: String = ""
static var _needs_escape: RegEx = null


## Canonical JSON text of `v`; "" and `last_error` set on error.
static func stringify(v: Variant) -> String:
	last_error = ""
	var parts: PackedStringArray = []
	if not _emit(v, parts, 0, "$"):
		return ""
	return "".join(parts)


## Lower-case hex SHA-256 over the UTF-8 bytes of stringify(v); "" (and `last_error`) on error.
static func sha256_hex(v: Variant) -> String:
	var text: String = stringify(v)
	if last_error != "":
		return ""
	return sha256_text(text)


## Lower-case hex SHA-256 over the UTF-8 bytes of `text` (no canonicalization).
static func sha256_text(text: String) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var bytes: PackedByteArray = text.to_utf8_buffer()
	if not bytes.is_empty():          # HashingContext.update refuses empty buffers
		ctx.update(bytes)
	return ctx.finish().hex_encode()


## Deep copy with integral floats → int, StringName → String (values and keys), Packed arrays → Array. Values that
## stringify() would reject are copied unchanged (normalize never fails); used before storing JSON-derived data so a
## JSON round trip (ints become floats) does not change hashes or comparisons.
static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floorf(f) and absf(f) <= float(MAX_SAFE_INT):
				return int(f)
			return f
		TYPE_STRING_NAME:
			return String(v)
		TYPE_DICTIONARY:
			var src: Dictionary = v
			var out: Dictionary = {}
			for k: Variant in src.keys():
				out[String(k) if typeof(k) == TYPE_STRING_NAME else k] = normalize(src[k])
			return out
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_BYTE_ARRAY:
			var out_a: Array = []
			for e: Variant in Array(v):
				out_a.append(normalize(e))
			return out_a
	return v


# --- internals --------------------------------------------------------------------------------------------------------

static func _emit(v: Variant, parts: PackedStringArray, depth: int, at: String) -> bool:
	if depth > MAX_DEPTH:
		return _error("nesting deeper than %d at %s" % [MAX_DEPTH, at])
	match typeof(v):
		TYPE_NIL:
			parts.append("null")
		TYPE_BOOL:
			parts.append("true" if bool(v) else "false")
		TYPE_INT:
			var i: int = v
			if i > MAX_SAFE_INT or i < -MAX_SAFE_INT:
				return _error("integer %d outside ±2^53 at %s" % [i, at])
			parts.append(str(i))
		TYPE_FLOAT:
			var f: float = v
			if not is_finite(f) or f != floorf(f):
				return _error("non-integral number %s at %s" % [str(f), at])
			if absf(f) > float(MAX_SAFE_INT):
				return _error("number %s outside ±2^53 at %s" % [str(f), at])
			parts.append(str(int(f)))
		TYPE_STRING, TYPE_STRING_NAME:
			parts.append(_quote(str(v)))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_BYTE_ARRAY:
			var arr: Array = Array(v)
			parts.append("[")
			for i in arr.size():
				if i > 0:
					parts.append(",")
				if not _emit(arr[i], parts, depth + 1, "%s[%d]" % [at, i]):
					return false
			parts.append("]")
		TYPE_DICTIONARY:
			return _emit_object(v, parts, depth, at)
		_:
			return _error("unsupported type %s at %s" % [type_string(typeof(v)), at])
	return true


static func _emit_object(d: Dictionary, parts: PackedStringArray, depth: int, at: String) -> bool:
	var keys: Array[String] = []
	var src_keys: Dictionary = {}       # canonical key → original key
	for k: Variant in d.keys():
		if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
			return _error("non-string key %s (%s) at %s" % [str(k), type_string(typeof(k)), at])
		var ks: String = str(k)
		if not _is_ascii(ks):
			return _error("non-ASCII key \"%s\" at %s" % [ks, at])
		if src_keys.has(ks):
			return _error("duplicate key \"%s\" at %s" % [ks, at])
		src_keys[ks] = k
		keys.append(ks)
	keys.sort()   # ASCII only: String ordering == code point ordering
	parts.append("{")
	for i in keys.size():
		if i > 0:
			parts.append(",")
		parts.append(_quote(keys[i]))
		parts.append(":")
		if not _emit(d[src_keys[keys[i]]], parts, depth + 1, "%s.%s" % [at, keys[i]]):
			return false
	parts.append("}")
	return true


static func _quote(s: String) -> String:
	if _needs_escape == null:
		_needs_escape = RegEx.create_from_string("[\\x00-\\x1f\"\\\\]")
	if _needs_escape.search(s) == null:
		return "\"" + s + "\""
	var out: PackedStringArray = ["\""]
	for i in s.length():
		var c: int = s.unicode_at(i)
		if c == 0x22:
			out.append("\\\"")
		elif c == 0x5C:
			out.append("\\\\")
		elif c < 0x20:
			out.append(str(_SHORT_ESCAPES[c]) if _SHORT_ESCAPES.has(c) else "\\u%04x" % c)
		else:
			out.append(s[i])
	out.append("\"")
	return "".join(out)


static func _is_ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 0x7F:
			return false
	return true


static func _error(msg: String) -> bool:
	if last_error == "":
		last_error = msg
	return false
