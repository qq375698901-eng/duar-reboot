extends Control
const LONGSWORD_BASIC_SCENE = preload("res://scenes/weapons/longsword_basic.tscn")

@export var character_source_path: NodePath
@export var fallback_display_name: String = "Adventurer"
@export var fallback_specialization_level: int = 1
@export var fallback_weapon_mastery_level: int = 0
@export var fallback_free_stat_points: int = 0

@onready var subtitle_label: Label = $PanelShell/Subtitle
@onready var profile_name_label: Label = $PanelShell/ProfileCard/ProfileName
@onready var profile_job_label: Label = $PanelShell/ProfileCard/ProfileJob
@onready var profile_deprecated_nodes: Array[CanvasItem] = [
	$PanelShell/ProfileCard/ProfileFlavorTitle,
	$PanelShell/ProfileCard/ProfileFlavor,
	$PanelShell/ProfileCard/ProfileMetaTitle,
	$PanelShell/ProfileCard/ProfileMetaBody,
]
@onready var free_point_text: Label = $PanelShell/StatsCard/FreePointValue/FreePointText
@onready var stats_footer_label: Label = $PanelShell/StatsCard/StatsFooter
@onready var weapon_name_label: Label = $PanelShell/WeaponCard/WeaponName
@onready var weapon_attack_value_label: Label = $PanelShell/WeaponCard/WeaponAtkValue
@onready var weapon_defense_value_label: Label = $PanelShell/WeaponCard/WeaponDefValue
@onready var weapon_mastery_value_label: Label = $PanelShell/WeaponCard/WeaponMasteryValue
@onready var weapon_mastery_exp_fill: ColorRect = $PanelShell/WeaponCard/WeaponMasteryExpBar/Fill
@onready var weapon_mastery_exp_value_label: Label = $PanelShell/WeaponCard/WeaponMasteryExpBar/ValueLabel
@onready var class_swap_button: Button = $PanelShell/ClassCard/ClassSwapButton
@onready var class_value_label: Label = $PanelShell/ClassCard/ClassValue
@onready var spec_value_label: Label = $PanelShell/ClassCard/SpecValue
@onready var spec_exp_fill: ColorRect = $PanelShell/ClassCard/SpecExpBar/Fill
@onready var spec_exp_value_label: Label = $PanelShell/ClassCard/SpecExpBar/ValueLabel
@onready var class_hint_label: Label = $PanelShell/ClassCard/ClassHint

var _character_source: Node
var _fallback_profile: PlayerAttributeProfile
var _fallback_weapon: Node
var _stat_rows: Dictionary = {}
var _inventory_service: Node
var _account_service: Node


func _ready() -> void:
	_cache_stat_rows()
	_setup_fallback_state()
	_hide_deprecated_profile_sections()
	_configure_text_layout()
	_inventory_service = get_node_or_null("/root/InventoryService")
	_account_service = get_node_or_null("/root/AccountService")
	_connect_inventory_service_signals()
	_connect_account_service_signals()
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


func _hide_deprecated_profile_sections() -> void:
	for node in profile_deprecated_nodes:
		if node != null:
			node.visible = false


func _configure_text_layout() -> void:
	weapon_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_name_label.clip_text = true
	class_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_value_label.clip_text = true


func _connect_inventory_service_signals() -> void:
	if _inventory_service == null or not _inventory_service.has_signal("inventory_changed"):
		return

	var callback := Callable(self, "_on_inventory_service_changed")
	if not _inventory_service.is_connected("inventory_changed", callback):
		_inventory_service.connect("inventory_changed", callback)


func _on_inventory_service_changed() -> void:
	_refresh_all()


func _connect_account_service_signals() -> void:
	if _account_service == null:
		return

	var session_callback := Callable(self, "_on_account_service_changed")
	if _account_service.has_signal("session_changed") and not _account_service.is_connected("session_changed", session_callback):
		_account_service.connect("session_changed", session_callback)

	var profile_callback := Callable(self, "_on_account_service_profile_changed")
	if _account_service.has_signal("profile_changed") and not _account_service.is_connected("profile_changed", profile_callback):
		_account_service.connect("profile_changed", profile_callback)


