class_name MatchState
extends Node

signal phase_changed(phase: int)
signal roster_changed
signal countdown_changed(seconds_left: int)
signal clock_changed(seconds: float)
signal scores_changed(scores: Dictionary)
signal participant_changed(peer_id: int)
signal player_knocked_out(victim_id: int, killer_id: int)
signal respawn_requested(peer_id: int)
signal match_ended(final_result: Dictionary)

enum Phase { WAITING, COUNTDOWN, ACTIVE, ENDED }

const MODE_STOCK := "stock"
const MODE_UNLIMITED := "unlimited"
const MODE_PRACTICE := "practice"
const MODES: Array[String] = ["stock", "unlimited", "practice"]
const STATE_ALIVE := "alive"
const STATE_RESPAWNING := "respawning"
const STATE_OUT := "out"

var phase: int = Phase.WAITING
var mode: String = MODE_PRACTICE
var participants: Dictionary = {}
var scores: Dictionary = {}
var clock: float = 0.0
var stocks_per_player: int = 3
var time_limit: float = 0.0
var respawn_delay: float = 2.5
var countdown_length: float = 3.0
var last_result: Dictionary = {}

var _countdown_left: float = 0.0
var _countdown_shown: int = -1
var _clock_shown: int = -1
var _elapsed: float = 0.0
var _elimination_order: Array[int] = []


func _process(delta: float) -> void:
	advance(delta)


func configure(config: Dictionary) -> Dictionary:
	var new_mode := String(config.get("mode", MODE_PRACTICE))
	if new_mode not in MODES:
		return {"ok": false, "error": "Unknown mode"}
	if phase != Phase.WAITING:
		return {"ok": false, "error": "Match already started"}
	mode = new_mode
	stocks_per_player = clampi(int(config.get("stocks", 3)), 1, 9)
	time_limit = maxf(float(config.get("time_limit", 0.0)), 0.0)
	respawn_delay = clampf(float(config.get("respawn_delay", 2.5)), 0.5, 10.0)
	countdown_length = clampf(float(config.get("countdown", 3.0)), 0.5, 10.0)
	participants.clear()
	scores.clear()
	_elimination_order.clear()
	return {"ok": true, "error": ""}


func add_participant(peer_id: int, display_name: String, team: String) -> bool:
	if phase != Phase.WAITING or participants.has(peer_id) or team.is_empty():
		return false
	participants[peer_id] = {
		"name": display_name,
		"team": team,
		"state": STATE_ALIVE,
		"stocks": stocks_per_player if mode == MODE_STOCK else 0,
		"kills": 0,
		"deaths": 0,
		"respawn_in": 0.0,
		"forfeited": false,
	}
	if not scores.has(team):
		scores[team] = 0
	roster_changed.emit()
	return true


func participant(peer_id: int) -> Dictionary:
	return participants.get(peer_id, {})


func required_players() -> int:
	return 1 if mode == MODE_PRACTICE else 2


func can_begin() -> Dictionary:
	if phase != Phase.WAITING:
		return {"ok": false, "error": "Match already started"}
	if participants.size() < required_players():
		return {"ok": false, "error": "Waiting for players"}
	if mode == MODE_PRACTICE and participants.size() != 1:
		return {"ok": false, "error": "Practice is single player"}
	if mode != MODE_PRACTICE and scores.size() < 2:
		return {"ok": false, "error": "Waiting for an opposing team"}
	if mode == MODE_UNLIMITED and time_limit <= 0.0:
		return {"ok": false, "error": "Unlimited mode needs a timer"}
	return {"ok": true, "error": ""}


func begin() -> Dictionary:
	var check := can_begin()
	if not bool(check["ok"]):
		return check
	phase = Phase.COUNTDOWN
	_countdown_left = countdown_length
	_countdown_shown = -1
	phase_changed.emit(phase)
	return check


func advance(delta: float) -> void:
	if phase == Phase.COUNTDOWN:
		_countdown_left -= delta
		var whole := ceili(maxf(_countdown_left, 0.0))
		if whole != _countdown_shown:
			_countdown_shown = whole
			countdown_changed.emit(whole)
		if _countdown_left <= 0.0:
			_start_active()
	elif phase == Phase.ACTIVE:
		_tick_active(delta)


func _start_active() -> void:
	_elapsed = 0.0
	clock = time_limit
	_clock_shown = -1
	phase = Phase.ACTIVE
	phase_changed.emit(phase)
	_emit_clock()


func _tick_active(delta: float) -> void:
	_elapsed += delta
	for peer_id in participants.keys():
		var entry: Dictionary = participants[peer_id]
		if String(entry["state"]) != STATE_RESPAWNING:
			continue
		entry["respawn_in"] = float(entry["respawn_in"]) - delta
		if float(entry["respawn_in"]) <= 0.0:
			entry["state"] = STATE_ALIVE
			entry["respawn_in"] = 0.0
			participant_changed.emit(peer_id)
			respawn_requested.emit(peer_id)
	if time_limit > 0.0:
		clock = maxf(clock - delta, 0.0)
		_emit_clock()
		if clock <= 0.0:
			_finish_by_time()
	else:
		clock += delta
		_emit_clock()


func _emit_clock() -> void:
	var whole := int(clock)
	if whole != _clock_shown:
		_clock_shown = whole
		clock_changed.emit(clock)


