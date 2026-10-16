class_name SocialLogic
extends RefCounted

# Pure helpers for the Party and Friends screens. No nodes, so they can be tested headless.


static func initial(display_name: String) -> String:
	var trimmed := display_name.strip_edges()
	if trimmed.is_empty():
		return "?"
	return trimmed.substr(0, 1).to_upper()


static func badge_text(label: String, count: int) -> String:
	if count <= 0:
		return label
	if count > 9:
		return "%s (9+)" % label
	return "%s (%d)" % [label, count]


static func _name_key(entry: Dictionary) -> String:
	return String(entry.get("name", "")).to_lower()


# Leader first, then online players, then by name.
static func sort_members(members: Array, leader_id: String) -> Array:
	var sorted: Array = members.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_leader := String(a.get("user_id", "")) == leader_id
		var b_leader := String(b.get("user_id", "")) == leader_id
		if a_leader != b_leader:
			return a_leader
		var a_online := bool(a.get("online", false))
		var b_online := bool(b.get("online", false))
		if a_online != b_online:
			return a_online
		return SocialLogic._name_key(a) < SocialLogic._name_key(b)
	)
	return sorted


# Online friends first, then by name.
static func sort_friends(friends: Array) -> Array:
	var sorted: Array = friends.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_online := bool(a.get("online", false))
		var b_online := bool(b.get("online", false))
		if a_online != b_online:
			return a_online
		return SocialLogic._name_key(a) < SocialLogic._name_key(b)
	)
	return sorted


# The leader has no ready toggle, so only the other members count.
static func ready_progress(members: Array, leader_id: String) -> Dictionary:
	var total := 0
	var ready := 0
	for entry in members:
		var member: Dictionary = entry
		if String(member.get("user_id", "")) == leader_id:
			continue
		total += 1
		if bool(member.get("ready", false)):
			ready += 1
	return {"ready": ready, "total": total}


static func all_ready(members: Array, leader_id: String) -> bool:
	var progress := ready_progress(members, leader_id)
	return int(progress["ready"]) == int(progress["total"])


static func ready_hint(members: Array, leader_id: String) -> String:
	var progress := ready_progress(members, leader_id)
	var waiting := int(progress["total"]) - int(progress["ready"])
	if int(progress["total"]) == 0:
		return ""
	if waiting <= 0:
		return "Everyone is ready."
	return "Waiting for %d member%s to get ready." % [waiting, "" if waiting == 1 else "s"]


static func member_subtitle(member: Dictionary) -> String:
	return "Lv %d  |  %s" % [int(member.get("level", 1)), "Online" if bool(member.get("online", false)) else "Offline"]


static func member_tags(member: Dictionary, is_leader: bool, is_me: bool) -> Array[String]:
	var tags: Array[String] = []
	if is_leader:
		tags.append("LEADER")
	if is_me:
		tags.append("YOU")
	if not is_leader:
		tags.append("READY" if bool(member.get("ready", false)) else "NOT READY")
	return tags


static func friend_subtitle(friend: Dictionary) -> String:
	var text := "Lv %d  |  %s" % [int(friend.get("level", 1)), "Online" if bool(friend.get("online", false)) else "Offline"]
	if bool(friend.get("in_party", false)):
		text += "  |  In a party"
	return text


static func can_invite(friend: Dictionary) -> bool:
	return bool(friend.get("online", false)) and not bool(friend.get("in_party", false))


static func online_count(friends: Array) -> int:
	var count := 0
	for entry in friends:
		if bool((entry as Dictionary).get("online", false)):
			count += 1
	return count