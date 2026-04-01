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

const DEFAULT_SPECIALIZATION_LEVEL := 1
const DEFAULT_SPECIALIZATION_EXP := 0
const DEFAULT_WEAPON_MASTERY_LEVEL := 0
const DEFAULT_WEAPON_MASTERY_EXP := 0
const DEFAULT_WEAPON_MASTERY_TRACK := "longsword"
const SPECIALIZATION_EXP_REQUIREMENTS := [100, 160, 260, 420, 680, 1040, 1520, 2140]
const WEAPON_MASTERY_EXP_REQUIREMENTS := [60, 90, 140, 220, 340, 520, 760, 1080]
const SPECIALIZATION_EXP_TAIL_GROWTH := 1.42
const WEAPON_MASTERY_EXP_TAIL_GROWTH := 1.38

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
var _specialization_level: int = DEFAULT_SPECIALIZATION_LEVEL
var _specialization_exp: int = DEFAULT_SPECIALIZATION_EXP
var _weapon_mastery_levels: Dictionary = {}
var _weapon_mastery_exps: Dictionary = {}
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


func get_specialization_level() -> int:
	return max(1, _specialization_level)


func set_specialization_level(value: int) -> void:
	_specialization_level = max(1, value)


func add_specialization_levels(amount: int) -> void:
	if amount <= 0:
		return
	_specialization_level = max(1, _specialization_level + amount)


func get_specialization_exp() -> int:
	return max(0, _specialization_exp)


func get_specialization_exp_to_next_level() -> int:
	return _get_progression_requirement(
		SPECIALIZATION_EXP_REQUIREMENTS,
		max(0, get_specialization_level() - 1),
		SPECIALIZATION_EXP_TAIL_GROWTH
	)


func add_specialization_exp(amount: int) -> void:
	if amount <= 0:
		return

	_specialization_exp = max(0, _specialization_exp + amount)
	var exp_to_next_level := get_specialization_exp_to_next_level()
	while _specialization_exp >= exp_to_next_level:
		_specialization_exp -= exp_to_next_level
		_specialization_level = max(1, _specialization_level + 1)
		exp_to_next_level = get_specialization_exp_to_next_level()


