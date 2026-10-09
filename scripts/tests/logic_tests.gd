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
	_test_input_validation()
	_test_snapshot_codec()
	_test_snapshot_buffer()
	_test_reward_rules()
	_test_item_db()
	_test_rank_system()
	_test_placements()
	_test_placement_rewards()
	_test_pets()
	_test_characters()
	_test_room_sizes()
	_test_clan_rules()
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


func _test_input_validation() -> void:
	var input := PlayerInput.new()
	_check(not input.apply_state(Vector2(NAN, 0.0), 0.0, 0.0, false), "non finite movement is rejected")
	_check(not input.apply_state(Vector2.ZERO, INF, 0.0, false), "non finite yaw is rejected")
	_check(input.apply_state(Vector2(5.0, 0.0), 0.0, 9.0, true), "a valid state is accepted")
	_check(input.move.length() <= 1.0001, "movement vector is clamped to unit length")
	_check(absf(input.pitch) <= PlayerInput.MAX_PITCH + 0.0001, "pitch is clamped")
	_check(PlayerInput.is_single_action(4) and PlayerInput.is_single_action(PlayerInput.PET) and PlayerInput.is_single_action(PlayerInput.ABILITY), "single known actions are accepted")
	_check(not PlayerInput.is_single_action(6) and not PlayerInput.is_single_action(0) and not PlayerInput.is_single_action(128), "combined or unknown actions are rejected")
	input.press(PlayerInput.JUMP)
	_check(input.take(PlayerInput.JUMP) and not input.take(PlayerInput.JUMP), "an action edge is consumed once")


func _test_snapshot_codec() -> void:
	var players := PackedFloat32Array()
	SnapshotCodec.append_player(players, 3, Vector3(1.0, 2.0, 3.0), 0.5, 4.0, SnapshotCodec.FLAG_ACTIVE | SnapshotCodec.FLAG_GROUNDED, 42.0, 2, Transform3D.IDENTITY)
	_check(players.size() == SnapshotCodec.PLAYER_STRIDE, "player record has the expected size")
	var record := SnapshotCodec.read_player(players, 0)
	_check(int(record["slot"]) == 3 and int(record["weapon"]) == 2, "player slot and weapon survive a round trip")
	var position: Vector3 = record["pos"]
	_check(position.is_equal_approx(Vector3(1.0, 2.0, 3.0)), "player position survives a round trip")
	_check((int(record["flags"]) & SnapshotCodec.FLAG_ACTIVE) != 0, "player flags survive a round trip")
	var dynamics := PackedFloat32Array()
	SnapshotCodec.append_dynamic(dynamics, 1.0, Transform3D(Basis(Vector3.UP, 0.7), Vector3(4.0, 5.0, 6.0)), 0.0)
	var dynamic_record := SnapshotCodec.read_dynamic(dynamics, 0)
	var dynamic_position: Vector3 = dynamic_record["pos"]
	_check(dynamic_position.is_equal_approx(Vector3(4.0, 5.0, 6.0)), "dynamic position survives a round trip")
	var dynamic_transform: Transform3D = dynamic_record["xform"]
	_check(absf(dynamic_transform.basis.get_euler().y - 0.7) < 0.001, "dynamic rotation survives a round trip")
	var projectiles := PackedFloat32Array()
	SnapshotCodec.append_projectile(projectiles, 77, 5, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.0, -10.0))
	var projectile_record := SnapshotCodec.read_projectile(projectiles, 0)
	_check(int(projectile_record["id"]) == 77 and int(projectile_record["kind"]) == 5, "projectile id and kind survive a round trip")


func _snapshot(t: float, x: float, flags: int) -> Dictionary:
	var players := PackedFloat32Array()
	SnapshotCodec.append_player(players, 1, Vector3(x, 0.0, 0.0), 0.0, 0.0, flags, 0.0, -1, Transform3D.IDENTITY)
	return {"t": t, "c": 0.0, "p": players, "d": PackedFloat32Array(), "j": PackedFloat32Array()}


