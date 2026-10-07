class_name JsonUtil extends RefCounted
## JSON helpers: file reading/writing without engine error spam, safe number/array conversion,
## grid coordinate conversion ([x, y] <-> Vector2i). Pure helpers, no autoloads.

static var _last_error: String = ""


## Message of the last failed read_file()/parse()/write_file() ("" after a success).
static func last_error() -> String:
	return _last_error


## Reads and parses a JSON file. Returns the parsed Variant, or null on error (see last_error()).
## Never prints engine errors (missing file and parse errors are reported via last_error()).
static func read_file(path: String) -> Variant:
	_last_error = ""
	if not FileAccess.file_exists(path):
		_last_error = "file not found"
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_last_error = "cannot open file (error %d)" % FileAccess.get_open_error()
		return null
	var text: String = f.get_as_text()
	f.close()
	return parse(text)


## Parses JSON text. Returns null on error (see last_error()).
static func parse(text: String) -> Variant:
	_last_error = ""
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		_last_error = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		return null
	return json.data


## Writes `data` as JSON text (UTF-8). Returns OK or the FileAccess error.
static func write_file(path: String, data: Variant, indent: String = "\t") -> Error:
	_last_error = ""
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		var err: Error = FileAccess.get_open_error()
		_last_error = "cannot write file (error %d)" % err
		return err
	f.store_string(JSON.stringify(data, indent))
	f.close()
	return OK


## Floats at or above this magnitude are not integral data (int() could overflow int64; JSON doubles lose
## integer precision above 2^53 ≈ 9.007e15 anyway).
const MAX_INTEGRAL: float = 9.0e15


## True if `v` is an int, or a float without fractional part with |v| < MAX_INTEGRAL (JSON numbers are floats).
static func is_integral(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		return is_finite(f) and absf(f) < MAX_INTEGRAL and fmod(f, 1.0) == 0.0
	return false


## True if `v` is an int or float (never bool).
static func is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## Converts a JSON number (or numeric string) to int; anything else → `default`.
static func to_int(v: Variant, default: int = 0) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v)
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_STRING, TYPE_STRING_NAME:
			var s: String = str(v)
			if s.is_valid_int():
				return s.to_int()
			if s.is_valid_float():
				return int(s.to_float())
	return default


## Converts a JSON number (or numeric string) to float; anything else → `default`.
static func to_float(v: Variant, default: float = 0.0) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_STRING, TYPE_STRING_NAME:
			var s: String = str(v)
			if s.is_valid_float():
				return s.to_float()
	return default


## Converts an Array / PackedStringArray of strings to PackedStringArray (non-strings are stringified).
static func to_str_array(v: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if typeof(v) == TYPE_PACKED_STRING_ARRAY:
		out = v
		return out.duplicate()
	if typeof(v) == TYPE_ARRAY:
		var arr: Array = v
		for e: Variant in arr:
			out.append(str(e))
	return out


## Vector2i → [x, y] (save files, JSON).
static func vec2i_to_arr(v: Vector2i) -> Array:
	return [v.x, v.y]


## [x, y] (JSON numbers) → Vector2i; malformed input → `default`.
static func arr_to_vec2i(a: Variant, default: Vector2i = Vector2i.ZERO) -> Vector2i:
	if typeof(a) == TYPE_VECTOR2I:
		return a
	if typeof(a) != TYPE_ARRAY and typeof(a) != TYPE_PACKED_INT32_ARRAY and typeof(a) != TYPE_PACKED_FLOAT32_ARRAY:
		return default
	var arr: Array = Array(a)
	if arr.size() != 2 or not is_number(arr[0]) or not is_number(arr[1]):
		return default
	return Vector2i(int(arr[0]), int(arr[1]))


## [x, z] (JSON numbers) → Vector2 (room-local offsets); malformed input → `default`.
static func arr_to_vec2(a: Variant, default: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(a) == TYPE_VECTOR2:
		return a
	if typeof(a) != TYPE_ARRAY:
		return default
	var arr: Array = a
	if arr.size() != 2 or not is_number(arr[0]) or not is_number(arr[1]):
		return default
	return Vector2(float(arr[0]), float(arr[1]))
