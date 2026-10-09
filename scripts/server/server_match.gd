class_name ServerMatch
extends Node

signal finished

enum Stage { GATHERING, WEAPONS, RUNNING, DONE }

const SNAPSHOT_EVERY := 3
const GATHER_TIMEOUT := 90.0
const WEAPON_TIMEOUT := 25.0
const END_LINGER := 8.0
const INPUT_TIMEOUT := 0.25
const MAX_INPUT_RATE := 90.0
const MAX_ACTION_RATE := 30.0
const EMOTE_COOLDOWN_MSEC := 1000
const RESPAWN_DELAY := 2.5
const COUNTDOWN := 3.0

var hub: NetHub
var admin: SupabaseAdmin
var key: String = ""
var room: Dictionary = {}
var persist: bool = false
var open_roster: bool = false
var stage: Stage = Stage.GATHERING
var state: MatchState
var arena: Arena

var _viewport: SubViewport
var _world: Node3D
var _members: Dictionary = {}
var _slots: Array[int] = []
var _user_slot: Dictionary = {}
var _peer_slot: Dictionary = {}
var _bodies: Dictionary = {}
var _expected: int = 2
var _stage_time: float = 0.0
var _clock: float = 0.0
var _tick: int = 0
var _state_dirty: bool = false
var _state_timer: float = 0.0
var _closing: bool = false
var _result_sent: bool = false


func _ready() -> void:
	_expected = int(room.get("capacity", 2))
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(2, 2)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.set_meta("server_match", self)
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	hub.emote_received.connect(_on_emote_request)
	if not open_roster:
		var index := 0
		for entry in room.get("members", []):
			index += 1
			var info: Dictionary = entry
			_make_member(index, String(info["user_id"]), String(info["name"]), String(info["team"]))


func _make_member(slot: int, user_id: String, display_name: String, team: String) -> void:
	_members[slot] = {
		"slot": slot,
		"user_id": user_id,
		"name": display_name,
		"team": team,
		"peer": -1,
		"connected": false,
		"skin": "default",
		"character": "rifter",
		"emote": "wave",
		"emotes": [],
		"pet": "",
		"accessories": {},
		"ratings": {},
		"owned": [],
		"equipped_weapon": "",
		"weapon": "",
		"last_seq": -1,
		"last_emote_msec": 0,
		"since_input": 0.0,
		"input_tokens": MAX_INPUT_RATE,
		"action_tokens": MAX_ACTION_RATE,
	}
	_user_slot[user_id] = slot
	_slots.append(slot)
	_slots.sort()


func add_peer(peer_id: int, identity: Dictionary) -> Dictionary:
	if _closing or stage != Stage.GATHERING:
		return {"ok": false, "error": "The match has already started"}
	var user_id := String(identity["user_id"])
	var slot := int(_user_slot.get(user_id, 0))
	if open_roster:
		if slot != 0:
			return {"ok": false, "error": "Already connected"}
		if _members.size() >= _expected:
			return {"ok": false, "error": "The match is full"}
		slot = _members.size() + 1
		while _members.has(slot):
			slot += 1
		_make_member(slot, user_id, String(identity["name"]), "A" if slot % 2 == 1 else "B")
	elif slot == 0:
		return {"ok": false, "error": "You are not part of this match"}
	var member: Dictionary = _members[slot]
	if bool(member["connected"]):
		return {"ok": false, "error": "Already connected"}
	var pet_id := String(identity.get("pet", ""))
	if pet_id.is_empty() and open_roster:
		pet_id = PetDb.ORDER[(slot - 1) % PetDb.ORDER.size()]
	var character_id := String(identity.get("character", ""))
	if open_roster and character_id.is_empty():
		character_id = CharacterDb.ORDER[(slot - 1) % CharacterDb.ORDER.size()]
	elif not CharacterDb.has(character_id):
		character_id = "rifter"
	member["connected"] = true
	member["peer"] = peer_id
	member["skin"] = String(identity["skin"])
	member["character"] = character_id
	member["emote"] = String(identity["emote"])
	member["emotes"] = identity.get("emotes", [])
	member["pet"] = pet_id
	member["accessories"] = identity["accessories"]
	member["ratings"] = identity.get("ratings", {})
	member["owned"] = identity["owned"]
	member["equipped_weapon"] = String(identity["equipped_weapon"])
	_peer_slot[peer_id] = slot
	hub.rpc_id(peer_id, "cl_auth_result", true, "")
	_check_start()
	return {"ok": true, "error": ""}