func _on_account_service_changed(_username: String = "") -> void:
	_refresh_all()


func _on_account_service_profile_changed(_snapshot: Dictionary = {}) -> void:
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

	profile_name_label.text = _get_display_name()
	profile_job_label.text = "%s / Spec Lv.%d" % [profession_name, spec_level]


func _refresh_stats_card(snapshot: Dictionary) -> void:
	var total_stats: Dictionary = snapshot.get("total_stats", {})
	var equipment_bonus_stats: Dictionary = snapshot.get("equipment_bonus_stats", {})
	var free_points: int = int(snapshot.get("free_stat_points", 0))

	free_point_text.text = str(free_points)
	for attribute_id in _stat_rows.keys():
		var row_data: Dictionary = _stat_rows[attribute_id]
		var value_label: Label = row_data["value_label"]
		var plus_button: Button = row_data["plus_button"]
		var base_value: int = int(total_stats.get(String(attribute_id), 0))
		var equipment_bonus_value: int = int(equipment_bonus_stats.get(String(attribute_id), 0))
		value_label.text = _format_stat_display_value(base_value, equipment_bonus_value)
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
	_refresh_exp_bar(
		weapon_mastery_exp_fill,
		weapon_mastery_exp_value_label,
		_get_weapon_mastery_exp(),
		_get_weapon_mastery_exp_to_next_level()
	)


func _refresh_class_card(snapshot: Dictionary) -> void:
	class_value_label.text = String(snapshot.get("profession_name", "Martial Artist"))
	spec_value_label.text = "Lv.%d" % _get_specialization_level()
	_refresh_exp_bar(
		spec_exp_fill,
		spec_exp_value_label,
		_get_specialization_exp(),
		_get_specialization_exp_to_next_level()
	)
	class_hint_label.text = "Class swap is unavailable until more professions are implemented."
	class_swap_button.disabled = true


func _get_attribute_snapshot() -> Dictionary:
	if _character_source != null and _character_source.has_method("get_attribute_snapshot"):
		return _character_source.call("get_attribute_snapshot") as Dictionary
	if _account_service != null and _account_service.has_method("get_current_profile_snapshot"):
		var snapshot: Dictionary = _account_service.call("get_current_profile_snapshot") as Dictionary
		if not snapshot.is_empty():
			if not snapshot.has("equipment_bonus_stats"):
				snapshot["equipment_bonus_stats"] = _read_weapon_bonus_stats(_resolve_weapon_source())
			return snapshot

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
		"equipment_bonus_stats": _build_empty_equipment_bonus_stats(),
	}


func _build_profile_total_stats(profile: PlayerAttributeProfile) -> Dictionary:
	return {
		String(PlayerAttributeProfile.ATTRIBUTE_ATTACK): profile.get_total_stat(PlayerAttributeProfile.ATTRIBUTE_ATTACK),
		String(PlayerAttributeProfile.ATTRIBUTE_AGILITY): profile.get_total_stat(PlayerAttributeProfile.ATTRIBUTE_AGILITY),
		String(PlayerAttributeProfile.ATTRIBUTE_VITALITY): profile.get_total_stat(PlayerAttributeProfile.ATTRIBUTE_VITALITY),
		String(PlayerAttributeProfile.ATTRIBUTE_SPIRIT): profile.get_total_stat(PlayerAttributeProfile.ATTRIBUTE_SPIRIT),
	}


func _build_empty_equipment_bonus_stats() -> Dictionary:
	return {
		String(PlayerAttributeProfile.ATTRIBUTE_ATTACK): 0,
		String(PlayerAttributeProfile.ATTRIBUTE_AGILITY): 0,
		String(PlayerAttributeProfile.ATTRIBUTE_VITALITY): 0,
		String(PlayerAttributeProfile.ATTRIBUTE_SPIRIT): 0,
	}


func _get_display_name() -> String:
	if _character_source != null and _character_source.has_method("get_display_name"):
		return String(_character_source.call("get_display_name"))
	if _account_service != null and _account_service.has_method("get_current_display_name"):
		return String(_account_service.call("get_current_display_name"))
	return fallback_display_name


