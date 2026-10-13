extends TestCase
## Gift schema (05 §6.5, §11.4): required fields, run_bound, league_pur, floats, client_seed, sender privacy (L13),
## message keys, signature format, make_system / make_dev. Duplicates are a run property → test_m8_receive_gift.

## 05 §4.8: the delivered silver chest of the test vector (Kap. 7.4), with a well-formed signature.
func _paid_chest() -> Dictionary:
	return {"schema": 1, "gift_id": "g_01JB7Q3M0F5W8V2TQK4N6H8R9S", "source": "shop", "kind": "chest", "tier": "silver",
		"amount": 0, "sponsor_id": "", "sender": {"display_name": "", "anon": true, "sender_ref": "b_7f3a9c0d1e2f"},
		"message_key": "gift_msg_go_team", "target": {"player_id": "p_A", "run_id": "run_2Kx"},
		"event_id": "evt_2026w45_sat", "window_id": "eu", "league": "show", "load_half": 4, "effect_pm": 769,
		"roll": {"commit": "3613e6c5f82810dc73d6629a2864df33cdfdbd3e96f980122126bcfd821fd64a",
			"client_seed": "c0ffee4200000017", "nonce": 17, "log_id": "l_9f2c41d07ab3e655", "table_id": "gift_f1",
			"tables_hash": "5e2d07", "rolls": 2, "guarantee": "rare", "pity_forced": ""},
		"contents": [{"rarity": "common", "item_id": "item_ice_spray", "qty": 1},
			{"rarity": "rare", "item_id": "item_brutzel_burger", "qty": 2}],
		"run_bound": true, "deliver_by_tick": 0, "issued_at": "2026-11-07T19:42:05Z",
		"sig": "hmac-sha256:" + "5b1e".repeat(16)}


func test_make_system_is_valid() -> void:
	var g: Dictionary = Gift.make_system("spn_gluckwasser", 3, 1)
	assert_eq(Gift.validate(g), "", Gift.last_detail)
	assert_eq(g["gift_id"], "g_sys_3_1", "deterministic g_sys_<battle_n>_<k>")
	assert_eq(g["source"], "system")
	assert_eq(g["kind"], "sponsor_buff")
	assert_eq(g["effect_pm"], 1000)
	assert_eq(g["sender"], {"display_name": "", "anon": true, "sender_ref": ""})
	assert_true(g["run_bound"])
	assert_true(g.has("payload"), "02_TECH §3.5 minimum key")
	assert_eq(Gift.make_system("", 1, 0), {}, "no sponsor → no gift")


## 05 §6.3: which source may send which kind; gold carries 100 or 250 credits (dev gifts: any positive amount).
## live-integrity-9 (decision 2026-10-08, L11): "bits" is reserved — a bits gift may only be the cosmetic cheer.
func test_kinds_per_source() -> void:
	var cases: Array = [
		["gold", "shop", true], ["gold", "bits", false], ["gold", "fan", false], ["gold", "system", false],
		["chest", "shop", true], ["chest", "bits", false], ["chest", "fan", false],
		["fan_pack", "fan", true], ["fan_pack", "bits", false], ["fan_pack", "shop", false],
		["sponsor_buff", "bits", false], ["sponsor_buff", "shop", true], ["sponsor_buff", "fan", false],
		["cheer", "fan", true], ["cheer", "bits", true], ["cheer", "shop", true], ["cheer", "system", false],
	]
	for c: Array in cases:
		var g: Dictionary = _paid_chest() if c[0] == "chest" else \
			Gift.make_dev(c[0], "spn_novanet" if c[0] == "sponsor_buff" else "", 100)
		g["source"] = c[1]
		if c[1] == "system":
			g["league"] = "pur"
		elif Gift.BUYER_SOURCES.has(c[1]):
			(g["sender"] as Dictionary)["sender_ref"] = "b_0123456789ab"
		assert_eq(Gift.validate(g) == "", c[2], "%s from %s: %s" % [c[0], c[1], Gift.last_detail])
	for amount: int in [100, 250]:
		var ok: Dictionary = Gift.make_dev("gold", "", amount)
		ok["source"] = "shop"
		(ok["sender"] as Dictionary)["sender_ref"] = "b_0123456789ab"
		assert_eq(Gift.validate(ok), "", "shop gold %d" % amount)
	var odd: Dictionary = Gift.make_dev("gold", "", 150)
	assert_eq(Gift.validate(odd), "", "dev gifts may carry any amount (QA)")
	odd["source"] = "shop"
	(odd["sender"] as Dictionary)["sender_ref"] = "b_0123456789ab"
	assert_eq(Gift.validate(odd), "invalid_schema", "shop gold must be 100 or 250")


