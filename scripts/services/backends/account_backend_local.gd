extends Node

signal session_changed(username: String)
signal profile_changed(snapshot: Dictionary)

const BACKEND_ID := "local_runtime"
const ACCOUNT_RUNTIME_PATH := "/root/AccountRuntime"

var _runtime: Node


func _ready() -> void:
	call_deferred("_connect_runtime_signals")


func get_backend_id() -> String:
	return BACKEND_ID


func is_logged_in() -> bool:
	return bool(_call_runtime(&"is_logged_in", [], false))


func get_current_username() -> String:
	return String(_call_runtime(&"get_current_username", [], ""))


func get_current_display_name() -> String:
	return String(_call_runtime(&"get_current_display_name", [], "Adventurer"))


func register_account(username: String, password: String) -> Dictionary:
	return _call_runtime(&"register_account", [username, password], {}) as Dictionary


func login_account(username: String, password: String) -> Dictionary:
	return _call_runtime(&"login_account", [username, password], {}) as Dictionary


func logout() -> void:
	_call_runtime(&"logout")


func get_current_profile_state() -> Dictionary:
	return _call_runtime(&"get_current_profile_state", [], {}) as Dictionary


func get_current_profile_snapshot() -> Dictionary:
	return _call_runtime(&"get_current_profile_snapshot", [], {}) as Dictionary


func get_current_specialization_level() -> int:
	return int(_call_runtime(&"get_current_specialization_level", [], PlayerAttributeProfile.DEFAULT_SPECIALIZATION_LEVEL))


func get_current_specialization_exp() -> int:
	return int(_call_runtime(&"get_current_specialization_exp", [], PlayerAttributeProfile.DEFAULT_SPECIALIZATION_EXP))


func get_current_specialization_exp_to_next_level() -> int:
	return int(_call_runtime(&"get_current_specialization_exp_to_next_level", [], 100))


func get_current_weapon_mastery_level(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_call_runtime(&"get_current_weapon_mastery_level", [track_id], PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_LEVEL))


func get_current_weapon_mastery_exp(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_call_runtime(&"get_current_weapon_mastery_exp", [track_id], PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_EXP))


func get_current_weapon_mastery_exp_to_next_level(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_call_runtime(&"get_current_weapon_mastery_exp_to_next_level", [track_id], 80))


func add_specialization_levels(amount: int) -> void:
	_call_runtime(&"add_specialization_levels", [amount])


func add_specialization_exp(amount: int) -> void:
	_call_runtime(&"add_specialization_exp", [amount])


func add_weapon_mastery_levels(track_id: String, amount: int) -> void:
	_call_runtime(&"add_weapon_mastery_levels", [track_id, amount])


func add_weapon_mastery_exp(track_id: String, amount: int) -> void:
	_call_runtime(&"add_weapon_mastery_exp", [track_id, amount])


func overwrite_current_profile_state(state: Dictionary) -> void:
	_call_runtime(&"overwrite_current_profile_state", [state])


func add_free_stat_points(amount: int) -> void:
	_call_runtime(&"add_free_stat_points", [amount])


func allocate_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	return bool(_call_runtime(&"allocate_free_stat_points", [attribute_id, amount], false))


func refund_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	return bool(_call_runtime(&"refund_free_stat_points", [attribute_id, amount], false))


func get_current_inventory_state() -> Dictionary:
	return _call_runtime(&"get_current_inventory_state", [], {}) as Dictionary


func overwrite_current_inventory_state(state: Dictionary) -> void:
	_call_runtime(&"overwrite_current_inventory_state", [state])


func _get_runtime() -> Node:
	if _runtime == null or not is_instance_valid(_runtime):
		_runtime = get_node_or_null(ACCOUNT_RUNTIME_PATH)
	return _runtime


func _connect_runtime_signals() -> void:
	var runtime: Node = _get_runtime()
	if runtime == null:
		return

	var session_callback := Callable(self, "_on_runtime_session_changed")
	if runtime.has_signal("session_changed") and not runtime.is_connected("session_changed", session_callback):
		runtime.connect("session_changed", session_callback)

	var profile_callback := Callable(self, "_on_runtime_profile_changed")
	if runtime.has_signal("profile_changed") and not runtime.is_connected("profile_changed", profile_callback):
		runtime.connect("profile_changed", profile_callback)


func _on_runtime_session_changed(username: String) -> void:
	session_changed.emit(username)


func _on_runtime_profile_changed(snapshot: Dictionary) -> void:
	profile_changed.emit(snapshot)


func _call_runtime(method: StringName, args: Array = [], default_value = null):
	var runtime: Node = _get_runtime()
	if runtime == null or not runtime.has_method(method):
		return default_value
	return runtime.callv(method, args)