func _get_specialization_level() -> int:
	if _character_source != null and _character_source.has_method("get_specialization_level"):
		return int(_character_source.call("get_specialization_level"))
	if _account_service != null and _account_service.has_method("get_current_specialization_level"):
		return int(_account_service.call("get_current_specialization_level"))
	return fallback_specialization_level


func _get_specialization_exp() -> int:
	if _character_source != null and _character_source.has_method("get_specialization_exp"):
		return int(_character_source.call("get_specialization_exp"))
	if _account_service != null and _account_service.has_method("get_current_specialization_exp"):
		return int(_account_service.call("get_current_specialization_exp"))
	if _fallback_profile != null:
		return _fallback_profile.get_specialization_exp()
	return 0


func _get_specialization_exp_to_next_level() -> int:
	if _character_source != null and _character_source.has_method("get_specialization_exp_to_next_level"):
		return int(_character_source.call("get_specialization_exp_to_next_level"))
	if _account_service != null and _account_service.has_method("get_current_specialization_exp_to_next_level"):
		return int(_account_service.call("get_current_specialization_exp_to_next_level"))
	if _fallback_profile != null:
		return _fallback_profile.get_specialization_exp_to_next_level()
	return 100


func _get_weapon_mastery_level() -> int:
	if _character_source != null and _character_source.has_method("get_weapon_mastery_level"):
		return int(_character_source.call("get_weapon_mastery_level"))
	if _account_service != null and _account_service.has_method("get_current_weapon_mastery_level"):
		return int(_account_service.call("get_current_weapon_mastery_level", _resolve_weapon_mastery_track_id()))
	return fallback_weapon_mastery_level


func _get_weapon_mastery_exp() -> int:
	if _character_source != null and _character_source.has_method("get_weapon_mastery_exp"):
		return int(_character_source.call("get_weapon_mastery_exp"))
	if _account_service != null and _account_service.has_method("get_current_weapon_mastery_exp"):
		return int(_account_service.call("get_current_weapon_mastery_exp", _resolve_weapon_mastery_track_id()))
	if _fallback_profile != null:
		return _fallback_profile.get_weapon_mastery_exp(_resolve_weapon_mastery_track_id())
	return 0


func _get_weapon_mastery_exp_to_next_level() -> int:
	if _character_source != null and _character_source.has_method("get_weapon_mastery_exp_to_next_level"):
		return int(_character_source.call("get_weapon_mastery_exp_to_next_level"))
	if _account_service != null and _account_service.has_method("get_current_weapon_mastery_exp_to_next_level"):
		return int(_account_service.call("get_current_weapon_mastery_exp_to_next_level", _resolve_weapon_mastery_track_id()))
	if _fallback_profile != null:
		return _fallback_profile.get_weapon_mastery_exp_to_next_level(_resolve_weapon_mastery_track_id())
	return 80


func _resolve_weapon_mastery_track_id() -> String:
	var weapon: Variant = _resolve_weapon_source()
	if weapon == null:
		return PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK
	if weapon is Dictionary:
		return String((weapon as Dictionary).get("weapon_mastery_track_id", PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK))
	if weapon.has_method("get_weapon_mastery_track_id"):
		return String(weapon.call("get_weapon_mastery_track_id"))
	return PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK


func _resolve_weapon_source() -> Variant:
	if _character_source != null and _character_source.has_method("get_equipped_weapon_node"):
		var equipped_weapon: Variant = _character_source.call("get_equipped_weapon_node")
		if equipped_weapon is Node:
			return equipped_weapon
	if _inventory_service != null and _inventory_service.has_method("get_equipped_weapon"):
		var equipped_item: Dictionary = _inventory_service.call("get_equipped_weapon") as Dictionary
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
		var item: Dictionary = weapon as Dictionary
		if _inventory_service != null and _inventory_service.has_method("get_item_total_base_attack_power"):
			return float(_inventory_service.call("get_item_total_base_attack_power", item))
		return float(item.get("base_attack_power", 0.0))
	if weapon.has_method("get_base_attack_power"):
		return float(weapon.call("get_base_attack_power"))
	return float(weapon.get("base_attack_power"))


