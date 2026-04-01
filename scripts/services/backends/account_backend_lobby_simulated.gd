extends Node

signal session_changed(username: String)
signal profile_changed(snapshot: Dictionary)

const BACKEND_ID := "lobby_simulated"
const SIMULATOR_PATH := "/root/LobbyServerSimulator"


func _ready() -> void:
	call_deferred("_connect_simulator_signals")


func get_backend_id() -> String:
	return BACKEND_ID


func is_logged_in() -> bool:
	return bool(_request_value("is_logged_in", [], false))


func get_current_username() -> String:
	return String(_request_value("get_current_username", [], ""))


func get_current_display_name() -> String:
	return String(_request_value("get_current_display_name", [], "Adventurer"))


func register_account(username: String, password: String) -> Dictionary:
	return _request_value("register_account", [username, password], {}) as Dictionary


func login_account(username: String, password: String) -> Dictionary:
	return _request_value("login_account", [username, password], {}) as Dictionary


func logout() -> void:
	_request_value("logout")


func get_current_profile_state() -> Dictionary:
	return _request_value("get_current_profile_state", [], {}) as Dictionary


func get_current_profile_snapshot() -> Dictionary:
	return _request_value("get_current_profile_snapshot", [], {}) as Dictionary


func get_current_specialization_level() -> int:
	return int(_request_value("get_current_specialization_level", [], PlayerAttributeProfile.DEFAULT_SPECIALIZATION_LEVEL))


func get_current_specialization_exp() -> int:
	return int(_request_value("get_current_specialization_exp", [], PlayerAttributeProfile.DEFAULT_SPECIALIZATION_EXP))


func get_current_specialization_exp_to_next_level() -> int:
	return int(_request_value("get_current_specialization_exp_to_next_level", [], 100))


func get_current_weapon_mastery_level(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_request_value("get_current_weapon_mastery_level", [track_id], PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_LEVEL))


func get_current_weapon_mastery_exp(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_request_value("get_current_weapon_mastery_exp", [track_id], PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_EXP))


func get_current_weapon_mastery_exp_to_next_level(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_request_value("get_current_weapon_mastery_exp_to_next_level", [track_id], 80))


func add_specialization_levels(amount: int) -> void:
	_request_value("add_specialization_levels", [amount])


func add_specialization_exp(amount: int) -> void:
	_request_value("add_specialization_exp", [amount])


func add_weapon_mastery_levels(track_id: String, amount: int) -> void:
	_request_value("add_weapon_mastery_levels", [track_id, amount])


func add_weapon_mastery_exp(track_id: String, amount: int) -> void:
	_request_value("add_weapon_mastery_exp", [track_id, amount])


func overwrite_current_profile_state(state: Dictionary) -> void:
	_request_value("overwrite_current_profile_state", [state])


func add_free_stat_points(amount: int) -> void:
	_request_value("add_free_stat_points", [amount])


func allocate_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	return bool(_request_value("allocate_free_stat_points", [attribute_id, amount], false))


func refund_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	return bool(_request_value("refund_free_stat_points", [attribute_id, amount], false))


func get_current_inventory_state() -> Dictionary:
	return _request_value("get_current_inventory_state", [], {}) as Dictionary


func overwrite_current_inventory_state(state: Dictionary) -> void:
	_request_value("overwrite_current_inventory_state", [state])


func _connect_simulator_signals() -> void:
	var simulator: Node = get_node_or_null(SIMULATOR_PATH)
	if simulator == null:
		return

	var session_callback := Callable(self, "_on_simulator_session_changed")
	if simulator.has_signal("account_session_changed") and not simulator.is_connected("account_session_changed", session_callback):
		simulator.connect("account_session_changed", session_callback)

	var profile_callback := Callable(self, "_on_simulator_profile_changed")
	if simulator.has_signal("account_profile_changed") and not simulator.is_connected("account_profile_changed", profile_callback):
		simulator.connect("account_profile_changed", profile_callback)


func _on_simulator_session_changed(username: String) -> void:
	session_changed.emit(username)


func _on_simulator_profile_changed(snapshot: Dictionary) -> void:
	profile_changed.emit(snapshot)


func _request_value(operation: String, args: Array = [], default_value = null):
	var simulator: Node = get_node_or_null(SIMULATOR_PATH)
	if simulator == null or not simulator.has_method("request_account"):
		return default_value

	var response: Dictionary = simulator.call("request_account", operation, args) as Dictionary
	if not bool(response.get("ok", false)):
		return default_value
	return response.get("value", default_value)