func remove_peer(peer_id: int) -> void:
	var slot := int(_peer_slot.get(peer_id, 0))
	if slot == 0:
		return
	_peer_slot.erase(peer_id)
	var member: Dictionary = _members[slot]
	member["connected"] = false
	member["peer"] = -1
	match stage:
		Stage.GATHERING:
			if open_roster:
				_user_slot.erase(String(member["user_id"]))
				_members.erase(slot)
				_slots.erase(slot)
			if connected_peers().is_empty():
				_close()
		Stage.WEAPONS:
			_abort("A player left before the match started")
		Stage.RUNNING:
			state.forfeit(slot)
			var body: PlayerController = _bodies.get(slot)
			if body != null:
				body.set_active(false)
			if connected_peers().is_empty():
				_close()
		Stage.DONE:
			if connected_peers().is_empty():
				_close()


func connected_peers() -> Array[int]:
	var result: Array[int] = []
	for slot in _slots:
		var member: Dictionary = _members[slot]
		if bool(member["connected"]):
			result.append(int(member["peer"]))
	return result


func broadcast_event(data: Dictionary) -> void:
	for peer_id in connected_peers():
		hub.rpc_id(peer_id, "cl_event", data)


func _check_start() -> void:
	if stage != Stage.GATHERING or _members.size() < _expected:
		return
	for slot in _slots:
		if not bool(_members[slot]["connected"]):
			return
	_enter_weapons()


func _enter_weapons() -> void:
	stage = Stage.WEAPONS
	_stage_time = 0.0
	arena = Arena.new()
	arena.with_environment = false
	_world.add_child(arena)
	state = MatchState.new()
	_world.add_child(state)
	state.set_process(false)
	var mode := String(room.get("mode", "stock"))
	var config := {
		"mode": mode,
		"stocks": int(room.get("stocks", 3)),
		"time_limit": float(room.get("time_limit", 0)) if mode == MatchState.MODE_UNLIMITED else 0.0,
		"respawn_delay": RESPAWN_DELAY,
		"countdown": COUNTDOWN,
	}
	var configured := state.configure(config)
	if not bool(configured["ok"]):
		_abort(String(configured["error"]))
		return
	for slot in _slots:
		var member: Dictionary = _members[slot]
		state.add_participant(slot, String(member["name"]), String(member["team"]))
	state.phase_changed.connect(_on_phase)
	state.countdown_changed.connect(_on_countdown)
	state.respawn_requested.connect(_on_respawn_requested)
	state.player_knocked_out.connect(_on_knockout)
	state.scores_changed.connect(_on_state_changed)
	state.participant_changed.connect(_on_state_changed)
	state.match_ended.connect(_on_ended)
	_spawn_bodies()
	_broadcast_setup()
	_send_state()


func _spawn_index(slot: int, team: String, team_counts: Dictionary) -> int:
	var count := int(team_counts.get(team, 0))
	team_counts[team] = count + 1
	var indices: Array = Arena.TEAM_SPAWNS.get(team, [])
	if indices.is_empty():
		return (slot - 1) % arena.spawn_points.size()
	return int(indices[count % indices.size()]) % arena.spawn_points.size()


func _spawn_bodies() -> void:
	var team_counts := {}
	for slot in _slots:
		var member: Dictionary = _members[slot]
		var spawn_index := _spawn_index(slot, String(member["team"]), team_counts)
		var body := PlayerController.new()
		body.remote_input = PlayerInput.new()
		body.peer_id = slot
		body.team = String(member["team"])
		body.auto_respawn = false
		body.emote_id = String(member["emote"])
		body.spawn_point = arena.spawn_points[spawn_index]
		body.position = body.spawn_point
		_world.add_child(body)
		body.model.apply_appearance(String(member["skin"]), String(member["character"]), member["accessories"])
		body.skill.set_character(String(member["character"]))
		body.pet.set_pet(String(member["pet"]))
		body.controllable = false
		body.fell_out.connect(_on_fell_out.bind(slot))
		body.emote_played.connect(_on_emote.bind(slot))
		body.weapons.attacked.connect(_on_attack.bind(slot))
		body.pet.triggered.connect(_on_pet.bind(slot))
		body.pet.barrier_created.connect(_on_barrier.bind(slot))
		body.skill.triggered.connect(_on_skill.bind(slot))
		_bodies[slot] = body