## Paid chests carry the server roll AND its result (05 §6.4 step 4, §7.4): one content entry per roll, and the roll
## count of the tier at the gift's effect factor (05 §6.6/§6.10) — else the client would roll locally.
func test_paid_chest_needs_the_server_contents() -> void:
	var empty: Dictionary = _paid_chest()
	empty["contents"] = []
	assert_eq(Gift.validate(empty), "invalid_schema", "no contents → would be rolled from the public gift stream")
	assert_has(Gift.last_detail, "server contents")
	var short: Dictionary = _paid_chest()
	(short["contents"] as Array).pop_back()
	assert_eq(Gift.validate(short), "invalid_schema", "1 entry for 2 rolls")
	var more: Dictionary = _paid_chest()
	more["roll"]["rolls"] = 3
	(more["contents"] as Array).append({"rarity": "common", "credits": 40})
	assert_eq(Gift.validate(more), "invalid_schema", "silver at effect 769 ‰ has 2 rolls, not 3")
	assert_has(Gift.last_detail, "has 3 rolls, not 2")
	var full: Dictionary = _paid_chest()
	full["load_half"] = 0
	full["effect_pm"] = 1000
	assert_eq(Gift.validate(full), "invalid_schema", "silver at full effect has 3 rolls")
	full["roll"]["rolls"] = 3
	(full["contents"] as Array).append({"rarity": "common", "credits": 40})
	assert_eq(Gift.validate(full), "", Gift.last_detail)
	var dev: Dictionary = Gift.make_dev("chest", "silver", 0)
	assert_eq(Gift.validate(dev), "", "dev/offline chests stay without contents (the core rolls)")


func test_make_dev_ids_survive_restarts() -> void:
	var re: RegEx = RegEx.create_from_string("^g_dev_[0-9a-f]{16}$")
	var a: Dictionary = Gift.make_dev("chest", "bronze", 0)
	var b: Dictionary = Gift.make_dev("chest", "bronze", 0)
	assert_not_null(re.search(str(a["gift_id"])), "random id, not a per-process counter: %s" % a["gift_id"])
	assert_ne(a["gift_id"], b["gift_id"])
	assert_eq(int(b["roll"]["nonce"]), int(a["roll"]["nonce"]) + 1, "the roll nonce does not depend on the id")


func test_make_dev_kinds_are_valid_and_unique() -> void:
	var ids: Dictionary = {}
	for args: Array in [["gold", "", 100], ["gold", "", 0], ["chest", "silver", 0], ["chest", "nonsense", 0],
			["fan_pack", "", 0], ["sponsor_buff", "spn_novanet", 0], ["cheer", "", 0]]:
		var g: Dictionary = Gift.make_dev(args[0], args[1], args[2])
		assert_eq(Gift.validate(g), "", "%s: %s" % [str(args), Gift.last_detail])
		assert_eq(g["source"], "dev")
		assert_eq(g["league"], "show", "dev gifts are external (Show-Liga)")
		assert_false(ids.has(g["gift_id"]), "unique id " + str(g["gift_id"]))
		ids[g["gift_id"]] = true
	assert_eq(Gift.make_dev("gold", "", 0)["amount"], 100, "default 100 credits")
	assert_eq(Gift.make_dev("chest", "nonsense", 0)["tier"], "bronze")
	assert_eq(Gift.make_dev("sponsor_buff", "spn_novanet", 0)["sponsor_id"], "spn_novanet")


func test_paid_chest_example_is_valid() -> void:
	assert_eq(Gift.validate(_paid_chest()), "", Gift.last_detail)
	var parsed: Variant = JSON.parse_string(JSON.stringify(_paid_chest()))
	assert_eq(Gift.validate(parsed), "", "valid after a JSON round trip (ints → floats)")


func test_required_fields() -> void:
	for key: String in Gift.REQUIRED:
		var g: Dictionary = Gift.make_dev("gold", "", 100)
		g.erase(key)
		assert_eq(Gift.validate(g), "invalid_schema", "missing " + key)
		assert_has(Gift.last_detail, key)


func test_run_bound_must_be_true() -> void:
	var g: Dictionary = Gift.make_dev("chest", "bronze", 0)
	g["run_bound"] = false
	assert_eq(Gift.validate(g), "invalid_schema", "L3: gift contents are always run-bound")
	g["run_bound"] = 1
	assert_eq(Gift.validate(g), "invalid_schema", "a bool, not a number")


