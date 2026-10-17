class_name PetLogic
extends RefCounted

# Pure helpers for the pet collection screen. No nodes, so they can be tested headless.

const KIND_LABELS := {
	"area": "BURST",
	"slow": "CHILL",
	"guard": "GUARD",
	"dash": "DASH",
	"barrier": "WALL",
	"passive": "PASSIVE",
}


static func kind_label(pet: Dictionary) -> String:
	return String(KIND_LABELS.get(String(pet.get("kind", "")), "PET"))


static func _seconds(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%ds" % int(value)
	return "%.1fs" % value


static func _meters(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%dm" % int(value)
	return "%.1fm" % value


static func _percent_change(multiplier: float) -> String:
	var change := int(roundf((multiplier - 1.0) * 100.0))
	return "%+d%%" % change


static func passive_lines(passive: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if passive.has("air_accel"):
		lines.append("%s air control" % _percent_change(float(passive["air_accel"])))
	if passive.has("fall_gravity"):
		lines.append("%s fall gravity" % _percent_change(float(passive["fall_gravity"])))
	if passive.has("ragdoll_time"):
		lines.append("%s knocked down time" % _percent_change(float(passive["ragdoll_time"])))
	if passive.has("hitstun"):
		lines.append("%s hit stun" % _percent_change(float(passive["hitstun"])))
	return lines


# Short facts shown as chips on a pet card. Only values the pet really has are listed.
static func stat_chips(pet: Dictionary) -> Array[String]:
	var chips: Array[String] = []
	if pet.is_empty():
		return chips
	if PetDb.is_passive(pet):
		return passive_lines(pet.get("passive", {}))
	if pet.has("cooldown"):
		chips.append("Cooldown %s" % _seconds(float(pet["cooldown"])))
	match String(pet.get("kind", "")):
		PetDb.KIND_AREA:
			chips.append("Radius %s" % _meters(float(pet.get("radius", 0.0))))
			if float(pet.get("damage", 0.0)) > 0.0:
				chips.append("Damage %d" % int(roundf(float(pet["damage"]))))
			chips.append("Knockback %d" % int(roundf(float(pet.get("knockback", 0.0)))))
			if String(pet.get("mode", "")) == "inward":
				chips.append("Pulls in")
		PetDb.KIND_SLOW:
			chips.append("Radius %s" % _meters(float(pet.get("radius", 0.0))))
			chips.append("Slows %d%% for %s" % [int(roundf((1.0 - float(pet.get("slow_factor", 1.0))) * 100.0)), _seconds(float(pet.get("duration", 0.0)))])
		PetDb.KIND_GUARD:
			chips.append("Guard %s" % _seconds(float(pet.get("duration", 0.0))))
		PetDb.KIND_DASH:
			chips.append("Dash %s" % _seconds(float(pet.get("duration", 0.0))))
			chips.append("Immune %s" % _seconds(float(pet.get("immune", 0.0))))
		PetDb.KIND_BARRIER:
			chips.append("Wall %s" % _seconds(float(pet.get("duration", 0.0))))
			chips.append("Width %s" % _meters(float(pet.get("width", 0.0))))
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