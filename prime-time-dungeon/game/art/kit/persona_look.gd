# STUB(K0) — owned by 08-K2. Replace completely, keep the public API.
class_name PersonaLook extends RefCounted
## The persona's look on the kai model (08 §6.1–6.3): pure merge of the look ids (looks.json: hair style, hair
## colour, skin tone, beard, glasses, outfit) into a ModelSpec. DB.party_model is its only caller. Stub: the model
## unchanged (the canon look is the data model).


## A copy of `model` with the look applied. Stub: an unchanged copy.
static func apply(model: Dictionary, _look: Dictionary, _data: GameData) -> Dictionary:
	return model.duplicate(true)
