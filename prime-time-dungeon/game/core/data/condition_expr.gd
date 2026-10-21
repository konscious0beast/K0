class_name ConditionExpr extends RefCounted
## Parser/evaluator for achievement and scene conditions (02_TECH §4.4.9, §6.1).
##
## Grammar:
##   expr    := clause ( "&&" clause )*
##   clause  := "true" | operand OP literal
##   operand := "e." KEY | "s." STAT_ID | "f." FLAG          (KEY/FLAG: [a-z0-9_]+)
##   OP      := "==" | "!=" | ">=" | "<=" | ">" | "<"
##   literal := number | "\"" text "\"" | "true" | "false"
##
## Semantics: e = trigger payload / scene context, s = ShowState.stats (missing = 0), f = GameState.flags
## (missing = false, or 0 when compared with a number). Numbers compare numerically (int/float alike),
## strings and bools only with == / != (other operators are parse errors), type conflict = false.

const OPS: PackedStringArray = ["==", "!=", ">=", "<=", ">", "<"]
const SCOPES: PackedStringArray = ["e", "s", "f"]

var error: String = ""          # "" = parsed OK
var source: String = ""

# Each clause: {"always": bool, "scope": String, "key": String, "op": String, "value": Variant}
var _clauses: Array[Dictionary] = []
var _src: String = ""
var _pos: int = 0


## Parses `src`. Never returns null; check `error` ("" = OK).
static func parse(src: String) -> ConditionExpr:
	var ce: ConditionExpr = ConditionExpr.new()
	ce.source = src
	ce._parse_all(src)
	return ce


## True if every clause holds. A condition with a parse error is always false.
func eval(e: Dictionary, s: Dictionary, f: Dictionary) -> bool:
	if error != "":
		return false
	for c: Dictionary in _clauses:
		if bool(c["always"]):
			continue
		var lit: Variant = c["value"]
		var lhs: Variant = _lookup(str(c["scope"]), str(c["key"]), lit, e, s, f)
		if not _compare(lhs, str(c["op"]), lit):
			return false
	return true


## Operands for validation: [{"scope": "e"|"s"|"f", "key": String}] in source order.
func operands() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in _clauses:
		if not bool(c["always"]):
			out.append({"scope": c["scope"], "key": c["key"]})
	return out


## Number of clauses (including "true").
func clause_count() -> int:
	return _clauses.size()


# --- evaluation ------------------------------------------------------------------

