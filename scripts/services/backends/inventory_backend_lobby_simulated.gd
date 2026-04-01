extends Node

signal inventory_changed()
signal equipped_weapon_changed(item: Dictionary)
signal equipped_potion_changed(item: Dictionary)

const BACKEND_ID := "lobby_simulated"
const SIMULATOR_PATH := "/root/LobbyServerSimulator"


func _ready() -> void:
	call_deferred("_connect_simulator_signals")


func get_backend_id() -> String:
	return BACKEND_ID


func reset_demo_state() -> void:
	_request_value("reset_demo_state")


func build_save_state() -> Dictionary:
	return _request_value("build_save_state", [], {}) as Dictionary


func load_save_state(state: Dictionary) -> void:
	_request_value("load_save_state", [state])


func get_backpack_capacity() -> int:
	return int(_request_value("get_backpack_capacity", [], 0))


func get_warehouse_capacity() -> int:
	return int(_request_value("get_warehouse_capacity", [], 0))


func get_backpack_slots() -> Array:
	return _request_value("get_backpack_slots", [], []) as Array


func get_warehouse_slots() -> Array:
	return _request_value("get_warehouse_slots", [], []) as Array


func get_equipped_weapon() -> Dictionary:
	return _request_value("get_equipped_weapon", [], {}) as Dictionary


func get_equipped_potion() -> Dictionary:
	return _request_value("get_equipped_potion", [], {}) as Dictionary


func get_equipped_weapon_scene_path() -> String:
	return String(_request_value("get_equipped_weapon_scene_path", [], ""))


func get_used_backpack_slot_count() -> int:
	return int(_request_value("get_used_backpack_slot_count", [], 0))


func get_used_warehouse_slot_count() -> int:
	return int(_request_value("get_used_warehouse_slot_count", [], 0))


func get_debug_item_catalog() -> Array:
	return _request_value("get_debug_item_catalog", [], []) as Array


func add_item_to_backpack_by_definition(definition_id: String) -> bool:
	return bool(_request_value("add_item_to_backpack_by_definition", [definition_id], false))


func move_item(from_container: StringName, from_index: int, to_container: StringName, to_index: int) -> bool:
	return bool(_request_value("move_item", [from_container, from_index, to_container, to_index], false))


func equip_from_backpack(slot_index: int) -> bool:
	return bool(_request_value("equip_from_backpack", [slot_index], false))


func unequip_to_backpack(target_slot_index: int = -1) -> bool:
	return bool(_request_value("unequip_to_backpack", [target_slot_index], false))


func equip_potion_from_backpack(slot_index: int) -> bool:
	return bool(_request_value("equip_potion_from_backpack", [slot_index], false))


func unequip_potion_to_backpack(target_slot_index: int = -1) -> bool:
	return bool(_request_value("unequip_potion_to_backpack", [target_slot_index], false))


func consume_equipped_potion_one() -> Dictionary:
	return _request_value("consume_equipped_potion_one", [], {}) as Dictionary


func apply_player_death_penalty() -> void:
	_request_value("apply_player_death_penalty")


func find_first_empty_backpack_slot() -> int:
	return int(_request_value("find_first_empty_backpack_slot", [], -1))


func find_first_empty_warehouse_slot() -> int:
	return int(_request_value("find_first_empty_warehouse_slot", [], -1))


func build_empty_reinforcement_bonus() -> Dictionary:
	return _request_value("build_empty_reinforcement_bonus", [], {}) as Dictionary


func get_item_total_base_attack_power(item: Dictionary) -> float:
	return float(_request_value("get_item_total_base_attack_power", [item], 0.0))


func get_item_total_base_defense_ratio(item: Dictionary) -> float:
	return float(_request_value("get_item_total_base_defense_ratio", [item], 0.0))


func get_item_reinforcement_label(item: Dictionary) -> String:
	return String(_request_value("get_item_reinforcement_label", [item], ""))


func is_reinforcement_stone(item: Dictionary) -> bool:
	return bool(_request_value("is_reinforcement_stone", [item], false))


func is_potion(item: Dictionary) -> bool:
	return bool(_request_value("is_potion", [item], false))


func is_crafting_material(item: Dictionary) -> bool:
	return bool(_request_value("is_crafting_material", [item], false))


func get_scrap_metal_crafting_recipes() -> Array:
	return _request_value("get_scrap_metal_crafting_recipes", [], []) as Array


func craft_from_scrap_metal(source_container: StringName, source_index: int, product_definition_id: String) -> Dictionary:
	return _request_value("craft_from_scrap_metal", [source_container, source_index, product_definition_id], {}) as Dictionary


func can_item_be_reinforced(item: Dictionary) -> bool:
	return bool(_request_value("can_item_be_reinforced", [item], false))


func apply_reinforcement_stone(source_container: StringName, source_index: int, target_container: StringName, target_index: int = -1) -> Dictionary:
	return _request_value("apply_reinforcement_stone", [source_container, source_index, target_container, target_index], {}) as Dictionary


func _connect_simulator_signals() -> void:
	var simulator: Node = get_node_or_null(SIMULATOR_PATH)
	if simulator == null:
		return

	var inventory_callback := Callable(self, "_on_simulator_inventory_changed")
	if simulator.has_signal("inventory_changed") and not simulator.is_connected("inventory_changed", inventory_callback):
		simulator.connect("inventory_changed", inventory_callback)

	var weapon_callback := Callable(self, "_on_simulator_equipped_weapon_changed")
	if simulator.has_signal("inventory_equipped_weapon_changed") and not simulator.is_connected("inventory_equipped_weapon_changed", weapon_callback):
		simulator.connect("inventory_equipped_weapon_changed", weapon_callback)

	var potion_callback := Callable(self, "_on_simulator_equipped_potion_changed")
	if simulator.has_signal("inventory_equipped_potion_changed") and not simulator.is_connected("inventory_equipped_potion_changed", potion_callback):
		simulator.connect("inventory_equipped_potion_changed", potion_callback)


func _on_simulator_inventory_changed() -> void:
	inventory_changed.emit()


func _on_simulator_equipped_weapon_changed(item: Dictionary) -> void:
	equipped_weapon_changed.emit(item)


func _on_simulator_equipped_potion_changed(item: Dictionary) -> void:
	equipped_potion_changed.emit(item)


func _request_value(operation: String, args: Array = [], default_value = null):
	var simulator: Node = get_node_or_null(SIMULATOR_PATH)
	if simulator == null or not simulator.has_method("request_inventory"):
		return default_value

	var response: Dictionary = simulator.call("request_inventory", operation, args) as Dictionary
	if not bool(response.get("ok", false)):
		return default_value
	return response.get("value", default_value)
