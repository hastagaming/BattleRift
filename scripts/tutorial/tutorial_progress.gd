class_name TutorialProgress
extends RefCounted

# Pure rules for the tutorial progress stored in the player's settings (players.settings.tutorial).
# Reading and writing that setting is done by TutorialStore.

const KEY := "tutorial"
const VERSION := 1
const STATUS_ACTIVE := "active"
const STATUS_DONE := "done"
const STATUS_SKIPPED := "skipped"


static func entry(data: Dictionary) -> Dictionary:
	var settings: Variant = data.get("settings", {})
	if not settings is Dictionary:
		return {}
	var value: Variant = (settings as Dictionary).get(KEY, {})
	return value if value is Dictionary else {}


static func status(data: Dictionary) -> String:
	return String(entry(data).get("status", ""))


static func saved_index(data: Dictionary) -> int:
	return TutorialFlow.clamp_index(int(entry(data).get("step", 0)))


# New accounts and accounts with an unfinished tutorial are sent to the tutorial.
# Accounts that already played (matches, level or XP) are never forced into it.
static func needs_tutorial(data: Dictionary) -> bool:
	match status(data):
		STATUS_DONE, STATUS_SKIPPED:
			return false
		STATUS_ACTIVE:
			return true
	var stats: Variant = data.get("stats", {})
	var profile: Variant = data.get("profile", {})
	var matches := int((stats as Dictionary).get("matches", 0)) if stats is Dictionary else 0
	var level := int((profile as Dictionary).get("level", 1)) if profile is Dictionary else 1
	var xp := int((profile as Dictionary).get("xp", 0)) if profile is Dictionary else 0
	return matches == 0 and level <= 1 and xp == 0