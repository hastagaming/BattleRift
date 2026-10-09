class_name ClanRules
extends RefCounted

# These numbers mirror the SQL configuration (game_config and the clan functions).
const BASE_CAPACITY := 100
const CAPACITY_PER_LEVEL := 10
const MAX_CAPACITY := 200
const MAX_LEVEL := 20
const MAX_OFFICERS := 10
const MAX_DESCRIPTION := 120
const MAX_RULES := 200
const MAX_MESSAGE := 1000
const NAME_PATTERN := "^[A-Za-z0-9 _-]{3,20}$"
const TAG_PATTERN := "^[A-Za-z0-9]{2,5}$"
const TIER_IDS: Array[String] = ["bronze", "silver", "gold", "platinum", "diamond", "pro", "master", "rift"]
const TIER_NAMES := {
	"bronze": "Bronze",
	"silver": "Silver",
	"gold": "Gold",
	"platinum": "Platinum",
	"diamond": "Diamond",
	"pro": "Pro",
	"master": "Master",
	"rift": "Rift",
}


static func capacity_for_level(level: int) -> int:
	return mini(BASE_CAPACITY + CAPACITY_PER_LEVEL * (maxi(level, 1) - 1), MAX_CAPACITY)


static func xp_needed(level: int) -> int:
	return 500 + level * 250


static func _matches(pattern: String, text: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return false
	return regex.search(text) != null


static func valid_name(text: String) -> bool:
	return _matches(NAME_PATTERN, text)


static func valid_tag(text: String) -> bool:
	return _matches(TAG_PATTERN, text)


static func tier_name(tier_id: String) -> String:
	return String(TIER_NAMES.get(tier_id, tier_id.capitalize()))


static func needs_approval(requirements: Dictionary) -> bool:
	return bool(requirements.get("approval", false))


# Builds the requirement data saved on a clan. Empty or invalid values are left out.
static func build_requirements(min_rank: String, min_br: int, min_level: int, approval: bool) -> Dictionary:
	var result := {}
	if min_rank in TIER_IDS:
		result["min_rank"] = min_rank
	if min_br > 0:
		result["min_br"] = min_br
	if min_level > 0:
		result["min_level"] = min_level
	if approval:
		result["approval"] = true
	return result


static func requirements_text(requirements: Dictionary) -> String:
	var parts: Array[String] = []
	var rank_id := String(requirements.get("min_rank", ""))
	if not rank_id.is_empty():
		parts.append("Rank %s+" % tier_name(rank_id))
	var min_br := int(requirements.get("min_br", 0))
	if min_br > 0:
		parts.append("%d BR" % min_br)
	var min_level := int(requirements.get("min_level", 0))
	if min_level > 0:
		parts.append("Level %d+" % min_level)
	if needs_approval(requirements):
		parts.append("Approval required")
	if parts.is_empty():
		return "Open to everyone"
	return "  |  ".join(parts)