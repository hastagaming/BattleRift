extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_waiting_for_humans()
	_test_stock_last_team_wins()
	_test_stock_timeout()
	_test_unlimited_score_and_respawn()
	_test_unlimited_draw()
	_test_friendly_fire_gives_no_credit()
	_test_practice_quit()
	_test_spectator_candidates()
	_test_spectator_cycle()
	_test_room_start_rules()
	print("Finished with %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  %s" % label)
	else:
		_failures += 1
		printerr("FAIL  %s" % label)


func _stock_config(limit: float = 0.0) -> Dictionary:
	return {"mode": "stock", "stocks": 3, "time_limit": limit, "respawn_delay": 1.0, "countdown": 1.0}


func _unlimited_config() -> Dictionary:
	return {"mode": "unlimited", "time_limit": 10.0, "respawn_delay": 1.0, "countdown": 1.0}


func _active_state(config: Dictionary, roster: Array) -> MatchState:
	var state := MatchState.new()
	state.configure(config)
	for entry in roster:
		state.add_participant(int(entry[0]), String(entry[1]), String(entry[2]))
	state.begin()
	state.advance(2.0)
	return state


func _test_waiting_for_humans() -> void:
	var state := MatchState.new()
	state.configure(_stock_config())
	state.add_participant(1, "One", "A")
	_check(not bool(state.can_begin()["ok"]), "stock match waits for a second human")
	_check(not bool(state.begin()["ok"]), "begin is refused while waiting")
	state.add_participant(2, "Two", "A")
	_check(not bool(state.can_begin()["ok"]), "two players on one team cannot start")
	state.free()


func _test_stock_last_team_wins() -> void:
	var state := _active_state(_stock_config(), [[1, "One", "A"], [2, "Two", "B"]])
	_check(state.phase == MatchState.Phase.ACTIVE, "countdown reaches active phase")
	for i in 3:
		state.report_knockout(2, 1)
		state.advance(1.1)
	_check(state.phase == MatchState.Phase.ENDED, "stock match ends when last stock is lost")
	_check(String(state.last_result["winner_team"]) == "A", "surviving team wins")
	_check(int(state.last_result["participants"][1]["kills"]) == 3, "kills are counted")
	state.free()


func _test_stock_timeout() -> void:
	var state := _active_state(_stock_config(10.0), [[1, "One", "A"], [2, "Two", "B"]])
	state.report_knockout(2, 1)
	state.advance(11.0)
	_check(state.phase == MatchState.Phase.ENDED, "timed stock match ends at zero")
	_check(String(state.last_result["winner_team"]) == "A", "team with more stocks wins on time")
	state.free()


func _test_unlimited_score_and_respawn() -> void:
	var state := _active_state(_unlimited_config(), [[1, "One", "A"], [2, "Two", "B"]])
	var respawns: Array[int] = []
	state.respawn_requested.connect(func(peer_id: int) -> void: respawns.append(peer_id))
	state.report_knockout(2, 1)
	_check(int(state.scores["A"]) == 1, "kill adds a team point")
	state.advance(1.1)
	_check(respawns == [2], "knocked out player is respawned after the delay")
	state.advance(11.0)
	_check(String(state.last_result["winner_team"]) == "A", "higher score wins when the timer ends")
	state.free()


func _test_unlimited_draw() -> void:
	var state := _active_state(_unlimited_config(), [[1, "One", "A"], [2, "Two", "B"]])
	state.advance(11.0)
	_check(bool(state.last_result["draw"]), "equal score at zero is a draw")
	state.free()


func _test_friendly_fire_gives_no_credit() -> void:
	var state := _active_state(_unlimited_config(), [[1, "One", "A"], [3, "Three", "A"], [2, "Two", "B"]])
	state.report_knockout(1, 3)
	state.report_knockout(1, 1)
	_check(int(state.scores["A"]) == 0, "teammates and self-falls give no points")
	_check(int(state.scores["B"]) == 0, "scores stay unchanged for the other team")
	state.free()


func _test_practice_quit() -> void:
	var state := _active_state({"mode": "practice", "countdown": 1.0}, [[1, "One", "A"]])
	state.forfeit(1)
	_check(state.phase == MatchState.Phase.ENDED, "practice ends when the player leaves")
	_check(String(state.last_result["reason"]) == "quit", "practice result records the reason")
	_check(not bool(state.last_result["draw"]), "practice is not a draw")
	state.free()


func _same(list: Array, expected: Array) -> bool:
	if list.size() != expected.size():
		return false
	for i in list.size():
		if int(list[i]) != int(expected[i]):
			return false
	return true


func _test_spectator_candidates() -> void:
	var participants := {
		1: {"team": "A", "state": "out"},
		2: {"team": "A", "state": "alive"},
		3: {"team": "B", "state": "alive"},
		4: {"team": "A", "state": "respawning"},
		5: {"team": "B", "state": "alive"},
		6: {"team": "A", "state": "alive"},
	}
	_check(_same(SpectatorLogic.candidates(participants, 1, [2, 3, 4, 5, 6]), [2, 6, 3, 5]), "teammates come first, dead and respawning players are skipped")
	_check(_same(SpectatorLogic.candidates(participants, 1, [3, 5]), [3, 5]), "players without a body cannot be spectated")
	_check(SpectatorLogic.candidates({}, 1, []).is_empty(), "nobody to spectate gives an empty list")


func _test_spectator_cycle() -> void:
	var list := [2, 3, 5]
	_check(SpectatorLogic.next(list, -1, 1) == 2, "first target is picked when nothing is selected")
	_check(SpectatorLogic.next(list, 2, 1) == 3, "next target moves forward")
	_check(SpectatorLogic.next(list, 5, 1) == 2, "next target wraps to the start")
	_check(SpectatorLogic.next(list, 2, -1) == 5, "previous target wraps to the end")
	_check(SpectatorLogic.next(list, 9, -1) == 5, "a lost target falls back to the last candidate when going back")
	_check(SpectatorLogic.next([], 2, 1) == -1, "no candidates gives no target")


func _test_room_start_rules() -> void:
	var config: Node = load("res://scripts/core/game_config.gd").new()
	var players := {"u1": {"ready": true}, "u2": {"ready": false}}
	var teams := {"u1": "A", "u2": "B"}
	_check(not bool(config.can_start_match(players, teams, 2, "u1")["ok"]), "start is blocked while someone is not ready")
	players["u2"]["ready"] = true
	_check(bool(config.can_start_match(players, teams, 2, "u1")["ok"]), "start is allowed when everyone is ready and teams are balanced")
	teams["u2"] = "A"
	_check(not bool(config.can_start_match(players, teams, 2, "u1")["ok"]), "start is blocked when teams are unbalanced")
	_check(not bool(config.can_start_match({"u1": {"ready": true}}, {"u1": "A"}, 2, "u1")["ok"]), "start is blocked while the room is not full")
	_check(config.is_valid_custom_room_size(2) and config.is_valid_custom_room_size(4) and config.is_valid_custom_room_size(6), "room sizes 2, 4 and 6 are valid")
	_check(not config.is_valid_custom_room_size(3) and not config.is_valid_custom_room_size(5), "room sizes 3 and 5 are rejected")
	config.free()