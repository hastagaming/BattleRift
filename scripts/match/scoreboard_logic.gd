class_name ScoreboardLogic
extends RefCounted

# Pure data shaping for the in-match scoreboard. No nodes, so it is unit-testable.


static func rows(participants: Dictionary, local_peer: int) -> Array:
	var result: Array = []
	for peer_id in participants:
		var entry: Dictionary = participants[peer_id]
		var state_name := String(entry.get("state", ""))
		result.append({
			"peer": int(peer_id),
			"name": String(entry.get("name", "?")),
			"team": String(entry.get("team", "")),
			"kills": int(entry.get("kills", 0)),
			"deaths": int(entry.get("deaths", 0)),
			"stocks": int(entry.get("stocks", 0)),
			"state": state_name,
			"out": state_name == MatchState.STATE_OUT,
			"forfeited": bool(entry.get("forfeited", false)),
			"connected": bool(entry.get("connected", true)),
			"is_local": int(peer_id) == local_peer,
		})
	result.sort_custom(_before)
	return result


static func grouped(participants: Dictionary, local_peer: int, scores: Dictionary) -> Array:
	var by_team: Dictionary = {}
	for row in rows(participants, local_peer):
		var team := String(row["team"])
		if not by_team.has(team):
			by_team[team] = []
		(by_team[team] as Array).append(row)
	var groups: Array = []
	for team in by_team:
		groups.append({"team": String(team), "score": int(scores.get(team, 0)), "rows": by_team[team]})
	groups.sort_custom(_group_before)
	return groups


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["kills"]) != int(b["kills"]):
		return int(a["kills"]) > int(b["kills"])
	if int(a["deaths"]) != int(b["deaths"]):
		return int(a["deaths"]) < int(b["deaths"])
	if String(a["name"]) != String(b["name"]):
		return String(a["name"]) < String(b["name"])
	return int(a["peer"]) < int(b["peer"])


static func _group_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score"]) != int(b["score"]):
		return int(a["score"]) > int(b["score"])
	return String(a["team"]) < String(b["team"])


static func kd_text(kills: int, deaths: int) -> String:
	if deaths <= 0:
		return "%.1f" % float(kills)
	return "%.2f" % (float(kills) / float(deaths))