extends TestCase
## ConditionExpr: grammar, type comparisons, error cases (02_TECH §4.4.9).


func _ok(src: String) -> ConditionExpr:
	var ce: ConditionExpr = ConditionExpr.parse(src)
	assert_eq(ce.error, "", "parse '%s'" % src)
	return ce


func test_true_clause() -> void:
	var ce: ConditionExpr = _ok("true")
	assert_true(ce.eval({}, {}, {}))
	assert_len(ce.operands(), 0)
	assert_true(_ok("  true  ").eval({}, {}, {}))


func test_numeric_comparisons_int_float() -> void:
	var ce: ConditionExpr = _ok("e.min_party_hp == 1")
	assert_true(ce.eval({"min_party_hp": 1}, {}, {}))
	assert_true(ce.eval({"min_party_hp": 1.0}, {}, {}), "JSON float equals int literal")
	assert_false(ce.eval({"min_party_hp": 2}, {}, {}))
	var pct: ConditionExpr = _ok("e.min_party_hp_pct <= 0.1")
	assert_true(pct.eval({"min_party_hp_pct": 0.1}, {}, {}))
	assert_true(pct.eval({"min_party_hp_pct": 0}, {}, {}))
	assert_false(pct.eval({"min_party_hp_pct": 0.11}, {}, {}))
	assert_true(_ok("e.x > -2").eval({"x": -1}, {}, {}), "negative literal")
	assert_true(_ok("e.x >= 3").eval({"x": 3}, {}, {}))
	assert_false(_ok("e.x < 3").eval({"x": 3}, {}, {}))
	assert_true(_ok("e.x != 3").eval({"x": 4.5}, {}, {}))


func test_strings_and_string_names() -> void:
	var ce: ConditionExpr = _ok("e.enemy_id == \"enm_fahrscheinfresser\"")
	assert_true(ce.eval({"enemy_id": "enm_fahrscheinfresser"}, {}, {}))
	assert_true(ce.eval({"enemy_id": &"enm_fahrscheinfresser"}, {}, {}), "StringName payload")
	assert_false(ce.eval({"enemy_id": "enm_kanalratte"}, {}, {}))
	assert_true(_ok("e.by != \"attack\"").eval({"by": "skill"}, {}, {}))
	assert_true(_ok("e.t == \"a \\\"q\\\" b\"").eval({"t": "a \"q\" b"}, {}, {}), "escaped quotes")


func test_bools() -> void:
	var ce: ConditionExpr = _ok("e.first_visit == true")
	assert_true(ce.eval({"first_visit": true}, {}, {}))
	assert_false(ce.eval({"first_visit": false}, {}, {}))
	assert_true(_ok("e.is_boss != true").eval({"is_boss": false}, {}, {}))


func test_type_conflicts_are_false() -> void:
	assert_false(_ok("e.x == 1").eval({"x": "1"}, {}, {}), "string vs number")
	assert_false(_ok("e.x == \"1\"").eval({"x": 1}, {}, {}), "number vs string")
	assert_false(_ok("e.x == 1").eval({"x": true}, {}, {}), "bool vs number")
	assert_false(_ok("e.x == true").eval({"x": 1}, {}, {}), "number vs bool")
	assert_false(_ok("e.x != \"a\"").eval({"x": 3}, {}, {}), "conflict is false even for !=")
	assert_false(_ok("e.missing == 0").eval({}, {}, {}), "missing payload key → false")


func test_stats_and_flags_defaults() -> void:
	assert_true(_ok("s.kills_total == 0").eval({}, {}, {}), "missing stat = 0")
	assert_true(_ok("s.kills_total >= 10").eval({}, {"kills_total": 12}, {}))
	assert_false(_ok("s.kills_total >= 10").eval({}, {"kills_total": 9}, {}))
	assert_true(_ok("f.mop_pep_talk == false").eval({}, {}, {}), "missing flag = false")
	assert_true(_ok("f.counter == 0").eval({}, {}, {}), "missing flag = 0 for numbers")
	assert_true(_ok("f.defeated_enm_boss_hausmeister == true").eval({}, {}, {"defeated_enm_boss_hausmeister": true}))


func test_conjunction() -> void:
	var ce: ConditionExpr = _ok("e.kai_level >= 4 && f.scene_scn_mop_1 == true")
	assert_true(ce.eval({"kai_level": 4}, {}, {"scene_scn_mop_1": true}))
	assert_false(ce.eval({"kai_level": 3}, {}, {"scene_scn_mop_1": true}))
	assert_false(ce.eval({"kai_level": 5}, {}, {}))
	assert_true(_ok("true&&true && e.a==1").eval({"a": 1}, {}, {}), "whitespace optional")
	assert_eq(ce.clause_count(), 2)


func test_operands() -> void:
	var ce: ConditionExpr = _ok("e.a == 1 && s.kills_total > 2 && f.x == true && true")
	assert_eq(ce.operands(), [{"scope": "e", "key": "a"}, {"scope": "s", "key": "kills_total"}, {"scope": "f", "key": "x"}])


func test_syntax_errors() -> void:
	for src: String in ["", "   ", "e.", "x.y == 1", "e.a = 1", "e.a ==", "e.a == 1 &&", "e.a == 1 || e.b == 2",
			"e.a < \"x\"", "e.a > true", "e.a == tru", "e.a == \"unterminated", "e.A == 1", "e.a == 1.",
			"e.a == 1 e.b == 2", "true == 1", "e.a == 1x", "E.a == 1", "e.a == --1"]:
		var ce: ConditionExpr = ConditionExpr.parse(src)
		assert_ne(ce.error, "", "expected parse error for '%s'" % src)
		assert_false(ce.eval({"a": 1}, {}, {}), "erroneous expression is false: '%s'" % src)
		assert_len(ce.operands(), 0)
