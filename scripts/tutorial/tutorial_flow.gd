class_name TutorialFlow
extends RefCounted

# Step list and navigation for the interactive tutorial. Pure data and logic, no nodes.
# "match" steps run inside the practice arena and wait for a real action from the player.
# "guide" steps are information cards for features that exist in the game today.

const WHERE_MATCH := "match"
const WHERE_GUIDE := "guide"

const KIND_INFO := "info"
const KIND_MOVE := "move"
const KIND_LOOK := "look"
const KIND_JUMP := "jump"
const KIND_DASH := "dash"
const KIND_ATTACK := "attack"
const KIND_FALL := "fall"

const STEPS: Array[Dictionary] = [
	{
		"id": "welcome", "where": WHERE_GUIDE, "kind": KIND_INFO,
		"title": "Welcome to BattleRift",
		"body": "BattleRift is a physics brawler: you win by knocking opponents off the arena.\n\nThis short tutorial runs in a real practice arena with your real controls. You can skip it at any time and replay it later from Settings.",
	},
	{
		"id": "move", "where": WHERE_MATCH, "kind": KIND_MOVE,
		"title": "Move",
		"body": "Drag the left joystick to run around the arena.",
	},
	{
		"id": "look", "where": WHERE_MATCH, "kind": KIND_LOOK,
		"title": "Camera",
		"body": "Use the aim pad to turn the camera. Your movement follows the direction the camera faces.",
	},
	{
		"id": "jump", "where": WHERE_MATCH, "kind": KIND_JUMP,
		"title": "Jump",
		"body": "Tap JUMP to leave the ground.",
	},
	{
		"id": "dash", "where": WHERE_MATCH, "kind": KIND_DASH,
		"title": "Dash",
		"body": "Tap DASH for a quick burst in your moving direction. Use it to dodge or close the distance. It has a short cooldown.",
	},
	{
		"id": "attack", "where": WHERE_MATCH, "kind": KIND_ATTACK,
		"title": "Attack",
		"body": "Tap ATK to attack with your weapon. Melee weapons hit up close, ranged weapons fire projectiles or rays. You choose your weapon before every match.",
	},
	{
		"id": "damage", "where": WHERE_MATCH, "kind": KIND_INFO,
		"title": "DMG %",
		"body": "There is no health bar. Every hit adds to your DMG % (top right). The higher your DMG %, the farther the next hit sends you flying.",
	},
	{
		"id": "fall", "where": WHERE_MATCH, "kind": KIND_FALL,
		"title": "Knock-outs",
		"body": "You are knocked out when you fall off the arena. Walk off the edge now to see it. In practice you simply respawn.",
	},
	{
		"id": "score", "where": WHERE_MATCH, "kind": KIND_INFO,
		"title": "Stocks and score",
		"body": "In stock matches every player has a limited number of stocks. A knock-out costs one stock, and at zero you are out and can spectate.\n\nKnocking out an opponent scores a point for your team. The match ends when one team is left, or when the timer runs out in timed matches.",
	},
	{
		"id": "practice_done", "where": WHERE_MATCH, "kind": KIND_INFO,
		"title": "Controls done",
		"body": "That covers the controls. Next, a quick tour of rooms, friends and the rest of the game.",
	},
	{
		"id": "rooms", "where": WHERE_GUIDE, "kind": KIND_INFO,
		"title": "Play and rooms",
		"body": "Open Play to join a queue (Battle Royal, Casual or Ranked), or tap Custom Room in the lobby to create your own room.\n\nIn a room you pick the team size, choose Public or Private, and share the room code so friends can join. Everyone taps Ready, then the host starts the match.",
	},
	{
		"id": "friends", "where": WHERE_GUIDE, "kind": KIND_INFO,
		"title": "Friends and party",
		"body": "Open Social to find your friend code and add friends with theirs. Friends show up as online when they are in the game.\n\nA party lets friends queue together. Create one in Social, invite friends, and everyone taps Ready.",
	},
	{
		"id": "pets", "where": WHERE_GUIDE, "kind": KIND_INFO,
		"title": "Pets",
		"body": "Pets are companions with their own ability. Browse them in Shop, then equip one in Customize. In a match, use the PET button to trigger its ability.",
	},
	{
		"id": "clan", "where": WHERE_GUIDE, "kind": KIND_INFO,
		"title": "Clans",
		"body": "Open Clan to create a clan or ask to join one. Clan members share a tag next to their name and a clan chat.",
	},
	{
		"id": "currency", "where": WHERE_GUIDE, "kind": KIND_INFO,
		"title": "CR and BR",
		"body": "CR (Coin Rift) is the free currency you earn by playing. BR (BattleRift) is the premium currency. BR never gives a combat advantage.\n\nSpend both in Shop and unlock items in Inventory and Customize.",
	},
	{
		"id": "finish", "where": WHERE_GUIDE, "kind": KIND_INFO,
		"title": "You are ready",
		"body": "That is everything you need to start. You can replay this tutorial any time from Settings.",
	},
]

var index: int = 0

var _completed: bool = false


static func count() -> int:
	return STEPS.size()


static func clamp_index(value: int) -> int:
	return clampi(value, 0, STEPS.size() - 1)


static func first_match_index() -> int:
	for i in STEPS.size():
		if String(STEPS[i]["where"]) == WHERE_MATCH:
			return i
	return 0


static func where_of(step_index: int) -> String:
	return String(STEPS[clamp_index(step_index)]["where"])


func _init(start_index: int = 0) -> void:
	index = clamp_index(start_index)


func current() -> Dictionary:
	return STEPS[index]


func kind() -> String:
	return String(STEPS[index]["kind"])


func where() -> String:
	return String(STEPS[index]["where"])


func is_action() -> bool:
	return kind() != KIND_INFO


func is_completed() -> bool:
	return _completed or not is_action()


func can_continue() -> bool:
	return is_completed()


func can_go_back() -> bool:
	return index > 0 and String(STEPS[index - 1]["where"]) == where()


func is_last() -> bool:
	return index >= STEPS.size() - 1


func progress_text() -> String:
	return "Step %d of %d" % [index + 1, STEPS.size()]


# Reports a real action observed in the game. Returns true when it completes the current step.
func report(action_kind: String) -> bool:
	if not is_action() or _completed or action_kind != kind():
		return false
	_completed = true
	return true


# Moves to the next step. Returns {"ok", "finished", "scene_changed"}.
func advance() -> Dictionary:
	if not can_continue():
		return {"ok": false, "finished": false, "scene_changed": false}
	if is_last():
		return {"ok": true, "finished": true, "scene_changed": false}
	var previous_where := where()
	index += 1
	_completed = false
	return {"ok": true, "finished": false, "scene_changed": where() != previous_where}


func back() -> bool:
	if not can_go_back():
		return false
	index -= 1
	_completed = false
	return true