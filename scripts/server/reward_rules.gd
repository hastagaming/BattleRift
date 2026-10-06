class_name RewardRules
extends RefCounted

const BASE_CR := 20
const WIN_CR := 40
const DRAW_CR := 20
const KILL_CR := 5
const MAX_CR := 150
const BASE_XP := 30
const WIN_XP := 30
const DRAW_XP := 15
const KILL_XP := 5
const MAX_XP := 200
const MAX_COUNTED_KILLS := 20
const PLACEMENT_CR := 4
const PLACEMENT_XP := 3


static func for_player(outcome: String, kills: int, forfeited: bool) -> Dictionary:
	if forfeited:
		return {"cr": 0, "xp": 0}
	var counted_kills := clampi(kills, 0, MAX_COUNTED_KILLS)
	var cr := BASE_CR + counted_kills * KILL_CR
	var xp := BASE_XP + counted_kills * KILL_XP
	match outcome:
		"win":
			cr += WIN_CR
			xp += WIN_XP
		"draw":
			cr += DRAW_CR
			xp += DRAW_XP
	return {"cr": mini(cr, MAX_CR), "xp": mini(xp, MAX_XP)}


static func for_placement(placement: int, total: int, kills: int, forfeited: bool) -> Dictionary:
	var reward := for_player("win" if placement == 1 else "loss", kills, forfeited)
	if forfeited or total < 2:
		return reward
	var beaten := clampi(total - placement, 0, total)
	reward["cr"] = mini(int(reward["cr"]) + beaten * PLACEMENT_CR, MAX_CR)
	reward["xp"] = mini(int(reward["xp"]) + beaten * PLACEMENT_XP, MAX_XP)
	return reward