extends Node

signal inventory_changed()
signal equipped_weapon_changed(item: Dictionary)
signal equipped_potion_changed(item: Dictionary)

const ITEM_DEBUG_PANEL_SCENE := preload("res://scenes/ui/item_debug_panel.tscn")

const CONTAINER_BACKPACK := &"backpack"
const CONTAINER_WAREHOUSE := &"warehouse"
const CONTAINER_EQUIPPED := &"equipped"
const CONTAINER_EQUIPPED_POTION := &"equipped_potion"
const ITEM_TYPE_WEAPON := "weapon"
const ITEM_TYPE_REINFORCEMENT_STONE := "reinforcement_stone"
const ITEM_TYPE_POTION := "potion"
const ITEM_TYPE_CRAFTING_MATERIAL := "crafting_material"
const ITEM_LONGSWORD_BASIC := "longsword_basic"
const ITEM_SPEAR_BASIC := "spear_basic"
const ITEM_SCRAP_METAL := "scrap_metal"
const ITEM_REINFORCEMENT_STONE_T1_ATTACK := "reinforcement_stone_t1_attack"
const ITEM_REINFORCEMENT_STONE_T1_DEFENSE := "reinforcement_stone_t1_defense"
const ITEM_REINFORCEMENT_STONE_T1_POWER := "reinforcement_stone_t1_power"
const ITEM_REINFORCEMENT_STONE_T1_AGILITY := "reinforcement_stone_t1_agility"
const ITEM_REINFORCEMENT_STONE_T1_VITALITY := "reinforcement_stone_t1_vitality"
const ITEM_REINFORCEMENT_STONE_T1_SPIRIT := "reinforcement_stone_t1_spirit"
const ITEM_POTION_T1_RED := "potion_t1_red"
const DEFAULT_BACKPACK_SIZE := 24
const DEFAULT_WAREHOUSE_SIZE := 64
const REINFORCEMENT_MAX_LEVEL := 4
const DEFAULT_POTION_MAX_STACK := 10
const DEFAULT_CRAFTING_MATERIAL_MAX_STACK := 99

var _backpack_slots: Array = []
var _warehouse_slots: Array = []
var _equipped_weapon: Dictionary = {}
var _equipped_potion: Dictionary = {}
var _next_instance_id: int = 1
var _item_debug_panel: CanvasLayer


func _ready() -> void:
	call_deferred("_initialize_runtime_state")
	call_deferred("_ensure_runtime_item_debug_panel")


func _initialize_runtime_state() -> void:
	_connect_account_runtime_signals()
	_load_from_current_account_or_demo()


func reset_demo_state() -> void:
	_backpack_slots = _build_empty_slots(DEFAULT_BACKPACK_SIZE)
	_warehouse_slots = _build_empty_slots(DEFAULT_WAREHOUSE_SIZE)
	_equipped_weapon = _create_item(ITEM_LONGSWORD_BASIC)
	_equipped_potion = {}
	_backpack_slots[0] = _create_item(ITEM_LONGSWORD_BASIC)
	_backpack_slots[1] = _create_item(ITEM_SPEAR_BASIC)
	_backpack_slots[2] = _create_item(ITEM_LONGSWORD_BASIC)
	_backpack_slots[3] = _create_item(ITEM_REINFORCEMENT_STONE_T1_ATTACK)
	_backpack_slots[4] = _create_item(ITEM_REINFORCEMENT_STONE_T1_DEFENSE)
	_backpack_slots[5] = _create_item(ITEM_REINFORCEMENT_STONE_T1_POWER)
	_backpack_slots[6] = _create_item(ITEM_REINFORCEMENT_STONE_T1_AGILITY)
	_backpack_slots[7] = _create_item(ITEM_REINFORCEMENT_STONE_T1_VITALITY)
	_backpack_slots[8] = _create_item(ITEM_REINFORCEMENT_STONE_T1_SPIRIT)
	_backpack_slots[9] = _create_item(ITEM_POTION_T1_RED)
	_backpack_slots[10] = _create_item(ITEM_POTION_T1_RED)
	_backpack_slots[11] = _create_item(ITEM_POTION_T1_RED)
	_backpack_slots[12] = _create_item(ITEM_SCRAP_METAL)
	_backpack_slots[13] = _create_item(ITEM_SCRAP_METAL)
	_warehouse_slots[0] = _create_item(ITEM_LONGSWORD_BASIC)
	_warehouse_slots[1] = _create_item(ITEM_LONGSWORD_BASIC)
	_warehouse_slots[2] = _create_item(ITEM_LONGSWORD_BASIC)
	_warehouse_slots[3] = _create_item(ITEM_REINFORCEMENT_STONE_T1_DEFENSE)
	_warehouse_slots[4] = _create_item(ITEM_REINFORCEMENT_STONE_T1_ATTACK)
	_warehouse_slots[5] = _create_item(ITEM_POTION_T1_RED)
	_emit_inventory_changed(true, true)