func _test_snapshot_buffer() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snapshot(1.0, 0.0, SnapshotCodec.FLAG_ACTIVE), 1.0)
	buffer.push(_snapshot(2.0, 4.0, SnapshotCodec.FLAG_ACTIVE), 2.0)
	var middle := buffer.sample(1.5 + SnapshotBuffer.INTERP_DELAY)
	var middle_record := SnapshotCodec.read_player(middle["p"], 0)
	var middle_position: Vector3 = middle_record["pos"]
	_check(absf(middle_position.x - 2.0) < 0.01, "positions are interpolated between two snapshots")
	var far_buffer := SnapshotBuffer.new()
	far_buffer.push(_snapshot(1.0, 0.0, SnapshotCodec.FLAG_ACTIVE), 1.0)
	far_buffer.push(_snapshot(2.0, 10.0, SnapshotCodec.FLAG_ACTIVE), 2.0)
	var far := far_buffer.sample(1.5 + SnapshotBuffer.INTERP_DELAY)
	var far_record := SnapshotCodec.read_player(far["p"], 0)
	var far_position: Vector3 = far_record["pos"]
	_check(absf(far_position.x - 10.0) < 0.01, "a jump of more than six meters snaps instead of sliding")
	var teleport_buffer := SnapshotBuffer.new()
	teleport_buffer.push(_snapshot(1.0, 0.0, 0), 1.0)
	teleport_buffer.push(_snapshot(2.0, 4.0, SnapshotCodec.FLAG_ACTIVE), 2.0)
	var jump := teleport_buffer.sample(1.5 + SnapshotBuffer.INTERP_DELAY)
	var jump_record := SnapshotCodec.read_player(jump["p"], 0)
	var jump_position: Vector3 = jump_record["pos"]
	_check(absf(jump_position.x - 4.0) < 0.01, "an inactive player snaps instead of sliding across the arena")


func _test_reward_rules() -> void:
	var win := RewardRules.for_player("win", 2, false)
	var draw := RewardRules.for_player("draw", 2, false)
	var loss := RewardRules.for_player("loss", 2, false)
	_check(int(win["cr"]) > int(draw["cr"]) and int(draw["cr"]) > int(loss["cr"]), "a win pays more than a draw, and a draw more than a loss")
	_check(int(win["xp"]) > int(loss["xp"]), "a win gives more XP than a loss")
	var quit_early := RewardRules.for_player("loss", 5, true)
	_check(int(quit_early["cr"]) == 0 and int(quit_early["xp"]) == 0, "leaving a match early pays nothing")
	var huge := RewardRules.for_player("win", 999, false)
	_check(int(huge["cr"]) <= RewardRules.MAX_CR and int(huge["xp"]) <= RewardRules.MAX_XP, "rewards are capped")


func _test_item_db() -> void:
	var seen := {}
	var all_valid := true
	var unique := true
	var premium_weapon := false
	for entry in ItemDb.local_catalog():
		var item_id := String(entry["id"])
		if seen.has(item_id):
			unique = false
		seen[item_id] = true
		if String(entry["category"]).is_empty() or int(entry["price"]) <= 0 or String(entry["currency"]) not in ["cr", "br"]:
			all_valid = false
		if String(entry["category"]) == "weapon" and String(entry["currency"]) == "br":
			premium_weapon = true
	_check(all_valid, "every catalog entry has a category, a price and a valid currency")
	_check(unique, "catalog item ids are unique")
	_check(not premium_weapon, "weapons cannot be bought with BR")
	_check(ItemDb.slot_of("accessory", "crown") == "head" and ItemDb.slot_of("accessory", "cape") == "back", "accessories map to their slots")
	_check(ItemDb.slot_of("skin", "frost") == "skin", "non accessory items use their category as the slot")
	for starter in ["rifter", "default", "sword", "wave"]:
		_check(not ItemDb.info(starter).is_empty(), "starter item %s has display data" % starter)


