# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name CanonicalJson extends RefCounted
## Canonical serialization for hashes (05 §3.3 no. 9, §11.2).
## `last_error` is static: the static functions set it, callers read `CanonicalJson.last_error` ("" = last call ok).

static var last_error: String = ""


static func stringify(v: Variant) -> String:
	return ""


static func sha256_hex(v: Variant) -> String:
	return ""