func _lookup(scope: String, key: String, lit: Variant, e: Dictionary, s: Dictionary, f: Dictionary) -> Variant:
	match scope:
		"e":
			if e.has(key):
				return e[key]
			if e.has(StringName(key)):
				return e[StringName(key)]
			return null
		"s":
			if s.has(key):
				return s[key]
			if s.has(StringName(key)):
				return s[StringName(key)]
			return 0
		"f":
			if f.has(key):
				return f[key]
			if f.has(StringName(key)):
				return f[StringName(key)]
			if _is_num(lit):
				return 0
			return false
	return null


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _is_str(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME


static func _compare(lhs: Variant, op: String, rhs: Variant) -> bool:
	if _is_num(rhs):
		if not _is_num(lhs):
			return false
		if typeof(lhs) == TYPE_INT and typeof(rhs) == TYPE_INT:
			var a: int = lhs
			var b: int = rhs
			match op:
				"==": return a == b
				"!=": return a != b
				">=": return a >= b
				"<=": return a <= b
				">": return a > b
				"<": return a < b
			return false
		var fa: float = float(lhs)
		var fb: float = float(rhs)
		match op:
			"==": return fa == fb
			"!=": return fa != fb
			">=": return fa >= fb
			"<=": return fa <= fb
			">": return fa > fb
			"<": return fa < fb
		return false
	if _is_str(rhs):
		if not _is_str(lhs):
			return false
		var sa: String = str(lhs)
		var sb: String = str(rhs)
		match op:
			"==": return sa == sb
			"!=": return sa != sb
		return false
	if typeof(rhs) == TYPE_BOOL:
		if typeof(lhs) != TYPE_BOOL:
			return false
		var ba: bool = lhs
		var bb: bool = rhs
		match op:
			"==": return ba == bb
			"!=": return ba != bb
		return false
	return false


# --- parsing ---------------------------------------------------------------------

func _parse_all(src: String) -> void:
	_src = src
	_pos = 0
	_clauses.clear()
	error = ""
	_skip_ws()
	if _pos >= _src.length():
		error = "empty expression"
		return
	while true:
		if not _parse_clause():
			_clauses.clear()
			return
		_skip_ws()
		if _pos >= _src.length():
			return
		if _src.substr(_pos, 2) != "&&":
			error = "expected '&&' at position %d" % _pos
			_clauses.clear()
			return
		_pos += 2
		_skip_ws()
		if _pos >= _src.length():
			error = "expected clause after '&&' at position %d" % _pos
			_clauses.clear()
			return


func _parse_clause() -> bool:
	var start: int = _pos
	var word: String = _read_ident()
	if word == "true":
		_clauses.append({"always": true, "scope": "", "key": "", "op": "", "value": true})
		return true
	if not SCOPES.has(word):
		error = "expected operand (e./s./f.) or 'true' at position %d" % start
		return false
	if _pos >= _src.length() or _src[_pos] != ".":
		error = "expected '.' after '%s' at position %d" % [word, _pos]
		return false
	_pos += 1
	var key_start: int = _pos
	var key: String = _read_ident()
	if key == "":
		error = "expected key after '%s.' at position %d" % [word, key_start]
		return false
	_skip_ws()
	var op: String = ""
	for candidate: String in OPS:
		if _src.substr(_pos, candidate.length()) == candidate:
			op = candidate
			break
	if op == "":
		error = "expected comparison operator at position %d" % _pos
		return false
	_pos += op.length()
	_skip_ws()
	var lit_pos: int = _pos
	var lit: Array = _read_literal()
	if not bool(lit[0]):
		if error == "":
			error = "expected literal at position %d" % lit_pos
		return false
	var value: Variant = lit[1]
	if not _is_num(value) and op != "==" and op != "!=":
		error = "operator '%s' needs a number literal (position %d)" % [op, lit_pos]
		return false
	_clauses.append({"always": false, "scope": word, "key": key, "op": op, "value": value})
	return true


func _skip_ws() -> void:
	while _pos < _src.length() and (_src[_pos] == " " or _src[_pos] == "\t" or _src[_pos] == "\n" or _src[_pos] == "\r"):
		_pos += 1


static func _is_ident_char(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"


func _read_ident() -> String:
	var start: int = _pos
	while _pos < _src.length() and _is_ident_char(_src[_pos]):
		_pos += 1
	return _src.substr(start, _pos - start)


## Returns [ok: bool, value: Variant].
func _read_literal() -> Array:
	if _pos >= _src.length():
		return [false, null]
	var c: String = _src[_pos]
	if c == "\"":
		_pos += 1
		var text: String = ""
		while _pos < _src.length():
			var ch: String = _src[_pos]
			if ch == "\\":
				if _pos + 1 >= _src.length():
					break
				text += _src[_pos + 1]
				_pos += 2
				continue
			if ch == "\"":
				_pos += 1
				return [true, text]
			text += ch
			_pos += 1
		error = "unterminated string literal"
		return [false, null]
	if c == "-" or (c >= "0" and c <= "9"):
		var start: int = _pos
		if c == "-":
			_pos += 1
		var digits: int = 0
		while _pos < _src.length() and _src[_pos] >= "0" and _src[_pos] <= "9":
			_pos += 1
			digits += 1
		var is_float: bool = false
		if _pos < _src.length() and _src[_pos] == ".":
			is_float = true
			_pos += 1
			var frac: int = 0
			while _pos < _src.length() and _src[_pos] >= "0" and _src[_pos] <= "9":
				_pos += 1
				frac += 1
			if frac == 0:
				error = "malformed number at position %d" % start
				return [false, null]
		if digits == 0:
			error = "malformed number at position %d" % start
			return [false, null]
		if _pos < _src.length() and _is_ident_char(_src[_pos]):
			error = "malformed number at position %d" % start
			return [false, null]
		var num_text: String = _src.substr(start, _pos - start)
		if is_float:
			return [true, num_text.to_float()]
		return [true, num_text.to_int()]
	var word: String = _read_ident()
	if word == "true":
		return [true, true]
	if word == "false":
		return [true, false]
	return [false, null]