func build_save_state() -> Dictionary:
	return {
		"backpack_slots": _backpack_slots.duplicate(true),
		"warehouse_slots": _warehouse_slots.duplicate(true),
		"equipped_weapon": _equipped_weapon.duplicate(true),
		"equipped_potion": _equipped_potion.duplicate(true),
		"next_instance_id": _next_instance_id,
	}


func load_save_state(state: Dictionary) -> void:
	if state.is_empty():
		reset_demo_state()
		return

	_backpack_slots = _sanitize_slot_array(state.get("backpack_slots", []), DEFAULT_BACKPACK_SIZE)
	_warehouse_slots = _sanitize_slot_array(state.get("warehouse_slots", []), DEFAULT_WAREHOUSE_SIZE)
	_equipped_weapon = _normalize_item_dict((state.get("equipped_weapon", {}) as Dictionary).duplicate(true))
	_equipped_potion = _normalize_item_dict((state.get("equipped_potion", {}) as Dictionary).duplicate(true))
	_next_instance_id = max(1, int(state.get("next_instance_id", 1)))
	_emit_inventory_changed(true, true)


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


func get_equipped_potion() -> Dictionary:
	return _equipped_potion.duplicate(true)


func get_equipped_weapon_scene_path() -> String:
	return String(_equipped_weapon.get("scene_path", ""))


func get_used_backpack_slot_count() -> int:
	return _count_used_slots(_backpack_slots)


func get_used_warehouse_slot_count() -> int:
	return _count_used_slots(_warehouse_slots)


func get_debug_item_catalog() -> Array:
	var preview_next_instance_id: int = _next_instance_id
	var catalog := [
		_create_item(ITEM_LONGSWORD_BASIC),
		_create_item(ITEM_SPEAR_BASIC),
		_create_item(ITEM_REINFORCEMENT_STONE_T1_ATTACK),
		_create_item(ITEM_REINFORCEMENT_STONE_T1_DEFENSE),
		_create_item(ITEM_REINFORCEMENT_STONE_T1_POWER),
		_create_item(ITEM_REINFORCEMENT_STONE_T1_AGILITY),
		_create_item(ITEM_REINFORCEMENT_STONE_T1_VITALITY),
		_create_item(ITEM_REINFORCEMENT_STONE_T1_SPIRIT),
		_create_item(ITEM_POTION_T1_RED),
		_create_item(ITEM_SCRAP_METAL),
	]
	_next_instance_id = preview_next_instance_id
	return catalog


func add_item_to_backpack_by_definition(definition_id: String) -> bool:
	var created_item: Dictionary = _create_item(definition_id)
	if created_item.is_empty():
		return false

	var remainder: Dictionary = _store_item_in_slots(_backpack_slots, created_item)
	if not remainder.is_empty():
		return false

	_emit_inventory_changed(false, false)
	return true


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
	if moving_item is Dictionary and target_item is Dictionary:
		var moving_dict: Dictionary = (moving_item as Dictionary).duplicate(true)
		var target_dict: Dictionary = (target_item as Dictionary).duplicate(true)
		if _can_stack_items(target_dict, moving_dict):
			var merge_result: Dictionary = _merge_stack_items(target_dict, moving_dict)
			to_slots[to_index] = merge_result.get("target", {})
			var remaining_item: Dictionary = merge_result.get("source", {}) as Dictionary
			from_slots[from_index] = null if remaining_item.is_empty() else remaining_item
			_emit_inventory_changed(false, false)
			return true

	from_slots[from_index] = target_item
	to_slots[to_index] = moving_item
	_emit_inventory_changed(false, false)
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
	_emit_inventory_changed(true, false)
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

	_emit_inventory_changed(true, false)
	return true