func _broadcast_setup() -> void:
	var roster: Array = []
	for slot in _slots:
		var member: Dictionary = _members[slot]
		roster.append({
			"slot": slot,
			"name": member["name"],
			"team": member["team"],
			"skin": member["skin"],
			"character": member["character"],
			"emote": member["emote"],
			"pet": member["pet"],
			"accessories": member["accessories"],
		})
	for slot in _slots:
		var member: Dictionary = _members[slot]
		hub.rpc_id(int(member["peer"]), "cl_setup", {
			"slot": slot,
			"mode": state.mode,
			"stocks": state.stocks_per_player,
			"time_limit": state.time_limit,
			"respawn_delay": state.respawn_delay,
			"countdown": COUNTDOWN,
			"weapon_seconds": WEAPON_TIMEOUT,
			"participants": roster,
		})


func on_weapon(peer_id: int, weapon_id: String) -> void:
	if stage != Stage.WEAPONS:
		return
	var slot := int(_peer_slot.get(peer_id, 0))
	if slot == 0:
		return
	var member: Dictionary = _members[slot]
	if not WeaponDb.has(weapon_id) or weapon_id not in member["owned"]:
		hub.rpc_id(peer_id, "cl_event", {"type": "weapon_rejected"})
		return
	member["weapon"] = weapon_id
	for other in _slots:
		if String(_members[other]["weapon"]).is_empty():
			return
	_begin_match()


func _fallback_weapon(member: Dictionary) -> String:
	var equipped := String(member["equipped_weapon"])
	if WeaponDb.has(equipped) and equipped in member["owned"]:
		return equipped
	for candidate in member["owned"]:
		if WeaponDb.has(String(candidate)):
			return String(candidate)
	return "sword"


func _begin_match() -> void:
	if stage != Stage.WEAPONS:
		return
	for slot in _slots:
		var member: Dictionary = _members[slot]
		var choice := String(member["weapon"])
		if choice.is_empty():
			choice = _fallback_weapon(member)
		var ids: Array[String] = [choice]
		(_bodies[slot] as PlayerController).weapons.set_available(ids)
	stage = Stage.RUNNING
	_stage_time = 0.0
	var started := state.begin()
	if not bool(started["ok"]):
		_abort(String(started["error"]))


func on_input(peer_id: int, seq: int, move_x: float, move_y: float, yaw: float, pitch: float, held: bool) -> void:
	var slot := int(_peer_slot.get(peer_id, 0))
	if slot == 0 or not _bodies.has(slot):
		return
	var member: Dictionary = _members[slot]
	if seq <= int(member["last_seq"]) or float(member["input_tokens"]) < 1.0:
		return
	member["input_tokens"] = float(member["input_tokens"]) - 1.0
	member["last_seq"] = seq
	member["since_input"] = 0.0
	(_bodies[slot] as PlayerController).remote_input.apply_state(Vector2(move_x, move_y), yaw, pitch, held)


func on_action(peer_id: int, action: int) -> void:
	if stage != Stage.RUNNING or not PlayerInput.is_single_action(action):
		return
	var slot := int(_peer_slot.get(peer_id, 0))
	if slot == 0 or not _bodies.has(slot):
		return
	var member: Dictionary = _members[slot]
	if float(member["action_tokens"]) < 1.0:
		return
	member["action_tokens"] = float(member["action_tokens"]) - 1.0
	(_bodies[slot] as PlayerController).remote_input.press(action)


# A player may only play emotes they own, and not more than once per second.
func _on_emote_request(peer_id: int, emote_choice: String) -> void:
	var slot := int(_peer_slot.get(peer_id, 0))
	if slot == 0 or not _bodies.has(slot) or stage != Stage.RUNNING:
		return
	var member: Dictionary = _members[slot]
	if emote_choice not in CharacterModel.EMOTES or emote_choice not in member["emotes"]:
		return
	var now := Time.get_ticks_msec()
	if now - int(member["last_emote_msec"]) < EMOTE_COOLDOWN_MSEC:
		return
	member["last_emote_msec"] = now
	var body: PlayerController = _bodies[slot]
	body.emote_id = emote_choice
	body.remote_input.press(PlayerInput.EMOTE)


func _refill_budgets(delta: float) -> void:
	for slot in _slots:
		var member: Dictionary = _members[slot]
		member["input_tokens"] = minf(float(member["input_tokens"]) + delta * MAX_INPUT_RATE, MAX_INPUT_RATE)
		member["action_tokens"] = minf(float(member["action_tokens"]) + delta * MAX_ACTION_RATE, MAX_ACTION_RATE)


