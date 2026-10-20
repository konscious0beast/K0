extends RefCounted
## 11-A1 (11 §4.10): PTD's own rules for the art kit's cat and its clothing props — private helper of DataValidator
## (no class_name; preloaded as ArtKitRules), run on its normalized output for the base data and for every pack:
##   1. Graf Mopsula never wears crown, ticket_crown or tiara (SpeciesRules.MOPSULA_FORBIDDEN_PROPS, 04 §2.3): his
##      party model here, the species looks for him in validators/species.gd;
##   2. no party member — neither the hero nor the companion — has the base "cat" (04 §2.3: a dog, not a cat); cats
##      are enemies or side figures only;
##   3. Kai and the persona never wear shorts, bathrobe or sandals (06 §0.3: no Liga look for Kai, no foot motif in
##      rigs) — not on his party model, not through a species look for him, not as a persona look (kind "wear") —
##      and the base content never uses sandals (no party model, enemy or species look).
##   4. A pack with a licence block is exempt for the entries it added and the fields it set (DataValidator.provenance,
##      PackLoader.owned_paths; art.json's paths are "model.…" — 11 §3.12 layer 2); a pack without a licence is
##      checked like the base data.

const SpeciesRules := preload("res://core/data/validators/species.gd")
## Rule 2: bases no party member may have.
const PARTY_FORBIDDEN_BASES: PackedStringArray = ["cat"]
## Rule 3: what Kai (party "kai", the species looks for him) and the persona (looks of kind "wear") never wear.
const KAI_FORBIDDEN_PROPS: PackedStringArray = ["shorts", "bathrobe", "sandals"]
## Rule 3: props the base content never uses.
const UNUSED_PROPS: PackedStringArray = ["sandals"]
const MOPSULA: String = "mopsula"
const KAI: String = "kai"
const WEAR_KIND: String = "wear"


static func check(v: DataValidator) -> void:
	for p: Dictionary in v._out.get("party", []):
		var id: String = str(p.get("id", ""))
		var m: Dictionary = _model(p)
		var ctx: String = "party[%s].model" % id
		if PARTY_FORBIDDEN_BASES.has(str(m.get("base", ""))) and not exempt(v, "party", id, "model.base"):
			v._err(ctx + ".base", "'%s': no party member or companion is a cat (04 §2.3; 11 §4.10 rule 2)" % m["base"])
		if exempt(v, "party", id, "model.props"):
			continue
		for prop: String in _props(m.get("props", [])):
			if id == MOPSULA and SpeciesRules.MOPSULA_FORBIDDEN_PROPS.has(prop):
				v._err(ctx + ".props", "'%s': no crown motif on Graf Mopsula (04 §2.3; 11 §4.10 rule 1)" % prop)
			elif id == KAI and KAI_FORBIDDEN_PROPS.has(prop):
				v._err(ctx + ".props", "'%s': Kai never wears it (06 §0.3; 11 §4.10 rule 3)" % prop)
			elif UNUSED_PROPS.has(prop):
				v._err(ctx + ".props", "'%s': not in the base content (11 §4.10 rule 3)" % prop)
	for e: Dictionary in v._out.get("enemies", []):
		var eid: String = str(e.get("id", ""))
		if exempt(v, "enemies", eid, "model.props"):
			continue
		for prop: String in _props(_model(e).get("props", [])):
			if UNUSED_PROPS.has(prop):
				v._err("enemies[%s].model.props" % eid, "'%s': not in the base content (11 §4.10 rule 3)" % prop)
	for s: Dictionary in v._out.get("species", []):
		var sid: String = str(s.get("id", ""))
		var hint: Dictionary = s.get("model_hint", {}) if s.get("model_hint", {}) is Dictionary else {}
		if exempt(v, "species", sid, "model_hint.props_add"):
			continue
		var for_kai: bool = _for_kai(s)
		for prop: String in _props(hint.get("props_add", [])):
			var sctx: String = "species[%s].model_hint.props_add" % sid
			if for_kai and KAI_FORBIDDEN_PROPS.has(prop):
				v._err(sctx, "'%s': Kai never wears it (06 §0.3; 11 §4.10 rule 3)" % prop)
			elif UNUSED_PROPS.has(prop):
				v._err(sctx, "'%s': not in the base content (11 §4.10 rule 3)" % prop)
	for l: Dictionary in v._out.get("looks", []):
		var lid: String = str(l.get("id", ""))
		if str(l.get("kind", "")) == WEAR_KIND and KAI_FORBIDDEN_PROPS.has(str(l.get("style", ""))) \
				and not exempt(v, "looks", lid, "style"):
			v._err("looks[%s].style" % lid, "'%s': the persona never wears it (06 §0.3; 11 §4.10 rule 3)" % l["style"])


## Is the field `path` of the entry `id` of `table` owned by a pack with a licence block (11 §3.12 layer 2)? Never for
## the base data or a pack without a licence.
static func exempt(v: DataValidator, table: String, id: String, path: String) -> bool:
	if not bool(v.provenance.get("licensed", false)):
		return false
	var owned: Variant = v.provenance.get("owned", {})
	return owned is Dictionary and PackLoader.covers(PackLoader.owned_paths(owned as Dictionary, table, id), path)


## A species look for Kai: its `for` names him or is empty (= every member, like TalentsRules.is_for_mopsula).
static func _for_kai(d: Dictionary) -> bool:
	var members: PackedStringArray = _props(d.get("for", []))
	return members.is_empty() or members.has(KAI)


static func _model(entry: Dictionary) -> Dictionary:
	return entry.get("model", {}) if entry.get("model", {}) is Dictionary else {}


## A string list of the normalized output (PackedStringArray or Array; anything else → empty).
static func _props(raw: Variant) -> PackedStringArray:
	if raw is PackedStringArray:
		return raw
	return PackedStringArray(raw as Array) if raw is Array else PackedStringArray()
