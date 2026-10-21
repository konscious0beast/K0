extends RefCounted
## The string literals of a GDScript source (11 §1.11, §1.12): the rules of test_09_terms.literals() — comments
## skipped, '…' and "…" with backslash escapes, triple-quoted strings across lines — plus what the extractor and the
## lint need on top: the column, the prefix (& StringName, ^ NodePath, r raw), the unescaped value and the code
## between the literals (comments removed), so a call like Tx.t("…") can be recognised around its literal.

const IDENT: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"


## {"lits": [{"line": int (1-based, where it starts), "col": int, "raw": String (between the quotes), "text": String
## (the value), "prefix": "" | "&" | "^" | "r"}], "code": PackedStringArray (code[i] = the code before lits[i] since
## the literal before it, code[lits.size()] = the rest), "comments": {line: the text after "#"}}.
static func scan(source: String) -> Dictionary:
	var lits: Array[Dictionary] = []
	var code: PackedStringArray = []
	var comments: Dictionary = {}
	var cur: String = ""
	var open: Dictionary = {}                     # a triple-quoted string still open
	var lines: PackedStringArray = source.split("\n")
	for n in lines.size():
		var line: String = lines[n]
		var i: int = 0
		var count: int = line.length()
		if not open.is_empty():
			var end: int = line.find(str(open["q"]))
			if end < 0:
				open["raw"] = str(open["raw"]) + line + "\n"
				continue
			open["raw"] = str(open["raw"]) + line.substr(0, end)
			lits.append(_lit(open))
			code.append(cur)
			cur = ""
			open = {}
			i = end + 3
		while i < count:
			var j: int = _next_special(line, i)
			if j < 0:
				cur += line.substr(i)
				break
			cur += line.substr(i, j - i)
			var ch: String = line[j]
			if ch == "#":
				comments[n + 1] = line.substr(j + 1)
				break
			var prefix: String = ""
			var tail: String = cur.right(2)
			if cur.ends_with("&") or cur.ends_with("^"):
				prefix = cur.right(1)
			elif cur.ends_with("r") and (tail.length() < 2 or not IDENT.contains(tail[0])):
				prefix = "r"
			if prefix != "":
				cur = cur.left(cur.length() - 1)
			if line.substr(j, 3) == ch.repeat(3):
				var close3: int = line.find(ch.repeat(3), j + 3)
				var lit3: Dictionary = {"q": ch.repeat(3), "line": n + 1, "col": j, "prefix": prefix,
					"raw": line.substr(j + 3) + "\n" if close3 < 0 else line.substr(j + 3, close3 - j - 3)}
				if close3 < 0:
					open = lit3
					i = count
					continue
				lits.append(_lit(lit3))
				code.append(cur)
				cur = ""
				i = close3 + 3
				continue
			var k: int = _closing(line, ch, j + 1)
			lits.append(_lit({"q": ch, "line": n + 1, "col": j, "prefix": prefix,
				"raw": line.substr(j + 1, (k if k >= 0 else count) - j - 1)}))
			code.append(cur)
			cur = ""
			i = count if k < 0 else k + 1
		if open.is_empty():
			cur += "\n"
	code.append(cur)
	return {"lits": lits, "code": code, "comments": comments}


## The value of a GDScript string literal's source text (escapes \n \t \r \a \b \f \v \\ \" \' \uXXXX \UXXXXXX;
## raw strings keep their backslashes).
static func unescape(raw: String, prefix: String = "") -> String:
	if prefix == "r" or not raw.contains("\\"):
		return raw
	var out: String = ""
	var i: int = 0
	var count: int = raw.length()
	while i < count:
		var c: String = raw[i]
		if c != "\\" or i + 1 >= count:
			out += c
			i += 1
			continue
		var e: String = raw[i + 1]
		i += 2
		match e:
			"n":
				out += "\n"
			"t":
				out += "\t"
			"r":
				out += "\r"
			"a":
				out += char(7)
			"b":
				out += char(8)
			"f":
				out += char(12)
			"v":
				out += char(11)
			"u", "U":
				var digits: int = 4 if e == "u" else 6
				out += char(raw.substr(i, digits).hex_to_int())
				i += digits
			"\n":
				pass                              # a line continuation inside a string
			_:
				out += e                          # \\ \" \' and anything else: the character itself
	return out


static func _lit(d: Dictionary) -> Dictionary:
	var raw: String = str(d["raw"])
	return {"line": int(d["line"]), "col": int(d["col"]), "raw": raw, "text": unescape(raw, str(d["prefix"])),
		"prefix": str(d["prefix"])}


## The first ", ' or # at or after `from` (-1: none).
static func _next_special(line: String, from: int) -> int:
	var best: int = -1
	for ch: String in ["\"", "'", "#"]:
		var p: int = line.find(ch, from)
		if p >= 0 and (best < 0 or p < best):
			best = p
	return best


## The closing quote `q` of a string starting at `from` (-1: none on this line); escaped quotes are skipped (raw strings
## too: a backslash keeps the quote in them).
static func _closing(line: String, q: String, from: int) -> int:
	var k: int = line.find(q, from)
	while k >= 0:
		var slashes: int = 0
		var b: int = k - 1
		while b >= from and line[b] == "\\":
			slashes += 1
			b -= 1
		if slashes % 2 == 0:
			return k
		k = line.find(q, k + 1)
	return -1
