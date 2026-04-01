extends Node

signal session_changed(username: String)
signal profile_changed(snapshot: Dictionary)

const SAVE_PATH := "user://account_runtime.cfg"
const ACCOUNTS_SECTION := "accounts"
const ACCOUNTS_KEY := "entries"

var _accounts: Dictionary = {}
var _current_username: String = ""
var _current_profile: PlayerAttributeProfile


func _ready() -> void:
	_load_accounts_from_disk()


func is_logged_in() -> bool:
	return not _current_username.is_empty()


func get_current_username() -> String:
	return _current_username


func get_current_display_name() -> String:
	if _current_username.is_empty():
		return "Adventurer"
	var account_data: Dictionary = _get_current_account_data()
	return String(account_data.get("display_name", _current_username))


func register_account(username: String, password: String) -> Dictionary:
	var normalized_username: String = _normalize_username(username)
	if normalized_username.is_empty():
		return {"ok": false, "message": _zh("6K+36L6T5YWl6LSm5Y+344CC")}
	if password.is_empty():
		return {"ok": false, "message": _zh("6K+36L6T5YWl5a+G56CB44CC")}
	if _accounts.has(normalized_username):
		return {"ok": false, "message": _zh("6K+l6LSm5Y+35bey6KKr5rOo5YaM44CC")}

	_accounts[normalized_username] = {
		"display_name": normalized_username,
		"password_hash": _hash_password(password),
		"player_profile": _build_default_profile_state(),
		"inventory_state": {},
	}
	_save_accounts_to_disk()
	_apply_logged_in_user(normalized_username)
	return {"ok": true, "message": _zh("5rOo5YaM5oiQ5Yqf44CC")}


func login_account(username: String, password: String) -> Dictionary:
	var normalized_username: String = _normalize_username(username)
	if normalized_username.is_empty():
		return {"ok": false, "message": _zh("6K+36L6T5YWl6LSm5Y+344CC")}
	if password.is_empty():
		return {"ok": false, "message": _zh("6K+36L6T5YWl5a+G56CB44CC")}
	if not _accounts.has(normalized_username):
		return {"ok": false, "message": _zh("6LSm5Y+35LiN5a2Y5Zyo44CC")}

	var account_data: Dictionary = _accounts[normalized_username] as Dictionary
	if String(account_data.get("password_hash", "")) != _hash_password(password):
		return {"ok": false, "message": _zh("6LSm5Y+35oiW5a+G56CB6ZSZ6K+v44CC")}

	_apply_logged_in_user(normalized_username)
	return {"ok": true, "message": _zh("55m75b2V5oiQ5Yqf44CC")}


func logout() -> void:
	_current_username = ""
	_current_profile = null
	session_changed.emit("")
	profile_changed.emit({})


func get_current_profile_state() -> Dictionary:
	if _current_profile == null:
		return {}
	return _current_profile.export_persisted_state()


func get_current_profile_snapshot() -> Dictionary:
	if _current_profile == null:
		return {}

	var snapshot: Dictionary = _current_profile.build_snapshot()
	var effective_max_hp: float = 100.0 * _current_profile.get_hp_multiplier()
	var effective_max_mp: float = 100.0 + _current_profile.get_bonus_max_mp()
	snapshot["current_hp"] = effective_max_hp
	snapshot["effective_max_hp"] = effective_max_hp
	snapshot["current_mp"] = effective_max_mp
	snapshot["effective_max_mp"] = effective_max_mp
	return snapshot


func get_current_specialization_level() -> int:
	if _current_profile == null:
		return PlayerAttributeProfile.DEFAULT_SPECIALIZATION_LEVEL
	return _current_profile.get_specialization_level()


func get_current_specialization_exp() -> int:
	if _current_profile == null:
		return PlayerAttributeProfile.DEFAULT_SPECIALIZATION_EXP
	return _current_profile.get_specialization_exp()


func get_current_specialization_exp_to_next_level() -> int:
	if _current_profile == null:
		return 100
	return _current_profile.get_specialization_exp_to_next_level()


