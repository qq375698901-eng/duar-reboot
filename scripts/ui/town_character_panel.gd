extends Control

const PlayerAttributeProfile = preload("res://scripts/characters/player_attribute_profile.gd")
const LONGSWORD_BASIC_SCENE = preload("res://scenes/weapons/longsword_basic.tscn")

@export var character_source_path: NodePath
@export var fallback_display_name: String = "Adventurer"
@export var fallback_specialization_level: int = 1
@export var fallback_weapon_mastery_level: int = 0
@export var fallback_free_stat_points: int = 0

@onready var subtitle_label: Label = $PanelShell/Subtitle
@onready var profile_name_label: Label = $PanelShell/ProfileCard/ProfileName
@onready var profile_job_label: Label = $PanelShell/ProfileCard/ProfileJob
@onready var profile_flavor_label: Label = $PanelShell/ProfileCard/ProfileFlavor
@onready var profile_meta_body_label: Label = $PanelShell/ProfileCard/ProfileMetaBody
@onready var free_point_text: Label = $PanelShell/StatsCard/FreePointValue/FreePointText
@onready var stats_footer_label: Label = $PanelShell/StatsCard/StatsFooter
@onready var weapon_name_label: Label = $PanelShell/WeaponCard/WeaponName
@onready var weapon_attack_value_label: Label = $PanelShell/WeaponCard/WeaponAtkValue
@onready var weapon_defense_value_label: Label = $PanelShell/WeaponCard/WeaponDefValue
@onready var weapon_mastery_value_label: Label = $PanelShell/WeaponCard/WeaponMasteryValue
@onready var class_swap_button: Button = $PanelShell/ClassCard/ClassSwapButton
@onready var class_value_label: Label = $PanelShell/ClassCard/ClassValue
@onready var spec_value_label: Label = $PanelShell/ClassCard/SpecValue
@onready var class_hint_label: Label = $PanelShell/ClassCard/ClassHint

var _character_source: Node
var _fallback_profile: PlayerAttributeProfile
var _fallback_weapon: Node
var _stat_rows: Dictionary = {}
var _inventory_runtime: Node


func _ready() -> void:
	_cache_stat_rows()
	_setup_fallback_state()
	_inventory_runtime = get_node_or_null("/root/InventoryRuntime")
	_connect_inventory_runtime_signals()
	bind_character_source(get_node_or_null(character_source_path))
	_refresh_all()


func bind_character_source(source: Node) -> void:
	if _character_source != null:
		_disconnect_character_source_signals()

	_character_source = source
	_connect_character_source_signals()
	_refresh_all()


func refresh_display() -> void:
	_refresh_all()


func _cache_stat_rows() -> void:
	_register_stat_row(PlayerAttributeProfile.ATTRIBUTE_ATTACK, $PanelShell/StatsCard/StatRow1)
	_register_stat_row(PlayerAttributeProfile.ATTRIBUTE_AGILITY, $PanelShell/StatsCard/StatRow2)
	_register_stat_row(PlayerAttributeProfile.ATTRIBUTE_VITALITY, $PanelShell/StatsCard/StatRow3)
	_register_stat_row(PlayerAttributeProfile.ATTRIBUTE_SPIRIT, $PanelShell/StatsCard/StatRow4)


func _register_stat_row(attribute_id: StringName, row_node: Control) -> void:
	var plus_button: Button = row_node.get_node("PlusButton")
	plus_button.pressed.connect(_on_stat_plus_button_pressed.bind(attribute_id))
	_stat_rows[attribute_id] = {
		"row": row_node,
		"value_label": row_node.get_node("StatValue") as Label,
		"plus_button": plus_button,
	}


func _setup_fallback_state() -> void:
	_fallback_profile = PlayerAttributeProfile.new()
	_fallback_profile.set_profession(PlayerAttributeProfile.Profession.MARTIAL_ARTIST)
	if fallback_free_stat_points > 0:
		_fallback_profile.add_free_stat_points(fallback_free_stat_points)

	_fallback_weapon = LONGSWORD_BASIC_SCENE.instantiate()


func _connect_inventory_runtime_signals() -> void:
	if _inventory_runtime == null or not _inventory_runtime.has_signal("inventory_changed"):
		return

	var callback := Callable(self, "_on_inventory_runtime_changed")
	if not _inventory_runtime.is_connected("inventory_changed", callback):
		_inventory_runtime.connect("inventory_changed", callback)


func _on_inventory_runtime_changed() -> void:
	_refresh_all()