func equip_potion_from_backpack(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _backpack_slots.size():
		return false

	var value: Variant = _backpack_slots[slot_index]
	if not (value is Dictionary):
		return false

	var item: Dictionary = value as Dictionary
	if String(item.get("item_type", "")) != ITEM_TYPE_POTION:
		return false

	if _equipped_potion.is_empty():
		_equipped_potion = item.duplicate(true)
		_backpack_slots[slot_index] = null
		_emit_inventory_changed(false, true)
		return true

	if _can_stack_items(_equipped_potion, item):
		var merge_result: Dictionary = _merge_stack_items(_equipped_potion.duplicate(true), item.duplicate(true))
		_equipped_potion = merge_result.get("target", {}) as Dictionary
		var remaining_item: Dictionary = merge_result.get("source", {}) as Dictionary
		_backpack_slots[slot_index] = null if remaining_item.is_empty() else remaining_item
		_emit_inventory_changed(false, true)
		return true

	var previous_potion: Dictionary = _equipped_potion.duplicate(true)
	_equipped_potion = item.duplicate(true)
	_backpack_slots[slot_index] = previous_potion
	_emit_inventory_changed(false, true)
	return true


func unequip_potion_to_backpack(target_slot_index: int = -1) -> bool:
	if _equipped_potion.is_empty():
		return false

	if target_slot_index >= _backpack_slots.size():
		return false

	if target_slot_index >= 0:
		var target_value: Variant = _backpack_slots[target_slot_index]
		if target_value == null:
			_backpack_slots[target_slot_index] = _equipped_potion.duplicate(true)
			_equipped_potion = {}
			_emit_inventory_changed(false, true)
			return true
		if target_value is Dictionary:
			var target_item: Dictionary = target_value as Dictionary
			if _can_stack_items(target_item, _equipped_potion):
				var merge_result: Dictionary = _merge_stack_items(target_item.duplicate(true), _equipped_potion.duplicate(true))
				_backpack_slots[target_slot_index] = merge_result.get("target", {}) as Dictionary
				var remaining_item: Dictionary = merge_result.get("source", {}) as Dictionary
				if remaining_item.is_empty():
					_equipped_potion = {}
					_emit_inventory_changed(false, true)
					return true
				return false
		return false

	var remainder: Dictionary = _store_item_in_slots(_backpack_slots, _equipped_potion.duplicate(true))
	if not remainder.is_empty():
		return false

	_equipped_potion = {}
	_emit_inventory_changed(false, true)
	return true


func consume_equipped_potion_one() -> Dictionary:
	if _equipped_potion.is_empty() or String(_equipped_potion.get("item_type", "")) != ITEM_TYPE_POTION:
		return {}

	var consumed_item: Dictionary = _equipped_potion.duplicate(true)
	var current_stack: int = _get_item_stack_count(_equipped_potion)
	if current_stack <= 1:
		_equipped_potion = {}
	else:
		_equipped_potion["stack_count"] = current_stack - 1
	_emit_inventory_changed(false, true)
	return consumed_item


func apply_player_death_penalty() -> void:
	_backpack_slots = _build_empty_slots(DEFAULT_BACKPACK_SIZE)
	_equipped_weapon = {}
	_equipped_potion = {}
	_emit_inventory_changed(true, true)


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


func build_empty_reinforcement_bonus() -> Dictionary:
	return {
		"base_attack_power": 0.0,
		"base_defense_ratio": 0.0,
		"attack": 0,
		"agility": 0,
		"vitality": 0,
		"spirit": 0,
	}


func get_item_total_base_attack_power(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var reinforcement_bonus := _normalize_reinforcement_bonus_data(item.get("reinforcement_bonus", {}))
	return maxf(0.0, float(item.get("base_attack_power", 0.0)) + float(reinforcement_bonus.get("base_attack_power", 0.0)))


func get_item_total_base_defense_ratio(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var reinforcement_bonus := _normalize_reinforcement_bonus_data(item.get("reinforcement_bonus", {}))
	return clampf(
		float(item.get("base_defense_ratio", 0.0)) + float(reinforcement_bonus.get("base_defense_ratio", 0.0)),
		0.0,
		1.0
	)


func get_item_reinforcement_label(item: Dictionary) -> String:
	if item.is_empty() or String(item.get("item_type", "")) != ITEM_TYPE_WEAPON:
		return ""
	return "%d/%d" % [clampi(int(item.get("reinforcement_level", 0)), 0, REINFORCEMENT_MAX_LEVEL), REINFORCEMENT_MAX_LEVEL]


func is_reinforcement_stone(item: Dictionary) -> bool:
	return not item.is_empty() and String(item.get("item_type", "")) == ITEM_TYPE_REINFORCEMENT_STONE


func is_potion(item: Dictionary) -> bool:
	return not item.is_empty() and String(item.get("item_type", "")) == ITEM_TYPE_POTION


func is_crafting_material(item: Dictionary) -> bool:
	return not item.is_empty() and String(item.get("item_type", "")) == ITEM_TYPE_CRAFTING_MATERIAL


func get_scrap_metal_crafting_recipes() -> Array:
	return [
		{
			"product_definition_id": ITEM_LONGSWORD_BASIC,
			"product_display_name": _zh("5LiA6Zi26ZW/5YmR"),
			"cost_definition_id": ITEM_SCRAP_METAL,
			"cost_display_name": _zh("5bqf5byD6YeR5bGe"),
			"cost_count": 1,
			"description": _zh("5Yi25L2c5LiA5oqK5LiA6Zi26ZW/5YmR44CC"),
		},
	]


func craft_from_scrap_metal(source_container: StringName, source_index: int, product_definition_id: String) -> Dictionary:
	var source_item: Dictionary = _get_item_by_ref(source_container, source_index)
	if String(source_item.get("definition_id", "")) != ITEM_SCRAP_METAL:
		return {"success": false, "reason": "invalid_source"}

	var recipe: Dictionary = _get_scrap_metal_recipe(product_definition_id)
	if recipe.is_empty():
		return {"success": false, "reason": "invalid_recipe"}

	var cost_count: int = max(1, int(recipe.get("cost_count", 1)))
	if _get_item_stack_count(source_item) < cost_count:
		return {"success": false, "reason": "insufficient_material"}

	var crafted_item: Dictionary = _create_item(product_definition_id)
	if crafted_item.is_empty():
		return {"success": false, "reason": "invalid_product"}

	if not _can_store_crafted_item_in_backpack(crafted_item, source_container, source_index, cost_count):
		return {"success": false, "reason": "backpack_full"}

	if not _consume_item_stack_by_ref(source_container, source_index, cost_count):
		return {"success": false, "reason": "consume_failed"}

	var remainder: Dictionary = _store_item_in_slots(_backpack_slots, crafted_item.duplicate(true))
	if not remainder.is_empty():
		return {"success": false, "reason": "backpack_full"}

	_emit_inventory_changed(false, false)
	return {
		"success": true,
		"product_definition_id": product_definition_id,
		"crafted_item": crafted_item.duplicate(true),
		"cost_count": cost_count,
	}


func can_item_be_reinforced(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if String(item.get("item_type", "")) != ITEM_TYPE_WEAPON:
		return false
	return int(item.get("reinforcement_level", 0)) < REINFORCEMENT_MAX_LEVEL


func apply_reinforcement_stone(source_container: StringName, source_index: int, target_container: StringName, target_index: int = -1) -> Dictionary:
	var source_item: Dictionary = _get_item_by_ref(source_container, source_index)
	if not is_reinforcement_stone(source_item):
		return {"success": false, "reason": "invalid_source"}

	var target_item: Dictionary = _get_item_by_ref(target_container, target_index)
	if not can_item_be_reinforced(target_item):
		return {"success": false, "reason": "invalid_target"}

	var reinforcement_effect_key: String = String(source_item.get("reinforcement_effect_key", ""))
	if reinforcement_effect_key.is_empty():
		return {"success": false, "reason": "invalid_effect"}

	var rolled_value: Variant = _roll_reinforcement_value(source_item)
	var updated_target: Dictionary = target_item.duplicate(true)
	var reinforcement_bonus: Dictionary = _normalize_reinforcement_bonus_data(updated_target.get("reinforcement_bonus", {}))

	match reinforcement_effect_key:
		"base_attack_power":
			reinforcement_bonus["base_attack_power"] = float(reinforcement_bonus.get("base_attack_power", 0.0)) + float(rolled_value)
		"base_defense_ratio":
			reinforcement_bonus["base_defense_ratio"] = float(reinforcement_bonus.get("base_defense_ratio", 0.0)) + float(rolled_value)
		"attack":
			reinforcement_bonus["attack"] = int(reinforcement_bonus.get("attack", 0)) + int(rolled_value)
		"agility":
			reinforcement_bonus["agility"] = int(reinforcement_bonus.get("agility", 0)) + int(rolled_value)
		"vitality":
			reinforcement_bonus["vitality"] = int(reinforcement_bonus.get("vitality", 0)) + int(rolled_value)
		"spirit":
			reinforcement_bonus["spirit"] = int(reinforcement_bonus.get("spirit", 0)) + int(rolled_value)
		_:
			return {"success": false, "reason": "unsupported_effect"}

	updated_target["reinforcement_bonus"] = reinforcement_bonus
	updated_target["reinforcement_level"] = clampi(int(updated_target.get("reinforcement_level", 0)) + 1, 0, REINFORCEMENT_MAX_LEVEL)
	var history: Array = _normalize_reinforcement_history(updated_target.get("reinforcement_history", []))
	history.append({
		"stone_definition_id": String(source_item.get("definition_id", "")),
		"effect_key": reinforcement_effect_key,
		"value": rolled_value,
		"bonus": {
			reinforcement_effect_key: rolled_value,
		},
	})
	updated_target["reinforcement_history"] = history

	_set_item_by_ref(target_container, target_index, updated_target)
	_set_item_by_ref(source_container, source_index, {})
	_emit_inventory_changed(target_container == CONTAINER_EQUIPPED, false)

	return {
		"success": true,
		"target_container": String(target_container),
		"target_index": target_index,
		"rolled_value": rolled_value,
		"effect_key": reinforcement_effect_key,
		"target_item": updated_target.duplicate(true),
	}


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
				"display_name": _zh("6ZW/5YmR"),
				"scene_path": "res://scenes/weapons/longsword_basic.tscn",
				"icon_path": "res://art/weapons/longsword_basic_preview_12x.png",
				"weapon_mastery_track_id": "longsword",
				"base_attack_power": 10.0,
				"base_defense_ratio": 0.3,
				"equip_weight": 0.0,
				"weapon_tier": 1,
				"reinforcement_level": 0,
				"reinforcement_bonus": build_empty_reinforcement_bonus(),
				"reinforcement_history": [],
				"affixes": PackedStringArray(),
			}
		ITEM_SPEAR_BASIC:
			var spear_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": spear_instance_id,
				"definition_id": ITEM_SPEAR_BASIC,
				"item_type": ITEM_TYPE_WEAPON,
				"display_name": "长枪",
				"scene_path": "res://scenes/weapons/spear_basic.tscn",
				"icon_path": "res://art/weapons/black_diamond_spear_preview_12x.png",
				"weapon_mastery_track_id": "spear",
				"base_attack_power": 12.0,
				"base_defense_ratio": 0.18,
				"equip_weight": 0.18,
				"weapon_tier": 1,
				"reinforcement_level": 0,
				"reinforcement_bonus": build_empty_reinforcement_bonus(),
				"reinforcement_history": [],
				"affixes": PackedStringArray(),
			}
		ITEM_SCRAP_METAL:
			var scrap_metal_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": scrap_metal_instance_id,
				"definition_id": ITEM_SCRAP_METAL,
				"item_type": ITEM_TYPE_CRAFTING_MATERIAL,
				"display_name": _zh("5bqf5byD6YeR5bGe"),
				"icon_path": "res://art/items/scrap_metal.png",
				"stack_count": 1,
				"max_stack": DEFAULT_CRAFTING_MATERIAL_MAX_STACK,
				"effect_description": _zh("5Zyw54mi5Lit6ZqP5Zyw5Y+v6KeB55qE5bqf5byD6YeR5bGe77yM5Y+v5Lul55So5LqO6KOF5aSH55qE5Yi25L2c5ZKM5L+u55CG44CC"),
			}
		ITEM_REINFORCEMENT_STONE_T1_ATTACK:
			var attack_stone_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": attack_stone_instance_id,
				"definition_id": ITEM_REINFORCEMENT_STONE_T1_ATTACK,
				"item_type": ITEM_TYPE_REINFORCEMENT_STONE,
				"display_name": _zh("5LiA6Zi25by65YyW55+z77yI5pS75Ye777yJ"),
				"icon_path": "res://art/items/reinforcement_stone_t1_attack.png",
				"reinforcement_tier": 1,
				"reinforcement_effect_key": "base_attack_power",
				"reinforcement_value_min": 1.0,
				"reinforcement_value_max": 3.0,
				"effect_description": _zh("5L2/5Z+656GA5pS75Ye75Yqb5o+Q6auYIDF+MyDngrnjgII="),
			}
		ITEM_REINFORCEMENT_STONE_T1_DEFENSE:
			var defense_stone_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": defense_stone_instance_id,
				"definition_id": ITEM_REINFORCEMENT_STONE_T1_DEFENSE,
				"item_type": ITEM_TYPE_REINFORCEMENT_STONE,
				"display_name": _zh("5LiA6Zi25by65YyW55+z77yI6Ziy5b6h77yJ"),
				"icon_path": "res://art/items/reinforcement_stone_t1_defense.png",
				"reinforcement_tier": 1,
				"reinforcement_effect_key": "base_defense_ratio",
				"reinforcement_value_min": 0.01,
				"reinforcement_value_max": 0.03,
				"effect_description": _zh("5L2/5Z+656GA6Ziy5b6h546H5o+Q6auYIDElfjMl44CC"),
			}
		ITEM_REINFORCEMENT_STONE_T1_POWER:
			var power_stone_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": power_stone_instance_id,
				"definition_id": ITEM_REINFORCEMENT_STONE_T1_POWER,
				"item_type": ITEM_TYPE_REINFORCEMENT_STONE,
				"display_name": _zh("5LiA6Zi25by65YyW55+z77yI5Yqb6YeP77yJ"),
				"icon_path": "res://art/items/reinforcement_stone_t1_power.png",
				"reinforcement_tier": 1,
				"reinforcement_effect_key": "attack",
				"reinforcement_value_min": 1.0,
				"reinforcement_value_max": 2.0,
				"effect_description": _zh("5L2/6ZmE5Yqg5Yqb6YeP5o+Q6auYIDF+MiDngrnjgII="),
			}
		ITEM_REINFORCEMENT_STONE_T1_AGILITY:
			var agility_stone_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": agility_stone_instance_id,
				"definition_id": ITEM_REINFORCEMENT_STONE_T1_AGILITY,
				"item_type": ITEM_TYPE_REINFORCEMENT_STONE,
				"display_name": _zh("5LiA6Zi25by65YyW55+z77yI5pWP5o2377yJ"),
				"icon_path": "res://art/items/reinforcement_stone_t1_agility.png",
				"reinforcement_tier": 1,
				"reinforcement_effect_key": "agility",
				"reinforcement_value_min": 1.0,
				"reinforcement_value_max": 2.0,
				"effect_description": _zh("5L2/6ZmE5Yqg5pWP5o235o+Q6auYIDF+MiDngrnjgII="),
			}
		ITEM_REINFORCEMENT_STONE_T1_VITALITY:
			var vitality_stone_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": vitality_stone_instance_id,
				"definition_id": ITEM_REINFORCEMENT_STONE_T1_VITALITY,
				"item_type": ITEM_TYPE_REINFORCEMENT_STONE,
				"display_name": _zh("5LiA6Zi25by65YyW55+z77yI5L2T6LSo77yJ"),
				"icon_path": "res://art/items/reinforcement_stone_t1_vitality.png",
				"reinforcement_tier": 1,
				"reinforcement_effect_key": "vitality",
				"reinforcement_value_min": 1.0,
				"reinforcement_value_max": 2.0,
				"effect_description": _zh("5L2/6ZmE5Yqg5L2T6LSo5o+Q6auYIDF+MiDngrnjgII="),
			}
		ITEM_REINFORCEMENT_STONE_T1_SPIRIT:
			var spirit_stone_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": spirit_stone_instance_id,
				"definition_id": ITEM_REINFORCEMENT_STONE_T1_SPIRIT,
				"item_type": ITEM_TYPE_REINFORCEMENT_STONE,
				"display_name": _zh("5LiA6Zi25by65YyW55+z77yI57K+56We77yJ"),
				"icon_path": "res://art/items/reinforcement_stone_t1_spirit.png",
				"reinforcement_tier": 1,
				"reinforcement_effect_key": "spirit",
				"reinforcement_value_min": 1.0,
				"reinforcement_value_max": 2.0,
				"effect_description": _zh("5L2/6ZmE5Yqg57K+56We5o+Q6auYIDF+MiDngrnjgII="),
			}
		ITEM_POTION_T1_RED:
			var potion_instance_id: int = _next_instance_id
			_next_instance_id += 1
			return {
				"instance_id": potion_instance_id,
				"definition_id": ITEM_POTION_T1_RED,
				"item_type": ITEM_TYPE_POTION,
				"display_name": "T1 Red Potion",
				"icon_path": "res://art/items/potion_t1_red.png",
				"stack_count": 1,
				"max_stack": DEFAULT_POTION_MAX_STACK,
				"potion_effect_key": "restore_hp",
				"restore_hp_value": 30.0,
				"use_startup_sec": 3.0,
				"use_move_scale": 0.3,
				"use_jump_scale": 0.3,
				"effect_description": "Restore 30 HP. Use time 3.0s.",
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


func _get_item_by_ref(container_id: StringName, slot_index: int) -> Dictionary:
	if container_id == CONTAINER_EQUIPPED:
		return _equipped_weapon.duplicate(true)
	if container_id == CONTAINER_EQUIPPED_POTION:
		return _equipped_potion.duplicate(true)
	if not _is_valid_slot_ref(container_id, slot_index):
		return {}
	var slots: Array = _get_slots_ref(container_id)
	var value: Variant = slots[slot_index]
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _set_item_by_ref(container_id: StringName, slot_index: int, item: Dictionary) -> void:
	var normalized_item: Dictionary = {}
	if not item.is_empty():
		normalized_item = _normalize_item_dict(item.duplicate(true))

	if container_id == CONTAINER_EQUIPPED:
		_equipped_weapon = normalized_item
		return
	if container_id == CONTAINER_EQUIPPED_POTION:
		_equipped_potion = normalized_item
		return

	if not _is_valid_slot_ref(container_id, slot_index):
		return

	var slots: Array = _get_slots_ref(container_id)
	slots[slot_index] = null if normalized_item.is_empty() else normalized_item


func _emit_inventory_changed(equipped_changed: bool, equipped_potion_changed_flag: bool = false) -> void:
	_persist_to_current_account()
	inventory_changed.emit()
	if equipped_changed:
		equipped_weapon_changed.emit(get_equipped_weapon())
	if equipped_potion_changed_flag:
		equipped_potion_changed.emit(get_equipped_potion())


func _connect_account_runtime_signals() -> void:
	var account_runtime: Node = get_node_or_null("/root/AccountRuntime")
	if account_runtime == null or not account_runtime.has_signal("session_changed"):
		return

	var callback := Callable(self, "_on_account_session_changed")
	if not account_runtime.is_connected("session_changed", callback):
		account_runtime.connect("session_changed", callback)


func _on_account_session_changed(_username: String) -> void:
	_load_from_current_account_or_demo()


func _load_from_current_account_or_demo() -> void:
	var account_runtime: Node = get_node_or_null("/root/AccountRuntime")
	if account_runtime != null \
			and account_runtime.has_method("is_logged_in") \
			and bool(account_runtime.call("is_logged_in")):
		var persisted_state: Dictionary = account_runtime.call("get_current_inventory_state") as Dictionary
		if persisted_state.is_empty():
			reset_demo_state()
		else:
			load_save_state(persisted_state)
		return

	if _backpack_slots.is_empty() and _warehouse_slots.is_empty() and _equipped_weapon.is_empty():
		reset_demo_state()


func _ensure_runtime_item_debug_panel() -> void:
	if _item_debug_panel != null:
		return
	_item_debug_panel = ITEM_DEBUG_PANEL_SCENE.instantiate() as CanvasLayer
	if _item_debug_panel == null:
		return
	_item_debug_panel.name = "ItemDebugPanel"
	add_child(_item_debug_panel)


func _persist_to_current_account() -> void:
	var account_runtime: Node = get_node_or_null("/root/AccountRuntime")
	if account_runtime == null \
			or not account_runtime.has_method("is_logged_in") \
			or not bool(account_runtime.call("is_logged_in")) \
			or not account_runtime.has_method("overwrite_current_inventory_state"):
		return
	account_runtime.call("overwrite_current_inventory_state", build_save_state())


func _sanitize_slot_array(value: Variant, desired_count: int) -> Array:
	var slots: Array = _build_empty_slots(desired_count)
	if not (value is Array):
		return slots

	var source_slots: Array = value as Array
	var copy_count: int = mini(desired_count, source_slots.size())
	for index in range(copy_count):
		var slot_value: Variant = source_slots[index]
		if slot_value is Dictionary:
			slots[index] = _normalize_item_dict((slot_value as Dictionary).duplicate(true))
		else:
			slots[index] = null
	return slots


func _normalize_item_dict(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var definition_id: String = String(item.get("definition_id", ""))
	if definition_id.is_empty():
		return item
	var default_item: Dictionary = _create_item(definition_id)
	if default_item.is_empty():
		return item
	default_item.merge(item, true)
	default_item["base_attack_power"] = float(default_item.get("base_attack_power", 0.0))
	default_item["base_defense_ratio"] = float(default_item.get("base_defense_ratio", 0.0))
	default_item["equip_weight"] = float(default_item.get("equip_weight", 0.0))
	default_item["stack_count"] = clampi(int(default_item.get("stack_count", 1)), 1, max(1, int(default_item.get("max_stack", 1))))
	default_item["max_stack"] = max(1, int(default_item.get("max_stack", 1)))
	default_item["restore_hp_value"] = float(default_item.get("restore_hp_value", 0.0))
	default_item["use_startup_sec"] = maxf(0.0, float(default_item.get("use_startup_sec", 0.0)))
	default_item["use_move_scale"] = clampf(float(default_item.get("use_move_scale", 1.0)), 0.1, 4.0)
	default_item["use_jump_scale"] = clampf(float(default_item.get("use_jump_scale", 1.0)), 0.1, 4.0)
	default_item["weapon_tier"] = max(1, int(default_item.get("weapon_tier", 1)))
	default_item["reinforcement_level"] = clampi(int(default_item.get("reinforcement_level", 0)), 0, REINFORCEMENT_MAX_LEVEL)
	default_item["reinforcement_bonus"] = _normalize_reinforcement_bonus_data(default_item.get("reinforcement_bonus", {}))
	default_item["reinforcement_history"] = _normalize_reinforcement_history(default_item.get("reinforcement_history", []))
	default_item["affixes"] = _normalize_affixes(default_item.get("affixes", PackedStringArray()))
	return default_item


func _normalize_reinforcement_bonus_data(value: Variant) -> Dictionary:
	var normalized := build_empty_reinforcement_bonus()
	if not (value is Dictionary):
		return normalized

	var source: Dictionary = value as Dictionary
	normalized["base_attack_power"] = float(source.get("base_attack_power", 0.0))
	normalized["base_defense_ratio"] = float(source.get("base_defense_ratio", 0.0))
	normalized["attack"] = int(source.get("attack", 0))
	normalized["agility"] = int(source.get("agility", 0))
	normalized["vitality"] = int(source.get("vitality", 0))
	normalized["spirit"] = int(source.get("spirit", 0))
	return normalized


func _normalize_reinforcement_history(value: Variant) -> Array:
	var history: Array = []
	if not (value is Array):
		return history

	for entry in value as Array:
		if entry is Dictionary:
			var normalized_entry: Dictionary = (entry as Dictionary).duplicate(true)
			normalized_entry["bonus"] = _normalize_reinforcement_bonus_data(normalized_entry.get("bonus", {}))
			history.append(normalized_entry)
	return history


func _normalize_affixes(value: Variant) -> PackedStringArray:
	var normalized := PackedStringArray()
	if value is PackedStringArray:
		return value
	if value is Array:
		for entry in value as Array:
			normalized.append(String(entry))
	return normalized


func _roll_reinforcement_value(stone_item: Dictionary) -> Variant:
	var min_value: float = float(stone_item.get("reinforcement_value_min", 0.0))
	var max_value: float = float(stone_item.get("reinforcement_value_max", min_value))
	if max_value < min_value:
		var swap_value: float = min_value
		min_value = max_value
		max_value = swap_value

	randomize()
	var effect_key: String = String(stone_item.get("reinforcement_effect_key", ""))
	if effect_key == "base_defense_ratio":
		return randf_range(min_value, max_value)
	return float(randi_range(int(round(min_value)), int(round(max_value))))


func _is_stackable_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	return int(item.get("max_stack", 1)) > 1


func _get_item_stack_count(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	return max(1, int(item.get("stack_count", 1)))


func _get_item_max_stack(item: Dictionary) -> int:
	if item.is_empty():
		return 1
	return max(1, int(item.get("max_stack", 1)))


func _can_stack_items(target_item: Dictionary, source_item: Dictionary) -> bool:
	if target_item.is_empty() or source_item.is_empty():
		return false
	if not _is_stackable_item(target_item) or not _is_stackable_item(source_item):
		return false
	if String(target_item.get("definition_id", "")) != String(source_item.get("definition_id", "")):
		return false
	return _get_item_stack_count(target_item) < _get_item_max_stack(target_item)


func _merge_stack_items(target_item: Dictionary, source_item: Dictionary) -> Dictionary:
	var updated_target: Dictionary = _normalize_item_dict(target_item.duplicate(true))
	var updated_source: Dictionary = _normalize_item_dict(source_item.duplicate(true))
	var target_count: int = _get_item_stack_count(updated_target)
	var source_count: int = _get_item_stack_count(updated_source)
	var transfer_count: int = min(_get_item_max_stack(updated_target) - target_count, source_count)
	if transfer_count <= 0:
		return {
			"target": updated_target,
			"source": updated_source,
		}

	updated_target["stack_count"] = target_count + transfer_count
	source_count -= transfer_count
	if source_count <= 0:
		updated_source = {}
	else:
		updated_source["stack_count"] = source_count

	return {
		"target": updated_target,
		"source": updated_source,
	}


func _store_item_in_slots(slots: Array, item: Dictionary) -> Dictionary:
	var remaining_item: Dictionary = _normalize_item_dict(item.duplicate(true))
	if remaining_item.is_empty():
		return {}

	if _is_stackable_item(remaining_item):
		for index in range(slots.size()):
			var slot_value: Variant = slots[index]
			if not (slot_value is Dictionary):
				continue
			var existing_item: Dictionary = slot_value as Dictionary
			if not _can_stack_items(existing_item, remaining_item):
				continue
			var merge_result: Dictionary = _merge_stack_items(existing_item.duplicate(true), remaining_item.duplicate(true))
			slots[index] = merge_result.get("target", {}) as Dictionary
			remaining_item = merge_result.get("source", {}) as Dictionary
			if remaining_item.is_empty():
				return {}

	for index in range(slots.size()):
		if slots[index] != null:
			continue
		if _is_stackable_item(remaining_item):
			var placed_item: Dictionary = remaining_item.duplicate(true)
			var placed_count: int = min(_get_item_stack_count(remaining_item), _get_item_max_stack(remaining_item))
			placed_item["stack_count"] = placed_count
			slots[index] = placed_item
			var remaining_count: int = _get_item_stack_count(remaining_item) - placed_count
			if remaining_count <= 0:
				return {}
			remaining_item["stack_count"] = remaining_count
			continue

		slots[index] = remaining_item
		return {}

	return remaining_item


func _get_scrap_metal_recipe(product_definition_id: String) -> Dictionary:
	for recipe_value in get_scrap_metal_crafting_recipes():
		if not (recipe_value is Dictionary):
			continue
		var recipe: Dictionary = recipe_value as Dictionary
		if String(recipe.get("product_definition_id", "")) == product_definition_id:
			return recipe
	return {}


func _can_store_crafted_item_in_backpack(item: Dictionary, source_container: StringName, source_index: int, consume_count: int) -> bool:
	var preview_slots: Array = _backpack_slots.duplicate(true)
	if source_container == CONTAINER_BACKPACK and source_index >= 0 and source_index < preview_slots.size():
		var source_value: Variant = preview_slots[source_index]
		if source_value is Dictionary:
			var updated_source_item: Dictionary = _consume_item_stack_preview((source_value as Dictionary).duplicate(true), consume_count)
			preview_slots[source_index] = null if updated_source_item.is_empty() else updated_source_item

	var remainder: Dictionary = _store_item_in_slots(preview_slots, item.duplicate(true))
	return remainder.is_empty()


func _consume_item_stack_by_ref(container_id: StringName, slot_index: int, consume_count: int) -> bool:
	if consume_count <= 0:
		return false

	var item: Dictionary = _get_item_by_ref(container_id, slot_index)
	if item.is_empty():
		return false
	if _get_item_stack_count(item) < consume_count:
		return false

	var updated_item: Dictionary = _consume_item_stack_preview(item, consume_count)
	_set_item_by_ref(container_id, slot_index, updated_item)
	return true


func _consume_item_stack_preview(item: Dictionary, consume_count: int) -> Dictionary:
	if item.is_empty():
		return {}
	var remaining_count: int = _get_item_stack_count(item) - max(0, consume_count)
	if remaining_count <= 0:
		return {}
	var updated_item: Dictionary = item.duplicate(true)
	updated_item["stack_count"] = remaining_count
	return updated_item


func _zh(encoded: String) -> String:
	return Marshalls.base64_to_utf8(encoded)
