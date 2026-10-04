extends Node

const TIERS: Array[Dictionary] = [
	{"id": "bronze", "name": "Bronze", "min_mmr": 0},
	{"id": "silver", "name": "Silver", "min_mmr": 1000},
	{"id": "gold", "name": "Gold", "min_mmr": 1300},
	{"id": "platinum", "name": "Platinum", "min_mmr": 1600},
	{"id": "diamond", "name": "Diamond", "min_mmr": 1900},
	{"id": "pro", "name": "Pro", "min_mmr": 2200},
	{"id": "master", "name": "Master", "min_mmr": 2500},
	{"id": "rift", "name": "Rift", "min_mmr": 2800},
]
const CONTEXTS: Array[String] = ["1v1", "2v2", "3v3", "battle_royal"]
const DEFAULT_MMR := 800
const MAX_MMR := 4000


func new_ratings() -> Dictionary:
	var ratings := {}
	for context in CONTEXTS:
		ratings[context] = DEFAULT_MMR
	return ratings


func is_valid_context(context: String) -> bool:
	return context in CONTEXTS


func tier_index_for_mmr(mmr: int) -> int:
	var index := 0
	for i in TIERS.size():
		if mmr >= int(TIERS[i]["min_mmr"]):
			index = i
	return index


func tier_name_for_mmr(mmr: int) -> String:
	return String(TIERS[tier_index_for_mmr(mmr)]["name"])


func tier_index_by_id(tier_id: String) -> int:
	for i in TIERS.size():
		if TIERS[i]["id"] == tier_id:
			return i
	return -1


func tier_progress(mmr: int) -> float:
	var index := tier_index_for_mmr(mmr)
	if index >= TIERS.size() - 1:
		return 1.0
	var low: int = int(TIERS[index]["min_mmr"])
	var high: int = int(TIERS[index + 1]["min_mmr"])
	return clampf(float(mmr - low) / float(high - low), 0.0, 1.0)


func meets_minimum_rank(mmr: int, minimum_tier_id: String) -> bool:
	var required := tier_index_by_id(minimum_tier_id)
	if required < 0:
		return true
	return tier_index_for_mmr(mmr) >= required


func _k_factor(mmr: int) -> float:
	if mmr < 1600:
		return 32.0
	if mmr < 2200:
		return 24.0
	return 16.0


func _expected_score(own_mmr: int, opponent_mmr: int) -> float:
	return 1.0 / (1.0 + pow(10.0, float(opponent_mmr - own_mmr) / 400.0))


func _finish(ratings: Dictionary, context: String, before: int, score: float, expected: float) -> Dictionary:
	var delta := roundi(_k_factor(before) * (score - expected))
	var after := clampi(before + delta, 0, MAX_MMR)
	ratings[context] = after
	return {
		"ok": true,
		"context": context,
		"before": before,
		"after": after,
		"delta": after - before,
		"tier_before": tier_name_for_mmr(before),
		"tier_after": tier_name_for_mmr(after),
		"tier_changed": tier_index_for_mmr(before) != tier_index_for_mmr(after),
	}


func apply_team_result(ratings: Dictionary, context: String, opponent_mmr: int, outcome: String) -> Dictionary:
	if not is_valid_context(context) or context == "battle_royal":
		return {"ok": false, "error": "Invalid context"}
	var score: float
	match outcome:
		"win":
			score = 1.0
		"loss":
			score = 0.0
		"draw":
			score = 0.5
		_:
			return {"ok": false, "error": "Invalid outcome"}
	var before := int(ratings.get(context, DEFAULT_MMR))
	return _finish(ratings, context, before, score, _expected_score(before, opponent_mmr))


func apply_placement_result(ratings: Dictionary, placement: int, total_players: int, lobby_average_mmr: int) -> Dictionary:
	if total_players < 2 or placement < 1 or placement > total_players:
		return {"ok": false, "error": "Invalid placement"}
	var score := 1.0 - float(placement - 1) / float(total_players - 1)
	var before := int(ratings.get("battle_royal", DEFAULT_MMR))
	return _finish(ratings, "battle_royal", before, score, _expected_score(before, lobby_average_mmr))


func search_range(wait_seconds: float) -> int:
	var steps := int(wait_seconds / GameConfig.matchmaking_expand_interval)
	var range_value: int = GameConfig.matchmaking_base_range + steps * GameConfig.matchmaking_expand_step
	return mini(range_value, GameConfig.matchmaking_max_range)


func is_within_search_range(mmr_a: int, mmr_b: int, wait_seconds: float) -> bool:
	return absi(mmr_a - mmr_b) <= search_range(wait_seconds)