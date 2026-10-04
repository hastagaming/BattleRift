class_name MatchSession
extends RefCounted

static var config: Dictionary = {}


static func practice() -> Dictionary:
	var player_name := "Rifter"
	if PlayerData.is_signed_in:
		player_name = String(PlayerData.data["profile"]["name"])
	return {
		"mode": MatchState.MODE_PRACTICE,
		"stocks": 3,
		"time_limit": 0.0,
		"respawn_delay": 2.0,
		"countdown": 3.0,
		"participants": [{"peer_id": 1, "name": player_name, "team": "A", "local": true}],
	}