func _test_rank_system() -> void:
	var rank: Node = load("res://scripts/rank/rank_system.gd").new()
	_check(rank.tier_name_for_mmr(0) == "Bronze" and rank.tier_name_for_mmr(1300) == "Gold" and rank.tier_name_for_mmr(4000) == "Rift", "mmr maps to the right tier")
	var win: Dictionary = rank.apply_team_result(rank.new_ratings(), "1v1", 800, "win")
	_check(bool(win["ok"]) and int(win["delta"]) > 0, "winning an even match raises the rating")
	var loss: Dictionary = rank.apply_team_result(rank.new_ratings(), "1v1", 800, "loss")
	_check(int(loss["delta"]) < 0, "losing an even match lowers the rating")
	var upset: Dictionary = rank.apply_team_result(rank.new_ratings(), "1v1", 1600, "win")
	_check(int(upset["delta"]) > int(win["delta"]), "beating a stronger opponent gives more rating")
	var first: Dictionary = rank.apply_placement_result(rank.new_ratings(), 1, 12, 800)
	var last: Dictionary = rank.apply_placement_result(rank.new_ratings(), 12, 12, 800)
	_check(int(first["delta"]) > 0 and int(last["delta"]) < 0, "battle royal first place gains and last place loses")
	_check(not bool(rank.apply_team_result(rank.new_ratings(), "battle_royal", 800, "win")["ok"]), "a team result cannot change the battle royal rating")
	rank.free()


func _test_placements() -> void:
	var state := _active_state({"mode": "stock", "stocks": 1, "countdown": 1.0, "respawn_delay": 1.0}, [[1, "One", "P1"], [2, "Two", "P2"], [3, "Three", "P3"]])
	state.report_knockout(3, 1)
	state.report_knockout(2, 1)
	_check(state.phase == MatchState.Phase.ENDED, "free for all ends when one player is left")
	var placements: Dictionary = state.last_result["placements"]
	_check(int(placements[1]) == 1 and int(placements[2]) == 2 and int(placements[3]) == 3, "placements follow the elimination order")
	_check(String(state.last_result["winner_team"]) == "P1", "the last player standing wins")
	state.free()


func _test_placement_rewards() -> void:
	var first := RewardRules.for_placement(1, 12, 3, false)
	var middle := RewardRules.for_placement(6, 12, 0, false)
	var last := RewardRules.for_placement(12, 12, 0, false)
	_check(int(first["cr"]) > int(middle["cr"]) and int(middle["cr"]) > int(last["cr"]), "better placements pay more")
	_check(int(RewardRules.for_placement(1, 12, 0, true)["cr"]) == 0, "leaving early pays nothing in battle royal")


func _test_pets() -> void:
	var balanced := true
	for pet_id in PetDb.ORDER:
		if not PetDb.is_balanced(PetDb.get_pet(pet_id)):
			balanced = false
	_check(balanced, "every pet respects the limits")
	_check(PetDb.ids().size() == 10, "the pet list has all ten pets")
	_check(String(ItemDb.info("pet_volt")["category"]) == "pet", "pets show up in the item database")
	_check(ItemDb.slot_of("pet", "pet_volt") == "pet", "pets use the pet slot")
	_check(not PetDb.has("volt") and not PetDb.has(""), "unknown pet ids are rejected")
	_check(PetDb.get_pet("pet_falcon")["kind"] == PetDb.KIND_PASSIVE and PetDb.get_pet("pet_catty")["kind"] == PetDb.KIND_PASSIVE, "falcon and catty are passive pets")
	_check(PetDb.get_pet("pet_creaton")["kind"] == PetDb.KIND_BARRIER, "creaton is an active pet that builds a wall")
	_check(float(PetDb.get_pet("pet_creaton")["cooldown"]) >= PetDb.MIN_COOLDOWN, "creaton has a real cooldown")
	var premium_stronger := false
	for pet_id in ["pet_shadow", "pet_riftling", "pet_creaton"]:
		var premium := PetDb.get_pet(pet_id)
		if float(premium.get("damage", 0.0)) > PetDb.MAX_DAMAGE or float(premium["cooldown"]) < PetDb.MIN_COOLDOWN:
			premium_stronger = true
	_check(not premium_stronger, "premium pets are not stronger than the limits")


