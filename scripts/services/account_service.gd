extends Node

signal session_changed(username: String)
signal profile_changed(snapshot: Dictionary)
signal backend_changed(backend_id: String)

const LOCAL_BACKEND_SCRIPT := preload("res://scripts/services/backends/account_backend_local.gd")
const LOBBY_SIMULATED_BACKEND_SCRIPT := preload("res://scripts/services/backends/account_backend_lobby_simulated.gd")

var _backend: Node
var _backend_id: String = ""


func _ready() -> void:
	if not use_lobby_simulated_backend():
		use_local_backend()


func get_backend_id() -> String:
	return _backend_id


func has_backend() -> bool:
	return _backend != null and is_instance_valid(_backend)


func is_using_local_backend() -> bool:
	return _backend_id == "local_runtime"


func use_local_backend() -> bool:
	var local_backend: Node = LOCAL_BACKEND_SCRIPT.new()
	return bind_backend(local_backend)

func use_lobby_simulated_backend() -> bool:
	var simulated_backend: Node = LOBBY_SIMULATED_BACKEND_SCRIPT.new()
	return bind_backend(simulated_backend)


func bind_backend(backend: Node) -> bool:
	if backend == null:
		return false
	_detach_backend()
	_backend = backend
	_backend_id = _resolve_backend_id(backend)
	add_child(backend)
	_connect_backend_signals()
	print("AccountService backend -> %s" % _backend_id)
	backend_changed.emit(_backend_id)
	return true


func is_logged_in() -> bool:
	return bool(_call_backend(&"is_logged_in", [], false))


func get_current_username() -> String:
	return String(_call_backend(&"get_current_username", [], ""))


func get_current_display_name() -> String:
	return String(_call_backend(&"get_current_display_name", [], "Adventurer"))


func register_account(username: String, password: String) -> Dictionary:
	return _call_backend(&"register_account", [username, password], {}) as Dictionary


func login_account(username: String, password: String) -> Dictionary:
	return _call_backend(&"login_account", [username, password], {}) as Dictionary


func logout() -> void:
	_call_backend(&"logout")


func get_current_profile_state() -> Dictionary:
	return _call_backend(&"get_current_profile_state", [], {}) as Dictionary


func get_current_profile_snapshot() -> Dictionary:
	return _call_backend(&"get_current_profile_snapshot", [], {}) as Dictionary


func get_current_specialization_level() -> int:
	return int(_call_backend(&"get_current_specialization_level", [], PlayerAttributeProfile.DEFAULT_SPECIALIZATION_LEVEL))


func get_current_specialization_exp() -> int:
	return int(_call_backend(&"get_current_specialization_exp", [], PlayerAttributeProfile.DEFAULT_SPECIALIZATION_EXP))


func get_current_specialization_exp_to_next_level() -> int:
	return int(_call_backend(&"get_current_specialization_exp_to_next_level", [], 100))


func get_current_weapon_mastery_level(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_call_backend(&"get_current_weapon_mastery_level", [track_id], PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_LEVEL))


func get_current_weapon_mastery_exp(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_call_backend(&"get_current_weapon_mastery_exp", [track_id], PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_EXP))


func get_current_weapon_mastery_exp_to_next_level(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	return int(_call_backend(&"get_current_weapon_mastery_exp_to_next_level", [track_id], 80))


func add_specialization_levels(amount: int) -> void:
	_call_backend(&"add_specialization_levels", [amount])


func add_specialization_exp(amount: int) -> void:
	_call_backend(&"add_specialization_exp", [amount])


func add_weapon_mastery_levels(track_id: String, amount: int) -> void:
	_call_backend(&"add_weapon_mastery_levels", [track_id, amount])


func add_weapon_mastery_exp(track_id: String, amount: int) -> void:
	_call_backend(&"add_weapon_mastery_exp", [track_id, amount])


func overwrite_current_profile_state(state: Dictionary) -> void:
	_call_backend(&"overwrite_current_profile_state", [state])


func add_free_stat_points(amount: int) -> void:
	_call_backend(&"add_free_stat_points", [amount])


func allocate_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	return bool(_call_backend(&"allocate_free_stat_points", [attribute_id, amount], false))


func refund_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	return bool(_call_backend(&"refund_free_stat_points", [attribute_id, amount], false))


func get_current_inventory_state() -> Dictionary:
	return _call_backend(&"get_current_inventory_state", [], {}) as Dictionary


func overwrite_current_inventory_state(state: Dictionary) -> void:
	_call_backend(&"overwrite_current_inventory_state", [state])


func _resolve_backend_id(backend: Node) -> String:
	if backend != null and backend.has_method("get_backend_id"):
		return String(backend.call("get_backend_id"))
	return "unknown"


func _connect_backend_signals() -> void:
	if _backend == null:
		return

	var session_callback := Callable(self, "_on_backend_session_changed")
	if _backend.has_signal("session_changed") and not _backend.is_connected("session_changed", session_callback):
		_backend.connect("session_changed", session_callback)

	var profile_callback := Callable(self, "_on_backend_profile_changed")
	if _backend.has_signal("profile_changed") and not _backend.is_connected("profile_changed", profile_callback):
		_backend.connect("profile_changed", profile_callback)


func _detach_backend() -> void:
	if _backend == null:
		_backend_id = ""
		return

	var session_callback := Callable(self, "_on_backend_session_changed")
	if _backend.has_signal("session_changed") and _backend.is_connected("session_changed", session_callback):
		_backend.disconnect("session_changed", session_callback)

	var profile_callback := Callable(self, "_on_backend_profile_changed")
	if _backend.has_signal("profile_changed") and _backend.is_connected("profile_changed", profile_callback):
		_backend.disconnect("profile_changed", profile_callback)

	if is_instance_valid(_backend):
		_backend.queue_free()
	_backend = null
	_backend_id = ""


func _on_backend_session_changed(username: String) -> void:
	session_changed.emit(username)


func _on_backend_profile_changed(snapshot: Dictionary) -> void:
	profile_changed.emit(snapshot)


func _call_backend(method: StringName, args: Array = [], default_value = null):
	if _backend == null or not _backend.has_method(method):
		return default_value
	return _backend.callv(method, args)