func _apply_input_timeouts(delta: float) -> void:
	for slot in _slots:
		var member: Dictionary = _members[slot]
		member["since_input"] = float(member["since_input"]) + delta
		if float(member["since_input"]) > INPUT_TIMEOUT and _bodies.has(slot):
			var input: PlayerInput = (_bodies[slot] as PlayerController).remote_input
			input.apply_state(Vector2.ZERO, input.yaw, input.pitch, false)


func _physics_process(delta: float) -> void:
	if _closing:
		return
	_clock += delta
	_stage_time += delta
	_refill_budgets(delta)
	match stage:
		Stage.GATHERING:
			if _stage_time > GATHER_TIMEOUT:
				_abort("Not all players connected in time")
		Stage.WEAPONS:
			if _stage_time > WEAPON_TIMEOUT:
				_begin_match()
		Stage.RUNNING:
			state.advance(delta)
		Stage.DONE:
			if _result_sent and _stage_time > END_LINGER:
				_close()
	if arena == null or _closing:
		return
	_apply_input_timeouts(delta)
	_tick += 1
	if _tick % SNAPSHOT_EVERY == 0:
		_send_snapshot()
	_flush_state(delta)


func _on_phase(phase: int) -> void:
	_state_dirty = true
	if phase == MatchState.Phase.ACTIVE:
		for slot in _slots:
			var alive := String(state.participant(slot).get("state", "")) == MatchState.STATE_ALIVE
			(_bodies[slot] as PlayerController).controllable = alive
	elif phase == MatchState.Phase.ENDED:
		for slot in _slots:
			(_bodies[slot] as PlayerController).controllable = false


func _on_countdown(seconds_left: int) -> void:
	broadcast_event({"type": "countdown", "n": seconds_left})


func _on_state_changed(_value: Variant) -> void:
	_state_dirty = true


func _on_knockout(victim_id: int, killer_id: int) -> void:
	broadcast_event({"type": "knockout", "victim": victim_id, "killer": killer_id})


func _on_attack(weapon_id: String, slot: int) -> void:
	var windup := float(WeaponDb.get_weapon(weapon_id).get("windup", 0.0))
	broadcast_event({"type": "attack", "slot": slot, "duration": maxf(windup + 0.2, 0.15)})


func _on_emote(emote: String, slot: int) -> void:
	broadcast_event({"type": "emote", "slot": slot, "id": emote})


func _on_pet(pet_id: String, center: Vector3, slot: int) -> void:
	var pet := PetDb.get_pet(pet_id)
	if String(pet.get("kind", "")) == PetDb.KIND_BARRIER:
		return
	broadcast_event({
		"type": "pet",
		"slot": slot,
		"pet": pet_id,
		"pos": center,
		"radius": PetDb.effect_radius(pet),
	})


func _on_barrier(at: Vector3, yaw: float, duration: float, width: float, height: float, color: Color, slot: int) -> void:
	broadcast_event({
		"type": "barrier",
		"slot": slot,
		"pos": at,
		"yaw": yaw,
		"duration": duration,
		"width": width,
		"height": height,
		"color": color,
	})


func _on_skill(character_id: String, center: Vector3, slot: int) -> void:
	broadcast_event({
		"type": "skill",
		"slot": slot,
		"pos": center,
		"radius": CharacterDb.effect_radius(CharacterDb.get_skill(character_id)),
		"color": CharacterDb.color_of(character_id),
	})


func _on_fell_out(attacker: Node, slot: int) -> void:
	if state.phase != MatchState.Phase.ACTIVE:
		_on_respawn_requested(slot)
		return
	var attacker_slot := -1
	if attacker is PlayerController:
		attacker_slot = (attacker as PlayerController).peer_id
	if not state.report_knockout(slot, attacker_slot):
		_on_respawn_requested(slot)


func _pick_spawn(slot: int) -> Vector3:
	var best: Vector3 = arena.spawn_points[0]
	var best_score := -1.0
	for point in arena.spawn_points:
		var nearest := 1000.0
		for other in _slots:
			if other == slot:
				continue
			var body: PlayerController = _bodies[other]
			if body.is_active:
				nearest = minf(nearest, point.distance_to(body.global_position))
		if nearest > best_score:
			best_score = nearest
			best = point
	return best


