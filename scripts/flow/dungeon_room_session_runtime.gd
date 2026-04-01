extends Node

signal session_started(session: Dictionary)
signal session_updated(session: Dictionary)
signal session_finished(session: Dictionary, finish_reason: String)

const MAX_EVENT_LOG_SIZE := 24

var _current_session: Dictionary = {}
var _last_finished_session: Dictionary = {}


func has_active_session() -> bool:
	return not _current_session.is_empty()


func get_current_session() -> Dictionary:
	return _current_session.duplicate(true)


func get_last_finished_session() -> Dictionary:
	return _last_finished_session.duplicate(true)


func start_room_session(room_context: Dictionary) -> Dictionary:
	_current_session = {
		"instance_id": String(room_context.get("instance_id", "")),
		"run_id": String(room_context.get("run_id", "")),
		"stage_index": int(room_context.get("stage_index", -1)),
		"room_scene_path": String(room_context.get("room_scene_path", "")),
		"room_id": String(room_context.get("room_id", "")),
		"room_display_name": String(room_context.get("room_display_name", "")),
		"room_type": String(room_context.get("room_type", "unknown")),
		"started_at_msec": Time.get_ticks_msec(),
		"finished_at_msec": 0,
		"finish_reason": "",
		"alive_enemy_count": -1,
		"room_cleared": false,
		"chest_opened": false,
		"opened_chest_size": -1,
		"loot_count": 0,
		"player_count": 0,
		"players": {},
		"primary_player_key": "",
		"primary_player_dead": false,
		"primary_player_name": "",
		"exit_requested": false,
		"last_event": "room_started",
		"event_log": [],
	}
	_append_event("room_started")
	session_started.emit(get_current_session())
	return get_current_session()


func finish_room_session(finish_reason: String) -> void:
	if _current_session.is_empty():
		return
	_current_session["finished_at_msec"] = Time.get_ticks_msec()
	_current_session["finish_reason"] = finish_reason
	_current_session["last_event"] = "room_finished"
	_append_event("room_finished:%s" % finish_reason)
	_last_finished_session = _current_session.duplicate(true)
	session_finished.emit(_last_finished_session.duplicate(true), finish_reason)
	_current_session.clear()


func set_room_clear_state(room_cleared: bool, alive_enemy_count: int = -1) -> void:
	if _current_session.is_empty():
		return

	var did_change: bool = bool(_current_session.get("room_cleared", false)) != room_cleared
	_current_session["room_cleared"] = room_cleared
	_current_session["alive_enemy_count"] = alive_enemy_count
	if did_change:
		_current_session["last_event"] = "room_cleared" if room_cleared else "room_uncleared"
		_append_event(_current_session["last_event"])
	_emit_session_updated()


func record_chest_opened(chest_size: int, granted_definition_ids: PackedStringArray) -> void:
	if _current_session.is_empty():
		return
	_current_session["chest_opened"] = true
	_current_session["opened_chest_size"] = chest_size
	_current_session["loot_count"] = granted_definition_ids.size()
	_current_session["last_event"] = "chest_opened"
	_append_event("chest_opened:%d:%d" % [chest_size, granted_definition_ids.size()])
	_emit_session_updated()


func upsert_player_entry(player_entry: Dictionary, make_primary: bool = false) -> void:
	if _current_session.is_empty() or player_entry.is_empty():
		return

	var player_key: String = String(player_entry.get("player_key", ""))
	if player_key.is_empty():
		return

	var players: Dictionary = (_current_session.get("players", {}) as Dictionary).duplicate(true)
	var existed: bool = players.has(player_key)
	var normalized_entry: Dictionary = player_entry.duplicate(true)
	normalized_entry["last_seen_msec"] = Time.get_ticks_msec()
	players[player_key] = normalized_entry
	_current_session["players"] = players
	_current_session["player_count"] = players.size()

	if make_primary or String(_current_session.get("primary_player_key", "")).is_empty():
		_current_session["primary_player_key"] = player_key
		_current_session["primary_player_name"] = String(normalized_entry.get("display_name", normalized_entry.get("node_name", "")))
		_current_session["primary_player_dead"] = bool(normalized_entry.get("dead", false))

	if not existed:
		_current_session["last_event"] = "player_joined"
		_append_event("player_joined:%s" % player_key)
	_emit_session_updated()