func _test_characters() -> void:
	var balanced := true
	for character_id in CharacterDb.ORDER:
		if not CharacterDb.is_balanced(character_id):
			balanced = false
	_check(balanced, "every character skill and passive respects the limits")
	_check(CharacterDb.ORDER.size() == 6, "the character list has all six characters")
	_check(CharacterDb.has("rifter") and not CharacterDb.has("nobody"), "unknown character ids are rejected")
	_check(String(ItemDb.info("titan")["category"]) == "character", "characters show up in the item database")
	_check(PassiveLimits.is_valid({"hitstun": 0.9}), "a mild passive is valid")
	_check(not PassiveLimits.is_valid({"hitstun": 0.2}) and not PassiveLimits.is_valid({"unknown": 1.0}), "extreme or unknown passives are rejected")
	_check(is_equal_approx(PassiveLimits.clamp_value("knockback_taken", 0.5), 0.85), "stacked passives are clamped")


func _test_room_sizes() -> void:
	var config: Node = load("res://scripts/core/game_config.gd").new()
	var all_valid := true
	for size_value in [2, 4, 6, 8, 10, 12, 14]:
		if not config.is_valid_custom_room_size(size_value):
			all_valid = false
	_check(all_valid, "room sizes from 2 to 14 players in steps of two are valid")
	_check(not config.is_valid_custom_room_size(16) and not config.is_valid_custom_room_size(7) and not config.is_valid_custom_room_size(0), "other room sizes are rejected")
	_check(config.mode_for_room_size(14) == "7v7", "14 players is a 7v7")
	var players := {}
	var teams := {}
	for i in 14:
		players[i] = {"ready": true}
		teams[i] = "A" if i < 7 else "B"
	_check(bool(config.can_start_match(players, teams, 14, 0)["ok"]), "a full 7v7 room can start")
	teams[13] = "A"
	_check(not bool(config.can_start_match(players, teams, 14, 0)["ok"]), "an unbalanced 7v7 room cannot start")
	config.free()
	var rank: Node = load("res://scripts/rank/rank_system.gd").new()
	_check(rank.is_valid_context("7v7") and rank.new_ratings().has("5v5"), "ratings exist for every team size")
	rank.free()


func _test_clan_rules() -> void:
	_check(ClanRules.valid_name("Rift Wolves") and ClanRules.valid_name("A_b-1"), "normal clan names are accepted")
	_check(not ClanRules.valid_name("ab") and not ClanRules.valid_name("this name is far too long to use") and not ClanRules.valid_name("bad!name"), "invalid clan names are rejected")
	_check(ClanRules.valid_tag("RFT") and ClanRules.valid_tag("A1"), "normal clan tags are accepted")
	_check(not ClanRules.valid_tag("R") and not ClanRules.valid_tag("TOOLONG") and not ClanRules.valid_tag("R F"), "invalid clan tags are rejected")
	_check(ClanRules.capacity_for_level(1) == 100 and ClanRules.capacity_for_level(2) == 110, "a new clan holds 100 members and grows with its level")
	_check(ClanRules.capacity_for_level(11) == 200 and ClanRules.capacity_for_level(ClanRules.MAX_LEVEL) == 200, "clan capacity never goes above 200")
	_check(ClanRules.xp_needed(2) > ClanRules.xp_needed(1), "higher clan levels need more xp")
	_check(ClanRules.requirements_text({}) == "Open to everyone", "no requirements means an open clan")
	var gold := ClanRules.build_requirements("gold", 10, 0, true)
	_check(gold.size() == 3 and bool(gold["approval"]) and int(gold["min_br"]) == 10, "requirements are built from the form values")
	_check(ClanRules.build_requirements("", 0, 0, false).is_empty(), "empty form values give no requirements")
	_check(ClanRules.build_requirements("nonsense", 0, 0, false).is_empty(), "an unknown rank is dropped")
	var text := ClanRules.requirements_text(gold)
	_check(text.contains("Gold") and text.contains("10 BR") and text.contains("Approval"), "requirements are described in plain text")
	var rank: Node = load("res://scripts/rank/rank_system.gd").new()
	var tiers: Array = rank.get("TIERS")
	var same := tiers.size() == ClanRules.TIER_IDS.size()
	for i in mini(tiers.size(), ClanRules.TIER_IDS.size()):
		if String((tiers[i] as Dictionary)["id"]) != ClanRules.TIER_IDS[i]:
			same = false
	_check(same, "clan rank requirements use the same tiers as the rank system")
	rank.free()