func _read_weapon_defense_ratio(weapon: Variant) -> float:
	if weapon == null:
		return 0.0
	if weapon is Dictionary:
		var item: Dictionary = weapon as Dictionary
		if _inventory_service != null and _inventory_service.has_method("get_item_total_base_defense_ratio"):
			return float(_inventory_service.call("get_item_total_base_defense_ratio", item))
		return float(item.get("base_defense_ratio", 0.0))
	if weapon.has_method("get_base_defense_ratio"):
		return float(weapon.call("get_base_defense_ratio"))
	return float(weapon.get("base_defense_ratio"))


func _read_weapon_bonus_stats(weapon: Variant) -> Dictionary:
	var bonus_stats := _build_empty_equipment_bonus_stats()
	if weapon == null:
		return bonus_stats

	if weapon is Dictionary:
		var item: Dictionary = weapon as Dictionary
		var reinforcement_bonus: Dictionary = item.get("reinforcement_bonus", {}) as Dictionary
		bonus_stats[String(PlayerAttributeProfile.ATTRIBUTE_ATTACK)] = int(reinforcement_bonus.get("attack", 0))
		bonus_stats[String(PlayerAttributeProfile.ATTRIBUTE_AGILITY)] = int(reinforcement_bonus.get("agility", 0))
		bonus_stats[String(PlayerAttributeProfile.ATTRIBUTE_VITALITY)] = int(reinforcement_bonus.get("vitality", 0))
		bonus_stats[String(PlayerAttributeProfile.ATTRIBUTE_SPIRIT)] = int(reinforcement_bonus.get("spirit", 0))
		return bonus_stats

	if weapon.has_method("get_attribute_bonus_value"):
		bonus_stats[String(PlayerAttributeProfile.ATTRIBUTE_ATTACK)] = int(weapon.call("get_attribute_bonus_value", PlayerAttributeProfile.ATTRIBUTE_ATTACK))
		bonus_stats[String(PlayerAttributeProfile.ATTRIBUTE_AGILITY)] = int(weapon.call("get_attribute_bonus_value", PlayerAttributeProfile.ATTRIBUTE_AGILITY))
		bonus_stats[String(PlayerAttributeProfile.ATTRIBUTE_VITALITY)] = int(weapon.call("get_attribute_bonus_value", PlayerAttributeProfile.ATTRIBUTE_VITALITY))
		bonus_stats[String(PlayerAttributeProfile.ATTRIBUTE_SPIRIT)] = int(weapon.call("get_attribute_bonus_value", PlayerAttributeProfile.ATTRIBUTE_SPIRIT))
	return bonus_stats


func _format_stat_display_value(base_value: int, equipment_bonus_value: int) -> String:
	if equipment_bonus_value > 0:
		return "%d +%d" % [base_value, equipment_bonus_value]
	return str(base_value)


func _refresh_exp_bar(fill_rect: ColorRect, value_label: Label, current_exp: int, exp_to_next_level: int) -> void:
	var safe_current_exp: int = max(0, current_exp)
	var safe_exp_to_next_level: int = max(1, exp_to_next_level)
	var ratio: float = clampf(float(safe_current_exp) / float(safe_exp_to_next_level), 0.0, 1.0)
	var bar_root := fill_rect.get_parent() as Control
	if bar_root != null:
		var full_width: float = bar_root.size.x
		if full_width <= 0.0:
			full_width = bar_root.offset_right - bar_root.offset_left
		fill_rect.offset_right = full_width * ratio
	value_label.text = "%d / %d EXP" % [safe_current_exp, safe_exp_to_next_level]


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

	if _account_service != null and _account_service.has_method("allocate_free_stat_points"):
		var did_allocate_account: bool = bool(_account_service.call("allocate_free_stat_points", attribute_id, 1))
		if did_allocate_account:
			_refresh_all()
		return

	if _fallback_profile != null and _fallback_profile.spend_free_stat_points(attribute_id, 1):
		_refresh_all()


func _exit_tree() -> void:
	_disconnect_character_source_signals()
	if is_instance_valid(_fallback_weapon):
		_fallback_weapon.free()
