extends Node

signal inventory_changed()
signal equipped_weapon_changed(item: Dictionary)
signal equipped_potion_changed(item: Dictionary)
signal backend_changed(backend_id: String)

const LOCAL_BACKEND_SCRIPT := preload("res://scripts/services/backends/inventory_backend_local.gd")
const LOBBY_SIMULATED_BACKEND_SCRIPT := preload("res://scripts/services/backends/inventory_backend_lobby_simulated.gd")

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
	print("InventoryService backend -> %s" % _backend_id)
	backend_changed.emit(_backend_id)
	return true


func reset_demo_state() -> void:
	_call_backend(&"reset_demo_state")


func build_save_state() -> Dictionary:
	return _call_backend(&"build_save_state", [], {}) as Dictionary


func load_save_state(state: Dictionary) -> void:
	_call_backend(&"load_save_state", [state])


func get_backpack_capacity() -> int:
	return int(_call_backend(&"get_backpack_capacity", [], 0))


func get_warehouse_capacity() -> int:
	return int(_call_backend(&"get_warehouse_capacity", [], 0))


func get_backpack_slots() -> Array:
	return _call_backend(&"get_backpack_slots", [], []) as Array


func get_warehouse_slots() -> Array:
	return _call_backend(&"get_warehouse_slots", [], []) as Array


func get_equipped_weapon() -> Dictionary:
	return _call_backend(&"get_equipped_weapon", [], {}) as Dictionary


func get_equipped_potion() -> Dictionary:
	return _call_backend(&"get_equipped_potion", [], {}) as Dictionary


func get_equipped_weapon_scene_path() -> String:
	return String(_call_backend(&"get_equipped_weapon_scene_path", [], ""))


func get_used_backpack_slot_count() -> int:
	return int(_call_backend(&"get_used_backpack_slot_count", [], 0))


func get_used_warehouse_slot_count() -> int:
	return int(_call_backend(&"get_used_warehouse_slot_count", [], 0))


func get_debug_item_catalog() -> Array:
	return _call_backend(&"get_debug_item_catalog", [], []) as Array


func add_item_to_backpack_by_definition(definition_id: String) -> bool:
	return bool(_call_backend(&"add_item_to_backpack_by_definition", [definition_id], false))


func move_item(from_container: StringName, from_index: int, to_container: StringName, to_index: int) -> bool:
	return bool(_call_backend(&"move_item", [from_container, from_index, to_container, to_index], false))


func equip_from_backpack(slot_index: int) -> bool:
	return bool(_call_backend(&"equip_from_backpack", [slot_index], false))


func unequip_to_backpack(target_slot_index: int = -1) -> bool:
	return bool(_call_backend(&"unequip_to_backpack", [target_slot_index], false))


func equip_potion_from_backpack(slot_index: int) -> bool:
	return bool(_call_backend(&"equip_potion_from_backpack", [slot_index], false))


func unequip_potion_to_backpack(target_slot_index: int = -1) -> bool:
	return bool(_call_backend(&"unequip_potion_to_backpack", [target_slot_index], false))


func consume_equipped_potion_one() -> Dictionary:
	return _call_backend(&"consume_equipped_potion_one", [], {}) as Dictionary


func apply_player_death_penalty() -> void:
	_call_backend(&"apply_player_death_penalty")


func find_first_empty_backpack_slot() -> int:
	return int(_call_backend(&"find_first_empty_backpack_slot", [], -1))


func find_first_empty_warehouse_slot() -> int:
	return int(_call_backend(&"find_first_empty_warehouse_slot", [], -1))


func build_empty_reinforcement_bonus() -> Dictionary:
	return _call_backend(&"build_empty_reinforcement_bonus", [], {}) as Dictionary


func get_item_total_base_attack_power(item: Dictionary) -> float:
	return float(_call_backend(&"get_item_total_base_attack_power", [item], 0.0))


