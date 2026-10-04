class_name SpectatorLogic
extends RefCounted


static func candidates(participants: Dictionary, local_peer: int, available: Array) -> Array[int]:
	var local_team := String(participants.get(local_peer, {}).get("team", ""))
	var teammates: Array[int] = []
	var others: Array[int] = []
	for peer_id in participants:
		var id := int(peer_id)
		if id == local_peer or id not in available:
			continue
		var entry: Dictionary = participants[peer_id]
		if String(entry.get("state", "")) != MatchState.STATE_ALIVE:
			continue
		if not local_team.is_empty() and String(entry.get("team", "")) == local_team:
			teammates.append(id)
		else:
			others.append(id)
	teammates.sort()
	others.sort()
	var result: Array[int] = []
	result.append_array(teammates)
	result.append_array(others)
	return result


static func next(list: Array, current: int, direction: int) -> int:
	if list.is_empty():
		return -1
	var index := list.find(current)
	if index < 0:
		return int(list[0]) if direction >= 0 else int(list[list.size() - 1])
	var step := 1 if direction >= 0 else -1
	return int(list[posmod(index + step, list.size())])