func _connect_character_source_signals() -> void:
	if _character_source == null:
		return
	if _character_source.has_signal("attribute_profile_changed"):
		_character_source.connect("attribute_profile_changed", Callable(self, "_on_character_source_changed"))
	if _character_source.has_signal("resources_changed"):
		_character_source.connect("resources_changed", Callable(self, "_on_character_source_changed"))


func _disconnect_character_source_signals() -> void:
	if _character_source == null:
		return
	if _character_source.has_signal("attribute_profile_changed"):
		var attr_callable := Callable(self, "_on_character_source_changed")
		if _character_source.is_connected("attribute_profile_changed", attr_callable):
			_character_source.disconnect("attribute_profile_changed", attr_callable)
	if _character_source.has_signal("resources_changed"):
		var res_callable := Callable(self, "_on_character_source_changed")
		if _character_source.is_connected("resources_changed", res_callable):
			_character_source.disconnect("resources_changed", res_callable)


func _on_character_source_changed(_a = null, _b = null, _c = null, _d = null) -> void:
	_refresh_all()


func _refresh_all() -> void:
	var snapshot: Dictionary = _get_attribute_snapshot()
	_refresh_profile_card(snapshot)
	_refresh_stats_card(snapshot)
	_refresh_weapon_card()
	_refresh_class_card(snapshot)


func _refresh_profile_card(snapshot: Dictionary) -> void:
	var profession_name: String = String(snapshot.get("profession_name", "Martial Artist"))
	var spec_level: int = _get_specialization_level()
	var current_hp: float = float(snapshot.get("current_hp", snapshot.get("effective_max_hp", 0.0)))
	var effective_max_hp: float = float(snapshot.get("effective_max_hp", 0.0))
	var current_mp: float = float(snapshot.get("current_mp", snapshot.get("effective_max_mp", 0.0)))
	var effective_max_mp: float = float(snapshot.get("effective_max_mp", 0.0))

	profile_name_label.text = _get_display_name()
	profile_job_label.text = "%s / Spec Lv.%d" % [profession_name, spec_level]
	profile_flavor_label.text = _get_profession_flavor_text(profession_name)
	profile_meta_body_label.text = "HP %.0f / %.0f\nMP %.0f / %.0f\nWeapon: %s\nFree Points: %d" % [
		current_hp,
		effective_max_hp,
		current_mp,
		effective_max_mp,
		_get_weapon_display_name(),
		int(snapshot.get("free_stat_points", 0)),
	]


func _refresh_stats_card(snapshot: Dictionary) -> void:
	var total_stats: Dictionary = snapshot.get("total_stats", {})
	var free_points: int = int(snapshot.get("free_stat_points", 0))

	free_point_text.text = str(free_points)
	for attribute_id in _stat_rows.keys():
		var row_data: Dictionary = _stat_rows[attribute_id]
		var value_label: Label = row_data["value_label"]
		var plus_button: Button = row_data["plus_button"]
		value_label.text = str(int(total_stats.get(String(attribute_id), 0)))
		plus_button.disabled = not _can_allocate_attribute_points(free_points)

	stats_footer_label.text = "Attribute points available." if free_points > 0 else "No free attribute points available."


func _refresh_weapon_card() -> void:
	var weapon: Variant = _resolve_weapon_source()
	var weapon_name: String = "Unarmed"
	var base_attack_power: float = 0.0
	var defense_ratio: float = 0.0

	if weapon != null:
		weapon_name = _read_weapon_display_name(weapon)
		base_attack_power = _read_weapon_base_attack_power(weapon)
		defense_ratio = _read_weapon_defense_ratio(weapon)

	weapon_name_label.text = weapon_name
	weapon_attack_value_label.text = str(snappedf(base_attack_power, 0.1))
	weapon_defense_value_label.text = "%d%%" % int(round(defense_ratio * 100.0))
	weapon_mastery_value_label.text = "Lv.%d" % _get_weapon_mastery_level()


func _refresh_class_card(snapshot: Dictionary) -> void:
	class_value_label.text = String(snapshot.get("profession_name", "Martial Artist"))
	spec_value_label.text = str(_get_specialization_level())
	class_hint_label.text = "Class swap is unavailable until more professions are implemented."
	class_swap_button.disabled = true


func _get_attribute_snapshot() -> Dictionary:
	if _character_source != null and _character_source.has_method("get_attribute_snapshot"):
		return _character_source.call("get_attribute_snapshot") as Dictionary

	var effective_max_hp: float = 100.0 * _fallback_profile.get_hp_multiplier()
	var effective_max_mp: float = 100.0 + _fallback_profile.get_bonus_max_mp()
	return {
		"profession_name": _fallback_profile.get_profession_name(),
		"free_stat_points": _fallback_profile.get_free_stat_points(),
		"current_hp": effective_max_hp,
		"effective_max_hp": effective_max_hp,
		"current_mp": effective_max_mp,
		"effective_max_mp": effective_max_mp,
		"total_stats": _build_profile_total_stats(_fallback_profile),
	}