func _on_respawn_requested(slot: int) -> void:
	var body: PlayerController = _bodies.get(slot)
	if body == null:
		return
	body.spawn_point = _pick_spawn(slot)
	body.respawn()
	body.controllable = state.phase == MatchState.Phase.ACTIVE


func _flush_state(delta: float) -> void:
	_state_timer += delta
	if _state_dirty or _state_timer >= 0.5:
		_state_dirty = false
		_state_timer = 0.0
		_send_state()


func _send_state() -> void:
	if state == null:
		return
	var data := {
		"phase": state.phase,
		"scores": state.scores,
		"participants": state.participants,
		"clock": state.clock,
	}
	for peer_id in connected_peers():
		hub.rpc_id(peer_id, "cl_state", data)


func _send_snapshot() -> void:
	var players := PackedFloat32Array()
	for slot in _slots:
		var body: PlayerController = _bodies[slot]
		var flags := 0
		if body.is_on_floor():
			flags |= SnapshotCodec.FLAG_GROUNDED
		if body.state == PlayerController.State.RAGDOLL:
			flags |= SnapshotCodec.FLAG_RAGDOLL
		if body.guard_remaining > 0.0:
			flags |= SnapshotCodec.FLAG_GUARD
		if body.is_active:
			flags |= SnapshotCodec.FLAG_ACTIVE
		SnapshotCodec.append_player(
			players,
			slot,
			body.global_position,
			body.model.rotation.y,
			Vector2(body.velocity.x, body.velocity.z).length(),
			flags,
			body.damage_percent,
			WeaponDb.ORDER.find(body.weapons.current_id),
			body.ragdoll_transform(),
			body.pet.cooldown_remaining(),
			body.skill.cooldown_remaining()
		)
	var dynamics := PackedFloat32Array()
	for node in arena.dynamics:
		var flag := 1.0
		var extra := 0.0
		if node.has_method("net_flag"):
			flag = float(node.call("net_flag"))
		if node.has_method("net_extra"):
			extra = float(node.call("net_extra"))
		SnapshotCodec.append_dynamic(dynamics, flag, node.global_transform, extra)
	var projectiles := PackedFloat32Array()
	for node in get_tree().get_nodes_in_group("projectiles"):
		var projectile := node as Projectile
		if projectile == null or projectile.get_viewport() != _viewport:
			continue
		SnapshotCodec.append_projectile(
			projectiles,
			projectile.net_id,
			WeaponDb.ORDER.find(projectile.weapon_id),
			projectile.global_position,
			projectile.linear_velocity
		)
	var snapshot := {"t": _clock, "c": state.clock, "p": players, "d": dynamics, "j": projectiles}
	for peer_id in connected_peers():
		hub.rpc_id(peer_id, "cl_snapshot", snapshot)


func _outcome_for(slot: int, final_result: Dictionary) -> String:
	if bool(final_result["draw"]):
		return "draw"
	var rows: Dictionary = final_result["participants"]
	var row: Dictionary = rows.get(slot, {})
	if String(row.get("team", "")) == String(final_result["winner_team"]):
		return "win"
	return "loss"


func _average(values: Array) -> int:
	if values.is_empty():
		return RankSystem.DEFAULT_MMR
	var total := 0
	for value in values:
		total += int(value)
	return roundi(float(total) / float(values.size()))


func _enemy_average(team_mmr: Dictionary, own_team: String) -> int:
	var enemies: Array = []
	for team in team_mmr:
		if String(team) != own_team:
			enemies.append_array(team_mmr[team])
	if enemies.is_empty():
		enemies = team_mmr.get(own_team, [])
	return _average(enemies)


# Rating changes only for ranked rooms. Casual and custom matches never touch the rating.
func _compute_ratings(final_result: Dictionary) -> Dictionary:
	var changes := {}
	if not bool(room.get("ranked", false)):
		return changes
	var context := String(room.get("context", ""))
	if not RankSystem.is_valid_context(context):
		return changes
	var rows: Dictionary = final_result["participants"]
	var team_mmr := {}
	var all_mmr: Array = []
	for slot in _slots:
		var member: Dictionary = _members[slot]
		var ratings: Dictionary = member["ratings"]
		var mmr := int(ratings.get(context, RankSystem.DEFAULT_MMR))
		var team := String(member["team"])
		if not team_mmr.has(team):
			team_mmr[team] = []
		team_mmr[team].append(mmr)
		all_mmr.append(mmr)
	for slot in _slots:
		var member: Dictionary = _members[slot]
		var ratings: Dictionary = (member["ratings"] as Dictionary).duplicate()
		var change: Dictionary
		if context == "battle_royal":
			var row: Dictionary = rows.get(slot, {})
			change = RankSystem.apply_placement_result(ratings, int(row.get("placement", _slots.size())), _slots.size(), _average(all_mmr))
		else:
			change = RankSystem.apply_team_result(ratings, context, _enemy_average(team_mmr, String(member["team"])), _outcome_for(slot, final_result))
		if bool(change.get("ok", false)):
			changes[slot] = change
	return changes