func get_item_total_base_defense_ratio(item: Dictionary) -> float:
	return float(_call_backend(&"get_item_total_base_defense_ratio", [item], 0.0))


func get_item_reinforcement_label(item: Dictionary) -> String:
	return String(_call_backend(&"get_item_reinforcement_label", [item], ""))


func is_reinforcement_stone(item: Dictionary) -> bool:
	return bool(_call_backend(&"is_reinforcement_stone", [item], false))


func is_potion(item: Dictionary) -> bool:
	return bool(_call_backend(&"is_potion", [item], false))


func is_crafting_material(item: Dictionary) -> bool:
	return bool(_call_backend(&"is_crafting_material", [item], false))


func get_scrap_metal_crafting_recipes() -> Array:
	return _call_backend(&"get_scrap_metal_crafting_recipes", [], []) as Array


func craft_from_scrap_metal(source_container: StringName, source_index: int, product_definition_id: String) -> Dictionary:
	return _call_backend(&"craft_from_scrap_metal", [source_container, source_index, product_definition_id], {}) as Dictionary


func can_item_be_reinforced(item: Dictionary) -> bool:
	return bool(_call_backend(&"can_item_be_reinforced", [item], false))


func apply_reinforcement_stone(source_container: StringName, source_index: int, target_container: StringName, target_index: int = -1) -> Dictionary:
	return _call_backend(&"apply_reinforcement_stone", [source_container, source_index, target_container, target_index], {}) as Dictionary


func _resolve_backend_id(backend: Node) -> String:
	if backend != null and backend.has_method("get_backend_id"):
		return String(backend.call("get_backend_id"))
	return "unknown"


func _connect_backend_signals() -> void:
	if _backend == null:
		return

	var inventory_callback := Callable(self, "_on_backend_inventory_changed")
	if _backend.has_signal("inventory_changed") and not _backend.is_connected("inventory_changed", inventory_callback):
		_backend.connect("inventory_changed", inventory_callback)

	var weapon_callback := Callable(self, "_on_backend_equipped_weapon_changed")
	if _backend.has_signal("equipped_weapon_changed") and not _backend.is_connected("equipped_weapon_changed", weapon_callback):
		_backend.connect("equipped_weapon_changed", weapon_callback)

	var potion_callback := Callable(self, "_on_backend_equipped_potion_changed")
	if _backend.has_signal("equipped_potion_changed") and not _backend.is_connected("equipped_potion_changed", potion_callback):
		_backend.connect("equipped_potion_changed", potion_callback)


func _detach_backend() -> void:
	if _backend == null:
		_backend_id = ""
		return

	var inventory_callback := Callable(self, "_on_backend_inventory_changed")
	if _backend.has_signal("inventory_changed") and _backend.is_connected("inventory_changed", inventory_callback):
		_backend.disconnect("inventory_changed", inventory_callback)

	var weapon_callback := Callable(self, "_on_backend_equipped_weapon_changed")
	if _backend.has_signal("equipped_weapon_changed") and _backend.is_connected("equipped_weapon_changed", weapon_callback):
		_backend.disconnect("equipped_weapon_changed", weapon_callback)

	var potion_callback := Callable(self, "_on_backend_equipped_potion_changed")
	if _backend.has_signal("equipped_potion_changed") and _backend.is_connected("equipped_potion_changed", potion_callback):
		_backend.disconnect("equipped_potion_changed", potion_callback)

	if is_instance_valid(_backend):
		_backend.queue_free()
	_backend = null
	_backend_id = ""


func _on_backend_inventory_changed() -> void:
	inventory_changed.emit()


func _on_backend_equipped_weapon_changed(item: Dictionary) -> void:
	equipped_weapon_changed.emit(item)


func _on_backend_equipped_potion_changed(item: Dictionary) -> void:
	equipped_potion_changed.emit(item)


func _call_backend(method: StringName, args: Array = [], default_value = null):
	if _backend == null or not _backend.has_method(method):
		return default_value
	return _backend.callv(method, args)
