extends Node

signal account_session_changed(username: String)
signal account_profile_changed(snapshot: Dictionary)
signal inventory_changed()
signal inventory_equipped_weapon_changed(item: Dictionary)
signal inventory_equipped_potion_changed(item: Dictionary)

const ACCOUNT_RUNTIME_PATH := "/root/AccountRuntime"
const INVENTORY_RUNTIME_PATH := "/root/InventoryRuntime"

const ACCOUNT_ALLOWED_OPERATIONS := {
	"is_logged_in": true,
	"get_current_username": true,
	"get_current_display_name": true,
	"register_account": true,
	"login_account": true,
	"logout": true,
	"get_current_profile_state": true,
	"get_current_profile_snapshot": true,
	"get_current_specialization_level": true,
	"get_current_specialization_exp": true,
	"get_current_specialization_exp_to_next_level": true,
	"get_current_weapon_mastery_level": true,
	"get_current_weapon_mastery_exp": true,
	"get_current_weapon_mastery_exp_to_next_level": true,
	"add_specialization_levels": true,
	"add_specialization_exp": true,
	"add_weapon_mastery_levels": true,
	"add_weapon_mastery_exp": true,
	"overwrite_current_profile_state": true,
	"add_free_stat_points": true,
	"allocate_free_stat_points": true,
	"refund_free_stat_points": true,
	"get_current_inventory_state": true,
	"overwrite_current_inventory_state": true,
}

const INVENTORY_ALLOWED_OPERATIONS := {
	"reset_demo_state": true,
	"build_save_state": true,
	"load_save_state": true,
	"get_backpack_capacity": true,
	"get_warehouse_capacity": true,
	"get_backpack_slots": true,
	"get_warehouse_slots": true,
	"get_equipped_weapon": true,
	"get_equipped_potion": true,
	"get_equipped_weapon_scene_path": true,
	"get_used_backpack_slot_count": true,
	"get_used_warehouse_slot_count": true,
	"get_debug_item_catalog": true,
	"add_item_to_backpack_by_definition": true,
	"move_item": true,
	"equip_from_backpack": true,
	"unequip_to_backpack": true,
	"equip_potion_from_backpack": true,
	"unequip_potion_to_backpack": true,
	"consume_equipped_potion_one": true,
	"apply_player_death_penalty": true,
	"find_first_empty_backpack_slot": true,
	"find_first_empty_warehouse_slot": true,
	"build_empty_reinforcement_bonus": true,
	"get_item_total_base_attack_power": true,
	"get_item_total_base_defense_ratio": true,
	"get_item_reinforcement_label": true,
	"is_reinforcement_stone": true,
	"is_potion": true,
	"is_crafting_material": true,
	"get_scrap_metal_crafting_recipes": true,
	"craft_from_scrap_metal": true,
	"can_item_be_reinforced": true,
	"apply_reinforcement_stone": true,
}

var _next_request_id: int = 1


func _ready() -> void:
	call_deferred("_connect_runtime_signals")


func request_account(operation: String, args: Array = []) -> Dictionary:
	return _request("account", ACCOUNT_RUNTIME_PATH, ACCOUNT_ALLOWED_OPERATIONS, operation, args)


func request_inventory(operation: String, args: Array = []) -> Dictionary:
	return _request("inventory", INVENTORY_RUNTIME_PATH, INVENTORY_ALLOWED_OPERATIONS, operation, args)


func _request(channel: String, runtime_path: String, allowed_operations: Dictionary, operation: String, args: Array) -> Dictionary:
	var request_id: int = _next_request_id
	_next_request_id += 1

	if not allowed_operations.has(operation):
		return {
			"ok": false,
			"channel": channel,
			"request_id": request_id,
			"error": "unsupported_operation",
		}

	var runtime: Node = get_node_or_null(runtime_path)
	if runtime == null or not runtime.has_method(operation):
		return {
			"ok": false,
			"channel": channel,
			"request_id": request_id,
			"error": "runtime_unavailable",
		}

	return {
		"ok": true,
		"channel": channel,
		"request_id": request_id,
		"backend": "lobby_simulated",
		"value": runtime.callv(operation, args),
	}


func _connect_runtime_signals() -> void:
	var account_runtime: Node = get_node_or_null(ACCOUNT_RUNTIME_PATH)
	if account_runtime != null:
		var account_session_callback := Callable(self, "_on_account_runtime_session_changed")
		if account_runtime.has_signal("session_changed") and not account_runtime.is_connected("session_changed", account_session_callback):
			account_runtime.connect("session_changed", account_session_callback)

		var account_profile_callback := Callable(self, "_on_account_runtime_profile_changed")
		if account_runtime.has_signal("profile_changed") and not account_runtime.is_connected("profile_changed", account_profile_callback):
			account_runtime.connect("profile_changed", account_profile_callback)

	var inventory_runtime: Node = get_node_or_null(INVENTORY_RUNTIME_PATH)
	if inventory_runtime != null:
		var inventory_callback := Callable(self, "_on_inventory_runtime_changed")
		if inventory_runtime.has_signal("inventory_changed") and not inventory_runtime.is_connected("inventory_changed", inventory_callback):
			inventory_runtime.connect("inventory_changed", inventory_callback)

		var weapon_callback := Callable(self, "_on_inventory_runtime_equipped_weapon_changed")
		if inventory_runtime.has_signal("equipped_weapon_changed") and not inventory_runtime.is_connected("equipped_weapon_changed", weapon_callback):
			inventory_runtime.connect("equipped_weapon_changed", weapon_callback)

		var potion_callback := Callable(self, "_on_inventory_runtime_equipped_potion_changed")
		if inventory_runtime.has_signal("equipped_potion_changed") and not inventory_runtime.is_connected("equipped_potion_changed", potion_callback):
			inventory_runtime.connect("equipped_potion_changed", potion_callback)


func _on_account_runtime_session_changed(username: String) -> void:
	account_session_changed.emit(username)


func _on_account_runtime_profile_changed(snapshot: Dictionary) -> void:
	account_profile_changed.emit(snapshot)


func _on_inventory_runtime_changed() -> void:
	inventory_changed.emit()


func _on_inventory_runtime_equipped_weapon_changed(item: Dictionary) -> void:
	inventory_equipped_weapon_changed.emit(item)


func _on_inventory_runtime_equipped_potion_changed(item: Dictionary) -> void:
	inventory_equipped_potion_changed.emit(item)