func test_league_pur() -> void:
	var g: Dictionary = Gift.make_dev("gold", "", 100)
	g["league"] = "pur"
	assert_eq(Gift.validate(g), "league_pur", "external gift in the Pur-Liga")
	var sys: Dictionary = Gift.make_system("spn_krawumm", 1, 0)
	sys["league"] = "pur"
	assert_eq(Gift.validate(sys), "", "system gifts exist in both leagues")
	g["league"] = "gold"
	assert_eq(Gift.validate(g), "invalid_schema")


func test_no_floats() -> void:
	var g: Dictionary = _paid_chest()
	g["effect_pm"] = 769.5
	assert_eq(Gift.validate(g), "invalid_schema", "effect factor in integer per mille (05 §3.3 Nr. 9)")
	g = _paid_chest()
	g["payload"] = {"mult": 0.769}
	assert_eq(Gift.validate(g), "invalid_schema", "no float anywhere, also in unknown/payload fields")
	g = _paid_chest()
	(g["contents"] as Array)[1]["qty"] = 1.5
	assert_eq(Gift.validate(g), "invalid_schema")


func test_client_seed_and_roll() -> void:
	for bad: String in ["c0ffee420000001", "c0ffee42000000177", "C0FFEE4200000017", "c0ffee42zz000017"]:
		var g: Dictionary = _paid_chest()
		g["roll"]["client_seed"] = bad
		assert_eq(Gift.validate(g), "invalid_schema", "client_seed '%s' (exactly 16 [0-9a-f])" % bad)
	var g2: Dictionary = _paid_chest()
	(g2["roll"] as Dictionary).erase("client_seed")
	assert_eq(Gift.validate(g2), "invalid_schema", "client_seed is mandatory for paid chests (L8)")
	var g3: Dictionary = _paid_chest()
	g3["roll"]["log_id"] = "l_123"
	assert_eq(Gift.validate(g3), "invalid_schema", "log_id = l_ + 16 hex")
	var g4: Dictionary = _paid_chest()
	g4["roll"]["guarantee"] = "legendary"
	assert_eq(Gift.validate(g4), "invalid_schema")
	var dev_chest: Dictionary = Gift.make_dev("chest", "gold", 0)
	assert_eq(Gift.validate(dev_chest), "", "offline/dev chests need no server roll (core rolls itself)")


func test_sender_privacy_and_message_keys() -> void:
	var g: Dictionary = _paid_chest()
	g["sender"]["display_name"] = "Kai_der_Pfleger"
	assert_eq(Gift.validate(g), "invalid_schema", "anonymous senders carry no name (L13)")
	g["sender"]["anon"] = false
	assert_eq(Gift.validate(g), "", "opt-in name")
	g["sender"]["display_name"] = "x".repeat(25)
	assert_eq(Gift.validate(g), "invalid_schema", "≤ 24 characters")
	var m: Dictionary = _paid_chest()
	m["message_key"] = "Schickt mehr!"
	assert_eq(Gift.validate(m), "invalid_schema", "no free text (moderation/DSA)")
	var sys: Dictionary = Gift.make_system("spn_krawumm", 1, 0)
	sys["sender"]["sender_ref"] = "b_1"
	assert_eq(Gift.validate(sys), "invalid_schema", "system gifts have an empty sender")


func test_kind_specific_fields() -> void:
	var cases: Array = [
		["gold", "amount", 0], ["gold", "tier", "gold"], ["chest", "tier", ""], ["chest", "amount", 100],
		["sponsor_buff", "sponsor_id", ""], ["cheer", "contents", [{"rarity": "common", "credits": 5}]],
		["chest", "contents", [{"rarity": "mythic", "credits": 5}]], ["chest", "contents", [{"rarity": "rare"}]],
	]
	for c: Array in cases:
		var g: Dictionary = Gift.make_dev(c[0], "spn_novanet" if c[0] == "sponsor_buff" else "bronze", 100)
		g[c[1]] = c[2]
		assert_eq(Gift.validate(g), "invalid_schema", str(c))
	var unknown: Dictionary = Gift.make_dev("gold", "", 100)
	unknown["kind"] = "lottery"
	assert_eq(Gift.validate(unknown), "invalid_schema")
	unknown = Gift.make_dev("gold", "", 100)
	unknown["source"] = "twitter"
	assert_eq(Gift.validate(unknown), "invalid_schema")


