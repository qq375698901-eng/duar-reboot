extends Node

signal inventory_changed()
signal equipped_weapon_changed(item: Dictionary)

const CONTAINER_BACKPACK := &"backpack"
const CONTAINER_WAREHOUSE := &"warehouse"
const ITEM_TYPE_WEAPON := "weapon"
const ITEM_LONGSWORD_BASIC := "longsword_basic"
const DEFAULT_BACKPACK_SIZE := 24
const DEFAULT_WAREHOUSE_SIZE := 64

var _backpack_slots: Array = []
var _warehouse_slots: Array = []
var _equipped_weapon: Dictionary = {}
var _next_instance_id: int = 1


func _ready() -> void:
	if _backpack_slots.is_empty() and _warehouse_slots.is_empty() and _equipped_weapon.is_empty():
		reset_demo_state()


func reset_demo_state() -> void:
	_backpack_slots = _build_empty_slots(DEFAULT_BACKPACK_SIZE)
	_warehouse_slots = _build_empty_slots(DEFAULT_WAREHOUSE_SIZE)
	_equipped_weapon = _create_item(ITEM_LONGSWORD_BASIC)
	_backpack_slots[0] = _create_item(ITEM_LONGSWORD_BASIC)
	_backpack_slots[1] = _create_item(ITEM_LONGSWORD_BASIC)
	_backpack_slots[2] = _create_item(ITEM_LONGSWORD_BASIC)
	_warehouse_slots[0] = _create_item(ITEM_LONGSWORD_BASIC)
	_warehouse_slots[1] = _create_item(ITEM_LONGSWORD_BASIC)
	_warehouse_slots[2] = _create_item(ITEM_LONGSWORD_BASIC)
	_emit_inventory_changed(true)


func get_backpack_capacity() -> int:
	return _backpack_slots.size()


func get_warehouse_capacity() -> int:
	return _warehouse_slots.size()


func get_backpack_slots() -> Array:
	return _backpack_slots.duplicate(true)


func get_warehouse_slots() -> Array:
	return _warehouse_slots.duplicate(true)


func get_equipped_weapon() -> Dictionary:
	return _equipped_weapon.duplicate(true)


func get_equipped_weapon_scene_path() -> String:
	return String(_equipped_weapon.get("scene_path", ""))


func get_used_backpack_slot_count() -> int:
	return _count_used_slots(_backpack_slots)


func get_used_warehouse_slot_count() -> int:
	return _count_used_slots(_warehouse_slots)


func move_item(from_container: StringName, from_index: int, to_container: StringName, to_index: int) -> bool:
	if not _is_valid_slot_ref(from_container, from_index):
		return false
	if not _is_valid_slot_ref(to_container, to_index):
		return false
	if from_container == to_container and from_index == to_index:
		return false

	var from_slots: Array = _get_slots_ref(from_container)
	var to_slots: Array = _get_slots_ref(to_container)
	var moving_item: Variant = from_slots[from_index]
	if moving_item == null:
		return false

	var target_item: Variant = to_slots[to_index]
	from_slots[from_index] = target_item
	to_slots[to_index] = moving_item
	_emit_inventory_changed(false)
	return true


func equip_from_backpack(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _backpack_slots.size():
		return false

	var item: Variant = _backpack_slots[slot_index]
	if not (item is Dictionary):
		return false
	if String(item.get("item_type", "")) != ITEM_TYPE_WEAPON:
		return false

	var previous_weapon: Dictionary = _equipped_weapon.duplicate(true)
	_equipped_weapon = (item as Dictionary).duplicate(true)
	if previous_weapon.is_empty():
		_backpack_slots[slot_index] = null
	else:
		_backpack_slots[slot_index] = previous_weapon
	_emit_inventory_changed(true)
	return true


func unequip_to_backpack(target_slot_index: int = -1) -> bool:
	if _equipped_weapon.is_empty():
		return false

	var resolved_index: int = target_slot_index
	if resolved_index < 0:
		resolved_index = find_first_empty_backpack_slot()
		if resolved_index < 0:
			return false
	elif resolved_index >= _backpack_slots.size():
		return false

	var previous_item: Variant = _backpack_slots[resolved_index]
	_backpack_slots[resolved_index] = _equipped_weapon.duplicate(true)
	if previous_item is Dictionary and not (previous_item as Dictionary).is_empty():
		_equipped_weapon = (previous_item as Dictionary).duplicate(true)
	else:
		_equipped_weapon = {}

	_emit_inventory_changed(true)
	return true


func find_first_empty_backpack_slot() -> int:
	for index in range(_backpack_slots.size()):
		if _backpack_slots[index] == null:
			return index
	return -1


func find_first_empty_warehouse_slot() -> int:
	for index in range(_warehouse_slots.size()):
		if _warehouse_slots[index] == null:
			return index
	return -1


func _build_empty_slots(count: int) -> Array:
	var slots: Array = []
	slots.resize(count)
	for index in range(count):
		slots[index] = null
	return slots


func _count_used_slots(slots: Array) -> int:
	var used: int = 0
	for item in slots:
		if item != null:
			used += 1
	return used


func _create_item(definition_id: String) -> Dictionary:
	match definition_id:
		ITEM_LONGSWORD_BASIC:
			var instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": instance_id,
				"definition_id": ITEM_LONGSWORD_BASIC,
				"item_type": ITEM_TYPE_WEAPON,
				"display_name": "Longsword",
				"scene_path": "res://scenes/weapons/longsword_basic.tscn",
				"base_attack_power": 10.0,
				"base_defense_ratio": 0.3,
				"equip_weight": 0.0,
				"weapon_tier": 1,
				"reinforcement_level": 0,
				"affixes": PackedStringArray(),
			}
		_:
			return {}


func _get_slots_ref(container_id: StringName) -> Array:
	if container_id == CONTAINER_BACKPACK:
		return _backpack_slots
	return _warehouse_slots


func _is_valid_slot_ref(container_id: StringName, slot_index: int) -> bool:
	if slot_index < 0:
		return false
	if container_id == CONTAINER_BACKPACK:
		return slot_index < _backpack_slots.size()
	if container_id == CONTAINER_WAREHOUSE:
		return slot_index < _warehouse_slots.size()
	return false


func _emit_inventory_changed(equipped_changed: bool) -> void:
	inventory_changed.emit()
	if equipped_changed:
		equipped_weapon_changed.emit(get_equipped_weapon())
