extends SceneTree

# Loads the real Customize scene headless and checks the pet collection and the emote list.
# Run: godot --headless -s res://scripts/tests/customize_smoke.gd

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
	player_data.sign_in("dev", "dev-local", "Tester")
	player_data.grant_item("pet", "pet_volt")
	player_data.grant_item("pet", "pet_catty")
	var screen: Control = (load("res://scenes/customize/customize.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	screen._on_slot("pet")
	await process_frame
	var texts := _labels(screen, [])
	_check(_contains(texts, "PETS  2 / 10 collected"), "the pet tab shows the collection progress")
	_check(_contains(texts, "Static Burst: Shocks nearby players"), "an owned pet shows its ability")
	_check(_contains(texts, "Cooldown 12s") and _contains(texts, "Radius 3.2m"), "an owned pet shows its facts")
	_check(_contains(texts, "-40% knocked down time"), "a passive pet shows its bonuses")
	_check(_contains(texts, "LOCKED") and _contains(texts, "[Get in Shop]"), "pets that are not owned are locked with a shop button")
	_check(_contains(texts, "[Select]"), "an owned pet can be selected")
	screen._on_slot("emote")
	await process_frame
	texts = _labels(screen, [])
	for emote_name in ["Wave", "Attack!", "Follow Me", "Watch Out!", "Hello Mate"]:
		_check(_contains(texts, emote_name), "the emote list has %s" % emote_name)
	screen.queue_free()
	print("Finished with %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)