func remove_player_entry(player_key: String) -> void:
	if _current_session.is_empty() or player_key.is_empty():
		return

	var players: Dictionary = (_current_session.get("players", {}) as Dictionary).duplicate(true)
	if not players.has(player_key):
		return

	players.erase(player_key)
	_current_session["players"] = players
	_current_session["player_count"] = players.size()
	if String(_current_session.get("primary_player_key", "")) == player_key:
		_current_session["primary_player_key"] = ""
		_current_session["primary_player_name"] = ""
		_current_session["primary_player_dead"] = false
		if not players.is_empty():
			var fallback_key: String = String(players.keys()[0])
			var fallback_entry: Dictionary = players.get(fallback_key, {}) as Dictionary
			_current_session["primary_player_key"] = fallback_key
			_current_session["primary_player_name"] = String(fallback_entry.get("display_name", fallback_entry.get("node_name", "")))
			_current_session["primary_player_dead"] = bool(fallback_entry.get("dead", false))

	_current_session["last_event"] = "player_removed"
	_append_event("player_removed:%s" % player_key)
	_emit_session_updated()


func set_primary_player_death_state(dead: bool, player_name: String = "") -> void:
	if _current_session.is_empty():
		return
	set_player_death_state(String(_current_session.get("primary_player_key", "")), dead, player_name)


func set_player_death_state(player_key: String, dead: bool, player_name: String = "") -> void:
	if _current_session.is_empty() or player_key.is_empty():
		return

	var players: Dictionary = (_current_session.get("players", {}) as Dictionary).duplicate(true)
	if not players.has(player_key):
		return

	var player_entry: Dictionary = (players.get(player_key, {}) as Dictionary).duplicate(true)
	var previous_dead: bool = bool(player_entry.get("dead", false))
	player_entry["dead"] = dead
	if not player_name.is_empty():
		player_entry["display_name"] = player_name
	players[player_key] = player_entry
	_current_session["players"] = players

	if String(_current_session.get("primary_player_key", "")) == player_key:
		_current_session["primary_player_dead"] = dead
		_current_session["primary_player_name"] = String(player_entry.get("display_name", player_entry.get("node_name", "")))

	if previous_dead != dead:
		_current_session["last_event"] = "player_dead" if dead else "player_revived"
		_append_event("%s:%s" % [_current_session["last_event"], player_key])
	_emit_session_updated()


func record_exit_requested() -> void:
	if _current_session.is_empty():
		return
	if bool(_current_session.get("exit_requested", false)):
		return
	_current_session["exit_requested"] = true
	_current_session["last_event"] = "exit_requested"
	_append_event("exit_requested")
	_emit_session_updated()


func build_debug_summary_text() -> String:
	if _current_session.is_empty():
		return "SESSION NONE"

	var clear_text: String = "CLEARED" if bool(_current_session.get("room_cleared", false)) else "FIGHT"
	var chest_text: String = "CHEST OPEN" if bool(_current_session.get("chest_opened", false)) else "CHEST CLOSED"
	var death_text: String = "PLAYER DEAD" if bool(_current_session.get("primary_player_dead", false)) else "PLAYER ALIVE"
	var primary_player: Dictionary = _get_primary_player_entry()
	var player_text: String = "PLAYERS %d" % int(_current_session.get("player_count", 0))
	var build_text: String = player_text
	if not primary_player.is_empty():
		build_text = "%s | MAIN %s | SPEC %d | MASTERY %d" % [
			player_text,
			String(primary_player.get("equipped_weapon_display_name", primary_player.get("weapon_mastery_track_id", "UNARMED"))),
			int(primary_player.get("specialization_level", 0)),
			int(primary_player.get("weapon_mastery_level", 0)),
		]
	return "%s | %s | %s\n%s" % [clear_text, chest_text, death_text, build_text]


func _emit_session_updated() -> void:
	session_updated.emit(get_current_session())


func _append_event(event_text: String) -> void:
	var event_log: Array = _current_session.get("event_log", [])
	event_log.append({
		"time_msec": Time.get_ticks_msec(),
		"text": event_text,
	})
	while event_log.size() > MAX_EVENT_LOG_SIZE:
		event_log.remove_at(0)
	_current_session["event_log"] = event_log


func _get_primary_player_entry() -> Dictionary:
	if _current_session.is_empty():
		return {}
	var primary_player_key: String = String(_current_session.get("primary_player_key", ""))
	if primary_player_key.is_empty():
		return {}
	return (_current_session.get("players", {}) as Dictionary).get(primary_player_key, {}) as Dictionary