func _build_profile_total_stats(profile: PlayerAttributeProfile) -> Dictionary:
	return {
		String(PlayerAttributeProfile.ATTRIBUTE_ATTACK): profile.get_total_stat(PlayerAttributeProfile.ATTRIBUTE_ATTACK),
		String(PlayerAttributeProfile.ATTRIBUTE_AGILITY): profile.get_total_stat(PlayerAttributeProfile.ATTRIBUTE_AGILITY),
		String(PlayerAttributeProfile.ATTRIBUTE_VITALITY): profile.get_total_stat(PlayerAttributeProfile.ATTRIBUTE_VITALITY),
		String(PlayerAttributeProfile.ATTRIBUTE_SPIRIT): profile.get_total_stat(PlayerAttributeProfile.ATTRIBUTE_SPIRIT),
	}


func _get_display_name() -> String:
	if _character_source != null and _character_source.has_method("get_display_name"):
		return String(_character_source.call("get_display_name"))
	return fallback_display_name


func _get_specialization_level() -> int:
	if _character_source != null and _character_source.has_method("get_specialization_level"):
		return int(_character_source.call("get_specialization_level"))
	return fallback_specialization_level


func _get_weapon_mastery_level() -> int:
	if _character_source != null and _character_source.has_method("get_weapon_mastery_level"):
		return int(_character_source.call("get_weapon_mastery_level"))
	return fallback_weapon_mastery_level


func _get_profession_flavor_text(profession_name: String) -> String:
	if profession_name == "Martial Artist":
		return "Frontline pressure fighter\nwith counters and sustain."
	return "No flavor text available."


func _get_weapon_display_name() -> String:
	return _read_weapon_display_name(_resolve_weapon_source())


func _resolve_weapon_source() -> Variant:
	if _character_source != null and _character_source.has_method("get_equipped_weapon_node"):
		var equipped_weapon: Variant = _character_source.call("get_equipped_weapon_node")
		if equipped_weapon is Node:
			return equipped_weapon
	if _inventory_runtime != null and _inventory_runtime.has_method("get_equipped_weapon"):
		var equipped_item: Dictionary = _inventory_runtime.call("get_equipped_weapon") as Dictionary
		if not equipped_item.is_empty():
			return equipped_item
		return null
	return _fallback_weapon


func _read_weapon_display_name(weapon: Variant) -> String:
	if weapon == null:
		return "Unarmed"
	if weapon is Dictionary:
		return String((weapon as Dictionary).get("display_name", "Longsword"))
	if weapon.has_method("get_display_name"):
		return String(weapon.call("get_display_name"))
	var display_name: Variant = weapon.get("display_name")
	if display_name != null:
		return String(display_name)
	return "Longsword"


func _read_weapon_base_attack_power(weapon: Variant) -> float:
	if weapon == null:
		return 0.0
	if weapon is Dictionary:
		return float((weapon as Dictionary).get("base_attack_power", 0.0))
	if weapon.has_method("get_base_attack_power"):
		return float(weapon.call("get_base_attack_power"))
	return float(weapon.get("base_attack_power"))


func _read_weapon_defense_ratio(weapon: Variant) -> float:
	if weapon == null:
		return 0.0
	if weapon is Dictionary:
		return float((weapon as Dictionary).get("base_defense_ratio", 0.0))
	if weapon.has_method("get_base_defense_ratio"):
		return float(weapon.call("get_base_defense_ratio"))
	return float(weapon.get("base_defense_ratio"))


func _can_allocate_attribute_points(free_points: int) -> bool:
	if free_points <= 0:
		return false
	if _character_source == null:
		return true
	return _character_source.has_method("allocate_free_stat_points")


func _on_stat_plus_button_pressed(attribute_id: StringName) -> void:
	if _character_source != null and _character_source.has_method("allocate_free_stat_points"):
		var did_allocate: bool = bool(_character_source.call("allocate_free_stat_points", attribute_id, 1))
		if did_allocate:
			_refresh_all()
		return

	if _fallback_profile != null and _fallback_profile.spend_free_stat_points(attribute_id, 1):
		_refresh_all()


func _exit_tree() -> void:
	_disconnect_character_source_signals()
	if is_instance_valid(_fallback_weapon):
		_fallback_weapon.free()