func _compute_rewards(final_result: Dictionary) -> Dictionary:
	var rows: Dictionary = final_result["participants"]
	var battle_royal := String(room.get("queue_type", "")) == "battle_royal"
	var rewards := {}
	for slot in _slots:
		var row: Dictionary = rows.get(slot, {})
		var kills := int(row.get("kills", 0))
		var forfeited := bool(row.get("forfeited", false))
		var outcome := _outcome_for(slot, final_result)
		var reward: Dictionary
		if battle_royal:
			reward = RewardRules.for_placement(int(row.get("placement", _slots.size())), _slots.size(), kills, forfeited)
		else:
			reward = RewardRules.for_player(outcome, kills, forfeited)
		reward["outcome"] = outcome
		rewards[slot] = reward
	return rewards


func _persist(final_result: Dictionary, rewards: Dictionary, changes: Dictionary) -> bool:
	var rows: Dictionary = final_result["participants"]
	var queue_type := String(room.get("queue_type", "custom"))
	var entries: Array = []
	for slot in _slots:
		var row: Dictionary = rows.get(slot, {})
		var reward: Dictionary = rewards[slot]
		var entry := {
			"user_id": String(_members[slot]["user_id"]),
			"outcome": String(reward["outcome"]),
			"kills": int(row.get("kills", 0)),
			"deaths": int(row.get("deaths", 0)),
			"cr": int(reward["cr"]),
			"xp": int(reward["xp"]),
			"duration": 0 if bool(row.get("forfeited", false)) else int(float(final_result.get("duration", 0.0))),
			"queue_type": queue_type,
		}
		if changes.has(slot):
			entry["rating_context"] = String(room.get("context", ""))
			entry["new_mmr"] = int(changes[slot]["after"])
		entries.append(entry)
	var result: Dictionary = await admin.service_rpc("apply_match_result", {
		"p_match_id": String(room["id"]),
		"p_mode": String(final_result["mode"]),
		"p_results": entries,
	})
	if not bool(result["ok"]):
		push_warning("Could not save match result: %s" % String(result["error"]))
	return bool(result["ok"])


func _on_ended(final_result: Dictionary) -> void:
	stage = Stage.DONE
	_stage_time = 0.0
	var rewards := _compute_rewards(final_result)
	var changes := _compute_ratings(final_result)
	var persisted := false
	var note := "Rewards are not saved for this match."
	if persist:
		persisted = await _persist(final_result, rewards, changes)
		note = "" if persisted else "Rewards could not be saved."
	if _closing:
		return
	for slot in _slots:
		var member: Dictionary = _members[slot]
		if not bool(member["connected"]):
			continue
		var copy := final_result.duplicate(true)
		copy["persisted"] = persisted
		copy["note"] = note
		copy["queue_type"] = String(room.get("queue_type", "custom"))
		copy["ranked"] = bool(room.get("ranked", false))
		if persisted:
			var shown := {"cr": int(rewards[slot]["cr"]), "xp": int(rewards[slot]["xp"])}
			if changes.has(slot):
				var change: Dictionary = changes[slot]
				shown["rank_delta"] = int(change["delta"])
				if bool(change["tier_changed"]):
					shown["rank_tier"] = "%s > %s" % [String(change["tier_before"]), String(change["tier_after"])]
				else:
					shown["rank_tier"] = String(change["tier_after"])
			copy["rewards"] = shown
		hub.rpc_id(int(member["peer"]), "cl_result", copy)
	_result_sent = true
	_stage_time = 0.0
	_send_state()


func _abort(reason: String) -> void:
	if _closing:
		return
	stage = Stage.DONE
	for peer_id in connected_peers():
		hub.rpc_id(peer_id, "cl_abort", reason)
	_close(0.5)


func _close(delay: float = 0.0) -> void:
	if _closing:
		return
	_closing = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	finished.emit()