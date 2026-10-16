extends SceneTree

# Loads the real Social scene headless and checks the loading, error, party and friends states.
# Run: godot --headless -s res://scripts/tests/social_smoke.gd

var _failures: int = 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		_failures += 1


func _labels(node: Node, found: Array[String]) -> Array[String]:
	if node is Label:
		found.append((node as Label).text)
	if node is Button:
		found.append("[%s]" % (node as Button).text)
	for child in node.get_children():
		_labels(child, found)
	return found


func _contains(texts: Array[String], needle: String) -> bool:
	for text in texts:
		if text.contains(needle):
			return true
	return false


func _initialize() -> void:
	# Autoload names are not compile-time identifiers in a -s script, so look them up on the root.
	var player_data: Node = root.get_node("PlayerData")
	var party_service: Node = root.get_node("PartyService")
	player_data.is_signed_in = true
	player_data.remote = true
	player_data.data = {"account": {"account_id": "me", "display_name": "Me"}, "currencies": {"cr": 0, "br": 0}}
	var screen: Control = (load("res://scenes/social/social.tscn") as PackedScene).instantiate()
	# Hold the poll so the first-reply state can be observed without a race against the network.
	party_service._polling = true
	root.add_child(screen)
	await process_frame
	party_service._polling = false
	var texts := _labels(screen, [])
	_check(_contains(texts, "Loading party..."), "the party tab shows a loading state before the first reply")
	_check(_contains(texts, "[Party]") and _contains(texts, "[Friends]"), "the tabs have no badge when there is nothing pending")

	party_service.last_error = "Could not reach the server"
	party_service.state_changed.emit(party_service.state)
	await process_frame
	texts = _labels(screen, [])
	_check(_contains(texts, "Could not load your party.") and _contains(texts, "[Retry]"), "a failed first load shows an error with a Retry button")

	party_service.loaded = true
	party_service.last_error = ""
	party_service.state = {
		"party": {
			"leader_id": "me", "max": 4,
			"members": [
				{"user_id": "me", "name": "Me", "level": 7, "online": true, "ready": false},
				{"user_id": "u2", "name": "Ann", "level": 3, "online": true, "ready": true},
				{"user_id": "u3", "name": "Bob", "level": 2, "online": false, "ready": false},
			],
			"invited": [],
		},
		"invites": [{"party_id": "p9", "from_name": "Zed"}],
	}
	party_service.state_changed.emit(party_service.state)
	await process_frame
	texts = _labels(screen, [])
	_check(_contains(texts, "3 / 4"), "the party heading shows the member count")
	_check(_contains(texts, "Ready  1 / 2"), "the ready progress counts only non-leader members")
	_check(_contains(texts, "Waiting for 1 member to get ready."), "the leader sees who the party is still waiting for")
	_check(_contains(texts, "LEADER") and _contains(texts, "YOU") and _contains(texts, "NOT READY"), "member cards show tags")
	_check(_contains(texts, "[Kick]") and _contains(texts, "[Promote]"), "the leader can kick and promote other members")
	_check(_contains(texts, "Zed invited you"), "party invites are listed")
	_check(_contains(texts, "[Party (1)]"), "the Party tab shows the pending invite count")

	party_service.last_error = "Could not reach the server"
	party_service.state_changed.emit(party_service.state)
	await process_frame
	texts = _labels(screen, [])
	_check(_contains(texts, "Connection problem. Showing the last known party."), "a later failed poll keeps the party and shows a warning")

	screen.queue_free()
	print("Finished with %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)