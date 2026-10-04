extends Node

const GAME_NAME := "BattleRift"
const SAVE_VERSION := 1
const ALLOW_BOTS := false

const CUSTOM_ROOM_SIZES := {2: "1v1", 4: "2v2", 6: "3v3"}
const CASUAL_MODES: Array[String] = ["1v1", "2v2", "3v3"]
const MODE_TEAM_SIZE := {"1v1": 1, "2v2": 2, "3v3": 3}

const CLAN_DEFAULT_CAPACITY := 100
const CLAN_MAX_CAPACITY := 200
const CLAN_BATTLE_MAX_CLANS := 5

var battle_royal_player_count: int = 12
var matchmaking_base_range: int = 100
var matchmaking_expand_step: int = 75
var matchmaking_expand_interval: float = 10.0
var matchmaking_max_range: int = 1200


func is_valid_custom_room_size(player_count: int) -> bool:
	return CUSTOM_ROOM_SIZES.has(player_count)


func mode_for_room_size(player_count: int) -> String:
	return String(CUSTOM_ROOM_SIZES.get(player_count, ""))


func team_size_for_mode(mode: String) -> int:
	return int(MODE_TEAM_SIZE.get(mode, 0))


func validate_team_assignment(teams: Dictionary, player_count: int) -> Dictionary:
	if not is_valid_custom_room_size(player_count):
		return {"ok": false, "error": "Invalid room size"}
	var per_team: int = player_count / 2
	var count_a: int = 0
	var count_b: int = 0
	for peer_id in teams:
		match String(teams[peer_id]):
			"A":
				count_a += 1
			"B":
				count_b += 1
			_:
				return {"ok": false, "error": "Player without team"}
	if count_a + count_b != player_count:
		return {"ok": false, "error": "Room is not full"}
	if count_a != per_team or count_b != per_team:
		return {"ok": false, "error": "Teams are not balanced"}
	return {"ok": true, "error": ""}


func can_start_match(players: Dictionary, teams: Dictionary, player_count: int, host_id: Variant) -> Dictionary:
	if players.size() != player_count:
		return {"ok": false, "error": "Waiting for players"}
	if not players.has(host_id):
		return {"ok": false, "error": "Host missing"}
	for peer_id in players:
		if not bool(players[peer_id].get("ready", false)):
			return {"ok": false, "error": "Not all players are ready"}
	return validate_team_assignment(teams, player_count)