func report_knockout(victim_id: int, attacker_id: int = -1) -> bool:
	if phase != Phase.ACTIVE or not participants.has(victim_id):
		return false
	var victim: Dictionary = participants[victim_id]
	if String(victim["state"]) != STATE_ALIVE:
		return false
	var killer_id := -1
	if attacker_id != victim_id and participants.has(attacker_id):
		var attacker: Dictionary = participants[attacker_id]
		if String(attacker["team"]) != String(victim["team"]):
			killer_id = attacker_id
			attacker["kills"] = int(attacker["kills"]) + 1
			var team := String(attacker["team"])
			scores[team] = int(scores.get(team, 0)) + 1
			participant_changed.emit(attacker_id)
			scores_changed.emit(scores)
	victim["deaths"] = int(victim["deaths"]) + 1
	if mode == MODE_STOCK:
		victim["stocks"] = int(victim["stocks"]) - 1
	if mode == MODE_STOCK and int(victim["stocks"]) <= 0:
		_elimination_order.append(victim_id)
		victim["state"] = STATE_OUT
		victim["respawn_in"] = 0.0
	else:
		victim["state"] = STATE_RESPAWNING
		victim["respawn_in"] = respawn_delay
	participant_changed.emit(victim_id)
	player_knocked_out.emit(victim_id, killer_id)
	if mode == MODE_STOCK:
		_check_last_team()
	return true


func forfeit(peer_id: int) -> void:
	if phase != Phase.COUNTDOWN and phase != Phase.ACTIVE:
		return
	if not participants.has(peer_id):
		return
	var entry: Dictionary = participants[peer_id]
	if String(entry["state"]) != STATE_OUT:
		_elimination_order.append(peer_id)
	entry["state"] = STATE_OUT
	entry["forfeited"] = true
	entry["stocks"] = 0
	participant_changed.emit(peer_id)
	if mode == MODE_PRACTICE:
		_finish("", false, "quit")
		return
	_check_last_team()


func _surviving_teams() -> Array[String]:
	var teams: Array[String] = []
	for peer_id in participants:
		var entry: Dictionary = participants[peer_id]
		var team := String(entry["team"])
		if String(entry["state"]) != STATE_OUT and team not in teams:
			teams.append(team)
	return teams


func _check_last_team() -> void:
	var teams := _surviving_teams()
	if teams.size() == 1:
		_finish(teams[0], false, "last_team")
	elif teams.is_empty():
		_finish("", true, "last_team")


func _finish_by_time() -> void:
	if mode == MODE_PRACTICE:
		_finish("", false, "time")
		return
	var values := {}
	if mode == MODE_STOCK:
		for peer_id in participants:
			var entry: Dictionary = participants[peer_id]
			var team := String(entry["team"])
			values[team] = int(values.get(team, 0)) + int(entry["stocks"])
	else:
		values = scores.duplicate()
	var best := -1
	var winners: Array[String] = []
	for team in values:
		var value := int(values[team])
		if value > best:
			best = value
			winners = [String(team)]
		elif value == best:
			winners.append(String(team))
	if winners.size() == 1:
		_finish(winners[0], false, "time")
	else:
		_finish("", true, "time")


func _compute_placements() -> Dictionary:
	var placements := {}
	var survivors: Array[int] = []
	for peer_id in participants:
		var entry: Dictionary = participants[peer_id]
		if String(entry["state"]) != STATE_OUT:
			survivors.append(int(peer_id))
	for peer_id in survivors:
		placements[peer_id] = 1
	var next_place := survivors.size() + 1 if not survivors.is_empty() else 1
	for i in range(_elimination_order.size() - 1, -1, -1):
		placements[_elimination_order[i]] = next_place
		next_place += 1
	return placements


func _finish(winner_team: String, is_draw: bool, reason: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	var placements := _compute_placements()
	var rows := {}
	for peer_id in participants:
		var entry: Dictionary = participants[peer_id]
		rows[peer_id] = {
			"name": entry["name"],
			"team": entry["team"],
			"kills": entry["kills"],
			"deaths": entry["deaths"],
			"stocks": entry["stocks"],
			"forfeited": entry["forfeited"],
			"placement": int(placements.get(peer_id, 0)),
		}
	last_result = {
		"mode": mode,
		"reason": reason,
		"winner_team": winner_team,
		"draw": is_draw,
		"duration": _elapsed,
		"scores": scores.duplicate(),
		"participants": rows,
		"placements": placements,
		"ranked": false,
	}
	phase_changed.emit(phase)
	match_ended.emit(last_result)


func set_clock(value: float) -> void:
	clock = value
	_emit_clock()


func apply_remote_state(data: Dictionary) -> void:
	var incoming_scores: Dictionary = data.get("scores", scores)
	var scores_differ := incoming_scores != scores
	scores = incoming_scores.duplicate()
	var incoming_participants: Dictionary = data.get("participants", participants)
	participants = incoming_participants.duplicate(true)
	clock = float(data.get("clock", clock))
	_emit_clock()
	if scores_differ:
		scores_changed.emit(scores)
	for peer_id in participants:
		participant_changed.emit(peer_id)
	var incoming_phase := int(data.get("phase", phase))
	if incoming_phase != phase:
		phase = incoming_phase
		phase_changed.emit(phase)