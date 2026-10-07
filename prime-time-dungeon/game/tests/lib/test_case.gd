class_name TestCase extends RefCounted
## Base class of all tests (02_TECH §11.2). Lives in tests/lib/ so the runner does not load it as a test file.
## Asserts never abort a test; all failures of a test are collected. Never wait on raw signals — use
## await_signal()/wait_until() with a frame limit.

const DATA_DIR: String = "res://data"

var tree: SceneTree                       # set by runner

var _failures: PackedStringArray = []
var _skipped: String = ""
var _current: String = ""
var _nodes: Array[Node] = []

static var _real_data: GameData = null


## Override.
func before_each() -> void:
	pass


## Override. Nodes added via add_to_tree() are freed automatically after it (in _tc_end).
func after_each() -> void:
	pass


# --- asserts ---------------------------------------------------------------------------------------------------------

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		_fail_with("expected true", msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		_fail_with("expected false", msg)


## Deep equality via _deep_eq (never `==` on mixed types).
func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	var reason: String = _deep_diff(actual, expected)
	if reason != "":
		_fail_with("expected %s, got %s (%s)" % [_fmt(expected), _fmt(actual), reason], msg)


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if _deep_diff(actual, unexpected) == "":
		_fail_with("expected a value different from %s" % _fmt(unexpected), msg)


func assert_almost(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		_fail_with("expected %s ± %s, got %s" % [str(expected), str(eps), str(actual)], msg)


func assert_gt(a: Variant, b: Variant, msg: String = "") -> void:
	var c: int = _cmp(a, b)
	if c == -2:
		_fail_with("cannot compare %s and %s" % [_fmt(a), _fmt(b)], msg)
	elif c <= 0:
		_fail_with("expected %s > %s" % [_fmt(a), _fmt(b)], msg)


func assert_lt(a: Variant, b: Variant, msg: String = "") -> void:
	var c: int = _cmp(a, b)
	if c == -2:
		_fail_with("cannot compare %s and %s" % [_fmt(a), _fmt(b)], msg)
	elif c >= 0:
		_fail_with("expected %s < %s" % [_fmt(a), _fmt(b)], msg)


## Inclusive.
func assert_between(v: Variant, lo: Variant, hi: Variant, msg: String = "") -> void:
	var c1: int = _cmp(v, lo)
	var c2: int = _cmp(v, hi)
	if c1 == -2 or c2 == -2:
		_fail_with("cannot compare %s with %s..%s" % [_fmt(v), _fmt(lo), _fmt(hi)], msg)
	elif c1 < 0 or c2 > 0:
		_fail_with("expected %s in %s..%s" % [_fmt(v), _fmt(lo), _fmt(hi)], msg)


func assert_null(v: Variant, msg: String = "") -> void:
	if not _is_null(v):
		_fail_with("expected null, got %s" % _fmt(v), msg)


func assert_not_null(v: Variant, msg: String = "") -> void:
	if _is_null(v):
		_fail_with("expected a value, got null", msg)


## Array/Packed*Array element, Dictionary key, String substring.
func assert_has(container: Variant, item: Variant, msg: String = "") -> void:
	if not _contains(container, item):
		_fail_with("%s does not contain %s" % [_fmt(container), _fmt(item)], msg)


func assert_len(container: Variant, n: int, msg: String = "") -> void:
	var size: int = _size_of(container)
	if size == -1:
		_fail_with("%s has no length" % _fmt(container), msg)
	elif size != n:
		_fail_with("expected length %d, got %d" % [n, size], msg)


func fail(msg: String) -> void:
	if _skipped != "":
		return
	_failures.append(msg)


## Marks the test skipped; further asserts are ignored.
func skip(reason: String) -> void:
	_skipped = reason if reason != "" else "skipped"


# --- helpers ---------------------------------------------------------------------------------------------------------

func make_rng(seed: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return rng


## Cached GameData.load_dir("res://data").
func real_data() -> GameData:
	if _real_data == null:
		_real_data = GameData.new()
		_real_data.load_dir(DATA_DIR)
	if not _real_data.is_valid():
		fail("real data invalid: " + "; ".join(_real_data.errors))
	return _real_data


## GameData.load_from_dicts(tables); fails the test if invalid.
func fixture_data(tables: Dictionary) -> GameData:
	var data: GameData = GameData.new()
	if not data.load_from_dicts(tables):
		fail("fixture data invalid: " + "; ".join(data.errors))
	return data


## tree.root.add_child(node); screen scenes (setup/on_resume/…) → Router.adopt(node). Freed after the test.
func add_to_tree(node: Node) -> Node:
	if node == null:
		fail("add_to_tree(null)")
		return null
	tree.root.add_child(node)
	_nodes.append(node)
	if node.has_method("setup") or node.has_method("on_resume") or node.has_method("on_suspend") \
			or node.has_method("request_new_game"):
		var router: Node = tree.root.get_node_or_null("Router")
		if router != null:
			router.call("adopt", node)
	return node


## Coroutine: awaits tree.process_frame n times.
func wait_frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Coroutine: true if `sig` is emitted within max_frames, else false + fail().
func await_signal(sig: Signal, max_frames: int = 300) -> bool:
	var fired: Array[bool] = [false]
	var cb: Callable = func(..._args: Array) -> void:
		fired[0] = true
	sig.connect(cb)
	var frames: int = 0
	while not fired[0] and frames < max_frames:
		await tree.process_frame
		frames += 1
	if not sig.is_null() and sig.is_connected(cb):
		sig.disconnect(cb)
	if not fired[0]:
		fail("signal '%s' not emitted within %d frames" % [sig.get_name(), max_frames])
		return false
	return true


## Coroutine: polls cond each frame; false + fail() on timeout.
func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames + 1:
		if bool(cond.call()):
			return true
		if i < max_frames:
			await tree.process_frame
	fail("condition not met within %d frames" % max_frames)
	return false


## int/float numerically, String == StringName, Packed*Array vs Array element-wise, Dictionary by keys;
## type mismatch → false (never `==` on mixed types).
func _deep_eq(a: Variant, b: Variant) -> bool:
	return _deep_diff(a, b) == ""


## Identifies TestCase for the runner.
func _tc_marker() -> void:
	pass


# --- runner protocol ------------------------------------------------------------------------------------------------

func _tc_begin(test_name: String) -> void:
	_current = test_name
	_failures = PackedStringArray()
	_skipped = ""


## {"failures": PackedStringArray, "skipped": String}; frees nodes added via add_to_tree().
func _tc_end() -> Dictionary:
	for n: Node in _nodes:
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_nodes.clear()
	return {"failures": _failures.duplicate(), "skipped": _skipped}


## Test method names of a script: "test_*" without required args, deduplicated by name (first occurrence wins;
## the list has own methods first, then inherited ones; overridden methods appear twice), declaration order.
static func collect_test_methods(script: Script) -> PackedStringArray:
	var out: PackedStringArray = []
	if script == null:
		return out
	for m: Dictionary in script.get_script_method_list():
		var mname: String = str(m.get("name", ""))
		if not mname.begins_with("test_") or out.has(mname):
			continue
		var args: Array = m.get("args", [])
		var defaults: Array = m.get("default_args", [])
		if args.size() - defaults.size() != 0:
			continue
		out.append(mname)
	return out


# --- internals -------------------------------------------------------------------------------------------------------

func _fail_with(what: String, msg: String) -> void:
	fail(what if msg == "" else "%s — %s" % [what, msg])


static func _is_null(v: Variant) -> bool:
	if v == null:
		return true
	if typeof(v) == TYPE_OBJECT and not is_instance_valid(v):
		return true
	return false


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _is_str(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME


static func _is_array_like(v: Variant) -> bool:
	var t: int = typeof(v)
	return t == TYPE_ARRAY or (t >= TYPE_PACKED_BYTE_ARRAY and t <= TYPE_PACKED_VECTOR4_ARRAY)


static func _fmt(v: Variant) -> String:
	if _is_str(v):
		return "\"%s\"" % str(v)
	var s: String = str(v)
	if s.length() > 200:
		s = s.substr(0, 200) + "…"
	return s


## "" if equal, otherwise the reason.
static func _deep_diff(a: Variant, b: Variant) -> String:
	if _is_null(a) and _is_null(b):
		return ""
	if _is_null(a) or _is_null(b):
		return "null vs value"
	if _is_num(a) and _is_num(b):
		if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
			return "" if int(a) == int(b) else "numbers differ"
		return "" if float(a) == float(b) else "numbers differ"
	if _is_str(a) and _is_str(b):
		return "" if str(a) == str(b) else "strings differ"
	if _is_array_like(a) and _is_array_like(b):
		var aa: Array = Array(a)
		var bb: Array = Array(b)
		if aa.size() != bb.size():
			return "size %d vs %d" % [aa.size(), bb.size()]
		for i in aa.size():
			var r: String = _deep_diff(aa[i], bb[i])
			if r != "":
				return "[%d]: %s" % [i, r]
		return ""
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return "dictionary size %d vs %d" % [da.size(), db.size()]
		for k: Variant in da.keys():
			var found: Array = _find_key(db, k)
			if not bool(found[0]):
				return "missing key %s" % _fmt(k)
			var r2: String = _deep_diff(da[k], db[found[1]])
			if r2 != "":
				return "[%s]: %s" % [_fmt(k), r2]
		return ""
	if typeof(a) != typeof(b):
		return "type %s vs %s" % [type_string(typeof(a)), type_string(typeof(b))]
	if typeof(a) == TYPE_OBJECT:
		return "" if a == b else "different objects"
	return "" if a == b else "values differ"


## [found: bool, key in d] with String/StringName and int/float tolerance.
static func _find_key(d: Dictionary, k: Variant) -> Array:
	if d.has(k):
		return [true, k]
	for other: Variant in d.keys():
		if (_is_str(k) and _is_str(other)) or (_is_num(k) and _is_num(other)):
			if _deep_diff(k, other) == "":
				return [true, other]
	return [false, null]


static func _contains(container: Variant, item: Variant) -> bool:
	if _is_array_like(container):
		for e: Variant in Array(container):
			if _deep_diff(e, item) == "":
				return true
		return false
	if typeof(container) == TYPE_DICTIONARY:
		return bool(_find_key(container, item)[0])
	if _is_str(container) and _is_str(item):
		return str(container).contains(str(item))
	return false


static func _size_of(container: Variant) -> int:
	if _is_array_like(container):
		return Array(container).size()
	if typeof(container) == TYPE_DICTIONARY:
		return (container as Dictionary).size()
	if _is_str(container):
		return str(container).length()
	return -1


## -2 not comparable, else -1/0/1.
static func _cmp(a: Variant, b: Variant) -> int:
	if _is_num(a) and _is_num(b):
		var fa: float = float(a)
		var fb: float = float(b)
		return 0 if fa == fb else (-1 if fa < fb else 1)
	if _is_str(a) and _is_str(b):
		var sa: String = str(a)
		var sb: String = str(b)
		return 0 if sa == sb else (-1 if sa < sb else 1)
	return -2