## live-integrity-8 (05 §7.5): gifts of buyers (fan/shop/bits) carry the pseudonym sender_ref "b_" + 12 hex characters —
## the per-buyer caps depend on it; system and dev gifts may have none.
func test_buyer_gifts_need_a_sender_ref() -> void:
	var g: Dictionary = _paid_chest()
	assert_eq(Gift.validate(g), "", Gift.last_detail)
	for bad: String in ["", "b_7f3a9c", "b_0123456789AB", "x_0123456789ab", "b_0123456789abc"]:
		g["sender"]["sender_ref"] = bad
		assert_eq(Gift.validate(g), "invalid_schema", "sender_ref '%s'" % bad)
		assert_has(Gift.last_detail, "sender_ref")
	assert_eq(Gift.validate(Gift.make_dev("gold", "", 100)), "", "dev gifts: unknown sender allowed (QA)")
	assert_eq(Gift.validate(Gift.make_system("spn_krawumm", 1, 0)), "", "system: empty sender")


## live-integrity-10 (05 §6.3/§6.5): a fan_pack carries no contents or exactly one common entry; every content entry is
## bounded (qty 1..9, credits 1..1000), so forged contents cannot carry a fortune.
func test_contents_are_bounded() -> void:
	var fp: Dictionary = Gift.make_dev("fan_pack", "", 0)
	fp["contents"] = [{"rarity": "common", "item_id": "itm_bandage", "qty": 1}]
	assert_eq(Gift.validate(fp), "", Gift.last_detail)
	fp["contents"] = [{"rarity": "epic", "credits": 100000}, {"rarity": "epic", "item_id": "itm_acc_queen_crown",
		"qty": 9}]
	assert_eq(Gift.validate(fp), "invalid_schema", "forged fan_pack (reviewer probe)")
	fp["contents"] = [{"rarity": "rare", "item_id": "itm_bandage", "qty": 1}]
	assert_eq(Gift.validate(fp), "invalid_schema", "fan packs roll the common pool only")
	fp["contents"] = [{"rarity": "common", "item_id": "itm_bandage", "qty": 1}, {"rarity": "common", "credits": 5}]
	assert_eq(Gift.validate(fp), "invalid_schema", "one roll")
	var chest: Dictionary = Gift.make_dev("chest", "gold", 0)
	chest["contents"] = [{"rarity": "rare", "item_id": "itm_bandage", "qty": Gift.MAX_CONTENT_QTY + 1}]
	assert_eq(Gift.validate(chest), "invalid_schema", "qty above the stack size")
	chest["contents"] = [{"rarity": "rare", "credits": Gift.MAX_CONTENT_CREDITS + 1}]
	assert_eq(Gift.validate(chest), "invalid_schema", "credits above the largest pool entry")
	chest["contents"] = [{"rarity": "rare", "credits": Gift.MAX_CONTENT_CREDITS}]
	assert_eq(Gift.validate(chest), "", Gift.last_detail)


func test_signature_format() -> void:
	var g: Dictionary = _paid_chest()
	g["sig"] = "hmac-sha256:5b1e…"
	assert_eq(Gift.validate(g), "bad_signature", "truncated signature")
	g["sig"] = "rsa:" + "0".repeat(64)
	assert_eq(Gift.validate(g), "bad_signature")
	g.erase("sig")
	assert_eq(Gift.validate(g), "", "sig is optional before S3")


func test_reason_codes() -> void:
	assert_eq(Gift.REASONS, ["", "invalid_schema", "duplicate", "league_pur", "not_accepting", "cap_reached",
		"run_not_active", "effect_mismatch", "bad_signature", "chest_blocked", "deadline_missed", "window_closed",
		"window_full", "window_sender_limit", "wrong_target", "too_soon"], "05 §6.5, §6.9, §6.10, §6.13")
	for r: String in SponsorWindows.REASONS:
		assert_has(Gift.REASONS, r, "Sponsor-Fenster reason " + r)
	assert_eq([SponsorWindows.protocol_code("window_closed"), SponsorWindows.protocol_code("window_full"),
		SponsorWindows.protocol_code("window_sender_limit")], ["E_WINDOW_CLOSED", "E_WINDOW_FULL",
		"E_WINDOW_SENDER_LIMIT"], "05 §4.5 protocol codes")
	assert_true(Gift.is_external(Gift.make_dev("cheer", "", 0)))
	assert_false(Gift.is_external(Gift.make_system("spn_krawumm", 0, 0)))
