extends Node

signal inventory_changed()
signal equipped_weapon_changed(item: Dictionary)
signal equipped_potion_changed(item: Dictionary)

const BACKEND_ID := "local_runtime"
const INVENTORY_RUNTIME_PATH := "/root/InventoryRuntime"

var _runtime: Node


func _ready() -> void:
	call_deferred("_connect_runtime_signals")


func get_backend_id() -> String:
	return BACKEND_ID


func reset_demo_state() -> void:
	_call_runtime(&"reset_demo_state")


func build_save_state() -> Dictionary:
	return _call_runtime(&"build_save_state", [], {}) as Dictionary


func load_save_state(state: Dictionary) -> void:
	_call_runtime(&"load_save_state", [state])


func get_backpack_capacity() -> int:
	return int(_call_runtime(&"get_backpack_capacity", [], 0))


func get_warehouse_capacity() -> int:
	return int(_call_runtime(&"get_warehouse_capacity", [], 0))


func get_backpack_slots() -> Array:
	return _call_runtime(&"get_backpack_slots", [], []) as Array


func get_warehouse_slots() -> Array:
	return _call_runtime(&"get_warehouse_slots", [], []) as Array


func get_equipped_weapon() -> Dictionary:
	return _call_runtime(&"get_equipped_weapon", [], {}) as Dictionary


func get_equipped_potion() -> Dictionary:
	return _call_runtime(&"get_equipped_potion", [], {}) as Dictionary


func get_equipped_weapon_scene_path() -> String:
	return String(_call_runtime(&"get_equipped_weapon_scene_path", [], ""))


func get_used_backpack_slot_count() -> int:
	return int(_call_runtime(&"get_used_backpack_slot_count", [], 0))


func get_used_warehouse_slot_count() -> int:
	return int(_call_runtime(&"get_used_warehouse_slot_count", [], 0))


func get_debug_item_catalog() -> Array:
	return _call_runtime(&"get_debug_item_catalog", [], []) as Array


func add_item_to_backpack_by_definition(definition_id: String) -> bool:
	return bool(_call_runtime(&"add_item_to_backpack_by_definition", [definition_id], false))


func move_item(from_container: StringName, from_index: int, to_container: StringName, to_index: int) -> bool:
	return bool(_call_runtime(&"move_item", [from_container, from_index, to_container, to_index], false))


func equip_from_backpack(slot_index: int) -> bool:
	return bool(_call_runtime(&"equip_from_backpack", [slot_index], false))


func unequip_to_backpack(target_slot_index: int = -1) -> bool:
	return bool(_call_runtime(&"unequip_to_backpack", [target_slot_index], false))


func equip_potion_from_backpack(slot_index: int) -> bool:
	return bool(_call_runtime(&"equip_potion_from_backpack", [slot_index], false))


func unequip_potion_to_backpack(target_slot_index: int = -1) -> bool:
	return bool(_call_runtime(&"unequip_potion_to_backpack", [target_slot_index], false))


func consume_equipped_potion_one() -> Dictionary:
	return _call_runtime(&"consume_equipped_potion_one", [], {}) as Dictionary


func apply_player_death_penalty() -> void:
	_call_runtime(&"apply_player_death_penalty")


func find_first_empty_backpack_slot() -> int:
	return int(_call_runtime(&"find_first_empty_backpack_slot", [], -1))


func find_first_empty_warehouse_slot() -> int:
	return int(_call_runtime(&"find_first_empty_warehouse_slot", [], -1))


func build_empty_reinforcement_bonus() -> Dictionary:
	return _call_runtime(&"build_empty_reinforcement_bonus", [], {}) as Dictionary


func get_item_total_base_attack_power(item: Dictionary) -> float:
	return float(_call_runtime(&"get_item_total_base_attack_power", [item], 0.0))


func get_item_total_base_defense_ratio(item: Dictionary) -> float:
	return float(_call_runtime(&"get_item_total_base_defense_ratio", [item], 0.0))


func get_item_reinforcement_label(item: Dictionary) -> String:
	return String(_call_runtime(&"get_item_reinforcement_label", [item], ""))


func is_reinforcement_stone(item: Dictionary) -> bool:
	return bool(_call_runtime(&"is_reinforcement_stone", [item], false))


func is_potion(item: Dictionary) -> bool:
	return bool(_call_runtime(&"is_potion", [item], false))


func is_crafting_material(item: Dictionary) -> bool:
	return bool(_call_runtime(&"is_crafting_material", [item], false))


func get_scrap_metal_crafting_recipes() -> Array:
	return _call_runtime(&"get_scrap_metal_crafting_recipes", [], []) as Array


func craft_from_scrap_metal(source_container: StringName, source_index: int, product_definition_id: String) -> Dictionary:
	return _call_runtime(&"craft_from_scrap_metal", [source_container, source_index, product_definition_id], {}) as Dictionary


func can_item_be_reinforced(item: Dictionary) -> bool:
	return bool(_call_runtime(&"can_item_be_reinforced", [item], false))


func apply_reinforcement_stone(source_container: StringName, source_index: int, target_container: StringName, target_index: int = -1) -> Dictionary:
	return _call_runtime(&"apply_reinforcement_stone", [source_container, source_index, target_container, target_index], {}) as Dictionary


func _get_runtime() -> Node:
	if _runtime == null or not is_instance_valid(_runtime):
		_runtime = get_node_or_null(INVENTORY_RUNTIME_PATH)
	return _runtime


func _connect_runtime_signals() -> void:
	var runtime: Node = _get_runtime()
	if runtime == null:
		return

	var inventory_callback := Callable(self, "_on_runtime_inventory_changed")
	if runtime.has_signal("inventory_changed") and not runtime.is_connected("inventory_changed", inventory_callback):
		runtime.connect("inventory_changed", inventory_callback)

	var weapon_callback := Callable(self, "_on_runtime_equipped_weapon_changed")
	if runtime.has_signal("equipped_weapon_changed") and not runtime.is_connected("equipped_weapon_changed", weapon_callback):
		runtime.connect("equipped_weapon_changed", weapon_callback)

	var potion_callback := Callable(self, "_on_runtime_equipped_potion_changed")
	if runtime.has_signal("equipped_potion_changed") and not runtime.is_connected("equipped_potion_changed", potion_callback):
		runtime.connect("equipped_potion_changed", potion_callback)


func _on_runtime_inventory_changed() -> void:
	inventory_changed.emit()


func _on_runtime_equipped_weapon_changed(item: Dictionary) -> void:
	equipped_weapon_changed.emit(item)


func _on_runtime_equipped_potion_changed(item: Dictionary) -> void:
	equipped_potion_changed.emit(item)


func _call_runtime(method: StringName, args: Array = [], default_value = null):
	var runtime: Node = _get_runtime()
	if runtime == null or not runtime.has_method(method):
		return default_value
	return runtime.callv(method, args)
