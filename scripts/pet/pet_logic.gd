class_name PetLogic
extends RefCounted

# Pure helpers for the pet collection screen. No nodes, so they can be tested headless.
# Every text comes from the language packs. The English text in PetDb is the fallback.


static func kind_label(pet: Dictionary) -> String:
	var kind := String(pet.get("kind", ""))
	return Loc.t_or("pet.kind.%s" % kind, Loc.t("pet.kind.generic"))


# The name of the ability in the language of the player.
static func ability_name(pet_id: String) -> String:
	var pet := PetDb.get_pet(pet_id)
	return Loc.t_or("pet.%s.ability" % pet_id, String(pet.get("ability_name", "")))


static func description(pet_id: String) -> String:
	var pet := PetDb.get_pet(pet_id)
	return Loc.t_or("pet.%s.desc" % pet_id, String(pet.get("desc", "")))


static func _seconds(value: float) -> String:
	var shown := Loc.format_number(value, 0 if is_equal_approx(value, roundf(value)) else 1)
	return Loc.t("unit.seconds", {"value": shown})


static func _meters(value: float) -> String:
	var shown := Loc.format_number(value, 0 if is_equal_approx(value, roundf(value)) else 1)
	return Loc.t("unit.meters", {"value": shown})


static func _percent_change(multiplier: float) -> String:
	var change := int(roundf((multiplier - 1.0) * 100.0))
	return "%+d%%" % change


static func _number(value: float) -> String:
	return Loc.format_number(roundf(value), 0)


static func passive_lines(passive: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if passive.has("air_accel"):
		lines.append(Loc.t("pet.passive.air_control", {"change": _percent_change(float(passive["air_accel"]))}))
	if passive.has("fall_gravity"):
		lines.append(Loc.t("pet.passive.fall_gravity", {"change": _percent_change(float(passive["fall_gravity"]))}))
	if passive.has("ragdoll_time"):
		lines.append(Loc.t("pet.passive.knocked_down_time", {"change": _percent_change(float(passive["ragdoll_time"]))}))
	if passive.has("hitstun"):
		lines.append(Loc.t("pet.passive.hit_stun", {"change": _percent_change(float(passive["hitstun"]))}))
	return lines


# Short facts shown as chips on a pet card. Only values the pet really has are listed.
static func stat_chips(pet: Dictionary) -> Array[String]:
	var chips: Array[String] = []
	if pet.is_empty():
		return chips
	if PetDb.is_passive(pet):
		return passive_lines(pet.get("passive", {}))
	if pet.has("cooldown"):
		chips.append(Loc.t("pet.stat.cooldown", {"value": _seconds(float(pet["cooldown"]))}))
	match String(pet.get("kind", "")):
		PetDb.KIND_AREA:
			chips.append(Loc.t("pet.stat.radius", {"value": _meters(float(pet.get("radius", 0.0)))}))
			if float(pet.get("damage", 0.0)) > 0.0:
				chips.append(Loc.t("pet.stat.damage", {"value": _number(float(pet["damage"]))}))
			chips.append(Loc.t("pet.stat.knockback", {"value": _number(float(pet.get("knockback", 0.0)))}))
			if String(pet.get("mode", "")) == "inward":
				chips.append(Loc.t("pet.stat.pulls_in"))
		PetDb.KIND_SLOW:
			chips.append(Loc.t("pet.stat.radius", {"value": _meters(float(pet.get("radius", 0.0)))}))
			chips.append(Loc.t("pet.stat.slows", {"percent": int(roundf((1.0 - float(pet.get("slow_factor", 1.0))) * 100.0)), "time": _seconds(float(pet.get("duration", 0.0)))}))
		PetDb.KIND_GUARD:
			chips.append(Loc.t("pet.stat.guard", {"value": _seconds(float(pet.get("duration", 0.0)))}))
		PetDb.KIND_DASH:
			chips.append(Loc.t("pet.stat.dash", {"value": _seconds(float(pet.get("duration", 0.0)))}))
			chips.append(Loc.t("pet.stat.immune", {"value": _seconds(float(pet.get("immune", 0.0)))}))
		PetDb.KIND_BARRIER:
			chips.append(Loc.t("pet.stat.wall", {"value": _seconds(float(pet.get("duration", 0.0)))}))
			chips.append(Loc.t("pet.stat.width", {"value": _meters(float(pet.get("width", 0.0)))}))
	return chips


static func collection_progress(owned: Array) -> Dictionary:
	var count := 0
	for pet_id in PetDb.ORDER:
		if pet_id in owned:
			count += 1
	return {"owned": count, "total": PetDb.ORDER.size()}


# Owned pets first, then the ones still to collect. Both keep the order of PetDb.ORDER.
static func collection_order(owned: Array) -> Array[String]:
	var ordered: Array[String] = []
	for pet_id in PetDb.ORDER:
		if pet_id in owned:
			ordered.append(pet_id)
	for pet_id in PetDb.ORDER:
		if pet_id not in owned:
			ordered.append(pet_id)
	return ordered