func get_weapon_mastery_level(track_id: String = DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	var normalized_track_id: String = _normalize_weapon_mastery_track_id(track_id)
	return max(0, int(_weapon_mastery_levels.get(normalized_track_id, DEFAULT_WEAPON_MASTERY_LEVEL)))


func set_weapon_mastery_level(track_id: String, value: int) -> void:
	var normalized_track_id: String = _normalize_weapon_mastery_track_id(track_id)
	_weapon_mastery_levels[normalized_track_id] = max(0, value)


func add_weapon_mastery_levels(track_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var normalized_track_id: String = _normalize_weapon_mastery_track_id(track_id)
	_weapon_mastery_levels[normalized_track_id] = get_weapon_mastery_level(normalized_track_id) + amount


func get_weapon_mastery_exp(track_id: String = DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	var normalized_track_id: String = _normalize_weapon_mastery_track_id(track_id)
	return max(0, int(_weapon_mastery_exps.get(normalized_track_id, DEFAULT_WEAPON_MASTERY_EXP)))


func get_weapon_mastery_exp_to_next_level(track_id: String = DEFAULT_WEAPON_MASTERY_TRACK) -> int:
	var mastery_level: int = get_weapon_mastery_level(track_id)
	return _get_progression_requirement(
		WEAPON_MASTERY_EXP_REQUIREMENTS,
		max(0, mastery_level),
		WEAPON_MASTERY_EXP_TAIL_GROWTH
	)


func add_weapon_mastery_exp(track_id: String, amount: int) -> void:
	if amount <= 0:
		return

	var normalized_track_id: String = _normalize_weapon_mastery_track_id(track_id)
	var current_exp: int = get_weapon_mastery_exp(normalized_track_id) + amount
	var current_level: int = get_weapon_mastery_level(normalized_track_id)
	var exp_to_next_level: int = get_weapon_mastery_exp_to_next_level(normalized_track_id)
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		current_level += 1
		exp_to_next_level = _get_progression_requirement(
			WEAPON_MASTERY_EXP_REQUIREMENTS,
			max(0, current_level),
			WEAPON_MASTERY_EXP_TAIL_GROWTH
		)

	_weapon_mastery_levels[normalized_track_id] = max(0, current_level)
	_weapon_mastery_exps[normalized_track_id] = max(0, current_exp)


func get_all_weapon_mastery_levels() -> Dictionary:
	return _weapon_mastery_levels.duplicate(true)


func get_all_weapon_mastery_exps() -> Dictionary:
	return _weapon_mastery_exps.duplicate(true)


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


func get_bonus_max_mp() -> float:
	return float(get_total_stat(ATTRIBUTE_SPIRIT))


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
		"specialization_level": get_specialization_level(),
		"specialization_exp": get_specialization_exp(),
		"specialization_exp_to_next_level": get_specialization_exp_to_next_level(),
		"weapon_mastery_levels": get_all_weapon_mastery_levels(),
		"weapon_mastery_exps": get_all_weapon_mastery_exps(),
		"base_stats": base_stats,
		"allocated_stats": allocated_stats,
		"total_stats": total_stats,
		"derived": {
			"attack_damage_multiplier": get_attack_damage_multiplier(),
			"movement_speed_multiplier": get_movement_speed_multiplier(),
			"acceleration_time_scale": get_acceleration_time_scale(),
			"acceleration_multiplier": get_acceleration_multiplier(),
			"hp_multiplier": get_hp_multiplier(),
			"max_mp_bonus": get_bonus_max_mp(),
			"mp_regen_per_sec": get_mp_regen_per_sec(),
		},
	}


func get_attribute_display_name(attribute_id: StringName) -> String:
	return String(ATTRIBUTE_DISPLAY_NAMES.get(attribute_id, String(attribute_id)))


func export_persisted_state() -> Dictionary:
	var allocated_stats: Dictionary = {}
	for attribute_id in ATTRIBUTE_IDS:
		allocated_stats[String(attribute_id)] = get_allocated_stat(attribute_id)

	return {
		"profession": _profession,
		"profession_id": get_profession_id(),
		"free_stat_points": _free_stat_points,
		"specialization_level": get_specialization_level(),
		"specialization_exp": get_specialization_exp(),
		"weapon_mastery_levels": get_all_weapon_mastery_levels(),
		"weapon_mastery_exps": get_all_weapon_mastery_exps(),
		"allocated_stats": allocated_stats,
	}


func load_persisted_state(state: Dictionary) -> void:
	_profession = Profession.MARTIAL_ARTIST
	_free_stat_points = 0
	_specialization_level = DEFAULT_SPECIALIZATION_LEVEL
	_specialization_exp = DEFAULT_SPECIALIZATION_EXP
	_weapon_mastery_levels = {
		DEFAULT_WEAPON_MASTERY_TRACK: DEFAULT_WEAPON_MASTERY_LEVEL,
	}
	_weapon_mastery_exps = {
		DEFAULT_WEAPON_MASTERY_TRACK: DEFAULT_WEAPON_MASTERY_EXP,
	}
	_allocated_stats = {
		ATTRIBUTE_ATTACK: 0,
		ATTRIBUTE_AGILITY: 0,
		ATTRIBUTE_VITALITY: 0,
		ATTRIBUTE_SPIRIT: 0,
	}

	if state.is_empty():
		return

	var persisted_profession: int = int(state.get("profession", Profession.MARTIAL_ARTIST))
	set_profession(persisted_profession)
	_free_stat_points = max(0, int(state.get("free_stat_points", 0)))
	_specialization_level = max(1, int(state.get("specialization_level", DEFAULT_SPECIALIZATION_LEVEL)))
	_specialization_exp = max(0, int(state.get("specialization_exp", DEFAULT_SPECIALIZATION_EXP)))

	var persisted_weapon_mastery_levels: Dictionary = state.get("weapon_mastery_levels", {}) as Dictionary
	for track_key in persisted_weapon_mastery_levels.keys():
		var normalized_track_key: String = _normalize_weapon_mastery_track_id(String(track_key))
		_weapon_mastery_levels[normalized_track_key] = max(0, int(persisted_weapon_mastery_levels.get(track_key, DEFAULT_WEAPON_MASTERY_LEVEL)))

	var persisted_weapon_mastery_exps: Dictionary = state.get("weapon_mastery_exps", {}) as Dictionary
	for track_exp_key in persisted_weapon_mastery_exps.keys():
		var normalized_track_exp_key: String = _normalize_weapon_mastery_track_id(String(track_exp_key))
		_weapon_mastery_exps[normalized_track_exp_key] = max(0, int(persisted_weapon_mastery_exps.get(track_exp_key, DEFAULT_WEAPON_MASTERY_EXP)))

	var persisted_allocated_stats: Dictionary = state.get("allocated_stats", {}) as Dictionary
	for attribute_id in ATTRIBUTE_IDS:
		var attribute_key: String = String(attribute_id)
		_allocated_stats[attribute_id] = max(0, int(persisted_allocated_stats.get(attribute_key, 0)))


func _is_valid_attribute_id(attribute_id: StringName) -> bool:
	return ATTRIBUTE_IDS.has(attribute_id)


func _normalize_weapon_mastery_track_id(track_id: String) -> String:
	var normalized_track_id: String = track_id.strip_edges().to_lower()
	if normalized_track_id.is_empty():
		return DEFAULT_WEAPON_MASTERY_TRACK
	return normalized_track_id


func _get_progression_requirement(requirements: Array, level_index: int, tail_growth: float) -> int:
	var safe_level_index: int = max(0, level_index)
	if safe_level_index < requirements.size():
		return max(1, int(requirements[safe_level_index]))

	var requirement: float = float(requirements[requirements.size() - 1])
	for _step in range(requirements.size(), safe_level_index + 1):
		requirement = ceilf(requirement * maxf(1.05, tail_growth))
	return max(1, int(requirement))