func get_current_weapon_mastery_level(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	if _current_profile == null:
		return PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_LEVEL
	return _current_profile.get_weapon_mastery_level(track_id)


func get_current_weapon_mastery_exp(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	if _current_profile == null:
		return PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_EXP
	return _current_profile.get_weapon_mastery_exp(track_id)


func get_current_weapon_mastery_exp_to_next_level(track_id: String = PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	if _current_profile == null:
		return 80
	return _current_profile.get_weapon_mastery_exp_to_next_level(track_id)


func add_specialization_levels(amount: int) -> void:
	if _current_profile == null or amount <= 0:
		return
	_current_profile.add_specialization_levels(amount)
	_persist_current_profile()


func add_specialization_exp(amount: int) -> void:
	if _current_profile == null or amount <= 0:
		return
	_current_profile.add_specialization_exp(amount)
	_persist_current_profile()


func add_weapon_mastery_levels(track_id: String, amount: int) -> void:
	if _current_profile == null or amount <= 0:
		return
	_current_profile.add_weapon_mastery_levels(track_id, amount)
	_persist_current_profile()


func add_weapon_mastery_exp(track_id: String, amount: int) -> void:
	if _current_profile == null or amount <= 0:
		return
	_current_profile.add_weapon_mastery_exp(track_id, amount)
	_persist_current_profile()


func overwrite_current_profile_state(state: Dictionary) -> void:
	if not is_logged_in():
		return
	_ensure_current_profile()
	_current_profile.load_persisted_state(state)
	_persist_current_profile()


func add_free_stat_points(amount: int) -> void:
	if _current_profile == null or amount <= 0:
		return
	_current_profile.add_free_stat_points(amount)
	_persist_current_profile()


func allocate_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	if _current_profile == null:
		return false
	var did_allocate: bool = _current_profile.spend_free_stat_points(attribute_id, amount)
	if did_allocate:
		_persist_current_profile()
	return did_allocate


func refund_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	if _current_profile == null:
		return false
	var did_refund: bool = _current_profile.refund_free_stat_points(attribute_id, amount)
	if did_refund:
		_persist_current_profile()
	return did_refund


func get_current_inventory_state() -> Dictionary:
	var account_data: Dictionary = _get_current_account_data()
	return (account_data.get("inventory_state", {}) as Dictionary).duplicate(true)


func overwrite_current_inventory_state(state: Dictionary) -> void:
	if not is_logged_in():
		return
	var account_data: Dictionary = _get_current_account_data()
	account_data["inventory_state"] = state.duplicate(true)
	_accounts[_current_username] = account_data
	_save_accounts_to_disk()


func _apply_logged_in_user(username: String) -> void:
	_current_username = username
	_ensure_current_profile()
	session_changed.emit(_current_username)
	profile_changed.emit(get_current_profile_snapshot())


func _ensure_current_profile() -> void:
	if _current_username.is_empty():
		_current_profile = null
		return
	var account_data: Dictionary = _get_current_account_data()
	var profile_state: Dictionary = account_data.get("player_profile", {}) as Dictionary
	_current_profile = PlayerAttributeProfile.new()
	_current_profile.load_persisted_state(profile_state)


func _persist_current_profile() -> void:
	if not is_logged_in() or _current_profile == null:
		return
	var account_data: Dictionary = _get_current_account_data()
	account_data["player_profile"] = _current_profile.export_persisted_state()
	_accounts[_current_username] = account_data
	_save_accounts_to_disk()
	profile_changed.emit(get_current_profile_snapshot())


func _build_default_profile_state() -> Dictionary:
	var profile := PlayerAttributeProfile.new()
	return profile.export_persisted_state()


func _get_current_account_data() -> Dictionary:
	if _current_username.is_empty():
		return {}
	return (_accounts.get(_current_username, {}) as Dictionary).duplicate(true)


func _normalize_username(username: String) -> String:
	return username.strip_edges()


func _hash_password(password: String) -> String:
	var hashing_context := HashingContext.new()
	var error_code: int = hashing_context.start(HashingContext.HASH_SHA256)
	if error_code != OK:
		return password
	hashing_context.update(password.to_utf8_buffer())
	return hashing_context.finish().hex_encode()


func _load_accounts_from_disk() -> void:
	var config := ConfigFile.new()
	var error_code: int = config.load(SAVE_PATH)
	if error_code != OK:
		_accounts = {}
		return
	_accounts = (config.get_value(ACCOUNTS_SECTION, ACCOUNTS_KEY, {}) as Dictionary).duplicate(true)


func _save_accounts_to_disk() -> void:
	var config := ConfigFile.new()
	config.set_value(ACCOUNTS_SECTION, ACCOUNTS_KEY, _accounts)
	config.save(SAVE_PATH)


func _zh(encoded: String) -> String:
	return Marshalls.base64_to_utf8(encoded)
