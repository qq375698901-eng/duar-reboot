extends RefCounted
class_name PlayerAttributeProfile

enum Profession {
	MARTIAL_ARTIST,
}

const ATTRIBUTE_ATTACK := &"attack"
const ATTRIBUTE_AGILITY := &"agility"
const ATTRIBUTE_VITALITY := &"vitality"
const ATTRIBUTE_SPIRIT := &"spirit"

const ATTRIBUTE_IDS := [
	ATTRIBUTE_ATTACK,
	ATTRIBUTE_AGILITY,
	ATTRIBUTE_VITALITY,
	ATTRIBUTE_SPIRIT,
]

const ATTRIBUTE_DISPLAY_NAMES := {
	ATTRIBUTE_ATTACK: "Attack",
	ATTRIBUTE_AGILITY: "Agility",
	ATTRIBUTE_VITALITY: "Vitality",
	ATTRIBUTE_SPIRIT: "Spirit",
}

const PROFESSION_DEFINITIONS := {
	Profession.MARTIAL_ARTIST: {
		"id": "martial_artist",
		"name": "Martial Artist",
		"base_stats": {
			ATTRIBUTE_ATTACK: 5,
			ATTRIBUTE_AGILITY: 3,
			ATTRIBUTE_VITALITY: 4,
			ATTRIBUTE_SPIRIT: 2,
		},
	},
}

var _profession: int = Profession.MARTIAL_ARTIST
var _free_stat_points: int = 0
var _allocated_stats := {
	ATTRIBUTE_ATTACK: 0,
	ATTRIBUTE_AGILITY: 0,
	ATTRIBUTE_VITALITY: 0,
	ATTRIBUTE_SPIRIT: 0,
}


func set_profession(profession: int) -> void:
	if not PROFESSION_DEFINITIONS.has(profession):
		return

	_profession = profession


func get_profession() -> int:
	return _profession


func get_profession_id() -> String:
	return String(PROFESSION_DEFINITIONS[_profession]["id"])


func get_profession_name() -> String:
	return String(PROFESSION_DEFINITIONS[_profession]["name"])


func get_base_stats() -> Dictionary:
	return (PROFESSION_DEFINITIONS[_profession]["base_stats"] as Dictionary).duplicate(true)


func get_base_stat(attribute_id: StringName) -> int:
	var base_stats: Dictionary = PROFESSION_DEFINITIONS[_profession]["base_stats"]
	return int(base_stats.get(attribute_id, 0))


func get_allocated_stat(attribute_id: StringName) -> int:
	return int(_allocated_stats.get(attribute_id, 0))


func get_total_stat(attribute_id: StringName) -> int:
	return get_base_stat(attribute_id) + get_allocated_stat(attribute_id)


func get_free_stat_points() -> int:
	return _free_stat_points


func add_free_stat_points(amount: int) -> void:
	if amount <= 0:
		return

	_free_stat_points += amount


func spend_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	if not _is_valid_attribute_id(attribute_id):
		return false
	if amount <= 0 or _free_stat_points < amount:
		return false

	_allocated_stats[attribute_id] = int(_allocated_stats.get(attribute_id, 0)) + amount
	_free_stat_points -= amount
	return true


func refund_free_stat_points(attribute_id: StringName, amount: int = 1) -> bool:
	if not _is_valid_attribute_id(attribute_id):
		return false
	if amount <= 0:
		return false

	var spent_points := int(_allocated_stats.get(attribute_id, 0))
	if spent_points < amount:
		return false

	_allocated_stats[attribute_id] = spent_points - amount
	_free_stat_points += amount
	return true


func get_attack_damage_multiplier() -> float:
	return 1.0 + 0.1 * float(get_total_stat(ATTRIBUTE_ATTACK))


func get_movement_speed_multiplier() -> float:
	return 1.0 + 0.02 * float(get_total_stat(ATTRIBUTE_AGILITY))


func get_acceleration_time_scale() -> float:
	return clampf(1.0 - 0.1 * float(get_total_stat(ATTRIBUTE_AGILITY)), 0.1, 1.0)


func get_acceleration_multiplier() -> float:
	var time_scale := get_acceleration_time_scale()
	if time_scale <= 0.0:
		return 1.0
	return 1.0 / time_scale


func get_hp_multiplier() -> float:
	return 1.0 + 0.1 * float(get_total_stat(ATTRIBUTE_VITALITY))


func get_mp_multiplier() -> float:
	return 1.0 + 0.1 * float(get_total_stat(ATTRIBUTE_SPIRIT))


func get_mp_regen_per_sec(base_regen_per_sec: float = 0.0) -> float:
	return maxf(0.0, base_regen_per_sec) + float(get_total_stat(ATTRIBUTE_SPIRIT))


func build_snapshot() -> Dictionary:
	var total_stats := {}
	var allocated_stats := {}
	var base_stats := {}
	for attribute_id in ATTRIBUTE_IDS:
		base_stats[String(attribute_id)] = get_base_stat(attribute_id)
		total_stats[String(attribute_id)] = get_total_stat(attribute_id)
		allocated_stats[String(attribute_id)] = get_allocated_stat(attribute_id)

	return {
		"profession_id": get_profession_id(),
		"profession_name": get_profession_name(),
		"free_stat_points": _free_stat_points,
		"base_stats": base_stats,
		"allocated_stats": allocated_stats,
		"total_stats": total_stats,
		"derived": {
			"attack_damage_multiplier": get_attack_damage_multiplier(),
			"movement_speed_multiplier": get_movement_speed_multiplier(),
			"acceleration_time_scale": get_acceleration_time_scale(),
			"acceleration_multiplier": get_acceleration_multiplier(),
			"hp_multiplier": get_hp_multiplier(),
			"mp_multiplier": get_mp_multiplier(),
			"mp_regen_per_sec": get_mp_regen_per_sec(),
		},
	}


func get_attribute_display_name(attribute_id: StringName) -> String:
	return String(ATTRIBUTE_DISPLAY_NAMES.get(attribute_id, String(attribute_id)))


func _is_valid_attribute_id(attribute_id: StringName) -> bool:
	return ATTRIBUTE_IDS.has(attribute_id)
