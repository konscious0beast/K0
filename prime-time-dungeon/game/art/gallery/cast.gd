extends RefCounted
## Art cast sheet (03_ART §5.5): the ModelSpec of every party member and enemy of floor 1 (+ floor 2 stubs §5.7).
## Private (no class_name): used by the character gallery and test_m4_art_kit (budgets §12.1). The data files
## (party.json / enemies.json, M7) carry the same specs; the gallery additionally shows every DB entry.

## id → {"name", "role": "hero" | "enemy" | "boss", "model": ModelSpec}
const CAST: Dictionary = {
	"kai": {"name": "Kai", "role": "hero", "model": {"base": "humanoid", "scale": 1.0, "pose": "auto",
		"colors": {"primary": "#3aa9a0", "secondary": "#2e3a57", "accent": "#3b2a22", "skin": "#e8b48f", "eyes": "#1a1420"},
		"props": ["mop"]}},
	"mopsula": {"name": "Graf Mopsula", "role": "hero", "model": {"base": "pug", "scale": 1.0, "pose": "auto",
		"colors": {"primary": "#d8b98a", "secondary": "#2a2024", "accent": "#7b2cbf", "eyes": "#1a1420"},
		"props": ["cape", "monocle"]}},
	"enm_kanalratte": {"name": "Kanalratte", "role": "enemy", "model": {"base": "rodent", "scale": 0.8, "pose": "auto",
		"colors": {"primary": "#6b5b4e", "secondary": "#e88a9a", "eyes": "#ff3030"}, "props": []}},
	"enm_taubenschwarm": {"name": "Taubenschwarm", "role": "enemy", "model": {"base": "swarm", "scale": 1.0,
		"colors": {"primary": "#8c93a6", "secondary": "#5fa38e", "accent": "#e0a040", "eyes": "#ff9a2e"}, "props": []}},
	"enm_pendler": {"name": "Pendler", "role": "enemy", "model": {"base": "humanoid", "scale": 1.09,
		"colors": {"primary": "#4a4f5a", "secondary": "#4a4f5a", "accent": "#b33a3a", "skin": "#c9c2b8", "eyes": "#1a1420"},
		"props": ["newspaper_head", "briefcase"]}},
	"enm_kanalschleim": {"name": "Kanalschleim", "role": "enemy", "model": {"base": "blob", "scale": 1.0,
		"colors": {"primary": "#6fbf4a", "secondary": "#d93b3b", "eyes": "#1a1420"}, "props": []}},
	"enm_rattenschamane": {"name": "Rattenschamane", "role": "enemy", "model": {"base": "rodent", "scale": 1.3,
		"pose": "auto", "colors": {"primary": "#5a4a40", "secondary": "#e88a9a", "accent": "#3e2f5b", "eyes": "#ffe66b"},
		"props": ["staff", "cape", "bottlecap_chain"]}},
	"enm_kabelsalat": {"name": "Kabelsalat", "role": "enemy", "model": {"base": "blob", "scale": 0.6,
		"colors": {"primary": "#cfcfcf", "secondary": "#1e1e1e", "accent": "#9fe8ff", "eyes": "#9fe8ff"},
		"props": ["cable_tangle"]}},
	"enm_kellerspinne": {"name": "Kellerspinne", "role": "enemy", "model": {"base": "insect", "scale": 1.0,
		"colors": {"primary": "#2b2b33", "secondary": "#c2453a", "accent": "#c2453a", "eyes": "#ffb000"}, "props": []}},
	"enm_spruehgeist": {"name": "Sprühgeist", "role": "enemy", "model": {"base": "specter", "scale": 0.65,
		"colors": {"primary": "#e23e9b", "secondary": "#ffffff", "accent": "#4ad9d9", "eyes": "#1a1420"},
		"props": ["spray_cap"]}},
	"enm_rolltreppenkrabbe": {"name": "Rolltreppenkrabbe", "role": "enemy", "model": {"base": "insect", "scale": 1.5,
		"colors": {"primary": "#8a8f96", "secondary": "#f2c230", "accent": "#b84a2e", "eyes": "#f5f0e6"},
		"props": ["escalator_back", "claws"]}},
	"enm_rattengardist": {"name": "Rattengardist", "role": "enemy", "model": {"base": "rodent", "scale": 2.0,
		"pose": "auto", "colors": {"primary": "#4d3f36", "secondary": "#e88a9a", "accent": "#7a1f9e", "eyes": "#ff3030"},
		"props": ["helmet", "shield", "halberd"]}},
	"enm_fahrscheinfresser": {"name": "Fahrscheinfresser", "role": "enemy", "model": {"base": "robot", "scale": 1.2,
		"colors": {"primary": "#2f6fb3", "secondary": "#24578c", "accent": "#9af2ff", "eyes": "#f5f0e6"}, "props": []}},
	"enm_boss_hausmeister": {"name": "Der Hausmeister", "role": "boss", "model": {"base": "brute", "scale": 1.36,
		"colors": {"primary": "#7c8a94", "secondary": "#3e4a55", "accent": "#4a3a30", "skin": "#d9a88a", "eyes": "#1a1420"},
		"props": ["cap", "key_ring", "broom"]}},
	"enm_boss_rattenkoenigin": {"name": "Die Rattenkönigin", "role": "boss", "model": {"base": "rodent", "scale": 4.0,
		"pose": "quadruped", "colors": {"primary": "#3f3530", "secondary": "#e88a9a", "accent": "#f2eee6", "eyes": "#ff3030"},
		"props": ["ticket_crown", "cape", "staff", "rat_king_tail"]}},
	# floor 2 stubs (03_ART §5.7)
	"enm_schaufensterpuppe": {"name": "Schaufensterpuppe", "role": "enemy", "model": {"base": "humanoid", "scale": 1.0,
		"colors": {"primary": "#e8dccb", "secondary": "#e8dccb", "accent": "#e8dccb", "skin": "#e8dccb", "eyes": "#e8dccb"},
		"props": []}},
	"enm_einkaufswagen": {"name": "Einkaufswagen", "role": "enemy", "model": {"base": "robot", "scale": 0.6,
		"colors": {"primary": "#c0c6cc", "secondary": "#e8455a", "accent": "#fff2c8", "eyes": "#fff2c8"}, "props": ["cart"]}},
	"enm_rabattschild": {"name": "Rabattschild", "role": "enemy", "model": {"base": "brute", "scale": 0.8,
		"colors": {"primary": "#ffffff", "secondary": "#e8455a", "accent": "#e8455a", "skin": "#f2e0d0", "eyes": "#1a1420"},
		"props": ["discount_tag"]}},
}

## Tri / MeshInstance budgets per role (02_TECH §12.1, hull not counted).
const BUDGETS: Dictionary = {"hero": [2500, 8], "enemy": [1500, 6], "boss": [4000, 10]}


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in CAST:
		out.append(str(k))
	return out


static func model(id: String) -> Dictionary:
	return (CAST[id]["model"] as Dictionary).duplicate(true)
