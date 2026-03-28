extends CanvasLayer

const PlayerAttributeProfile = preload("res://scripts/characters/player_attribute_profile.gd")

@export var player_path: NodePath

@onready var root_panel: PanelContainer = $RootPanel
@onready var free_points_value_label: Label = $RootPanel/Margin/VBox/TopRow/FreePointsValue
@onready var profession_value_label: Label = $RootPanel/Margin/VBox/TopRow/ProfessionValue
@onready var hp_value_label: Label = $RootPanel/Margin/VBox/DerivedGrid/HpValue
@onready var mp_value_label: Label = $RootPanel/Margin/VBox/DerivedGrid/MpValue
@onready var atk_mult_value_label: Label = $RootPanel/Margin/VBox/DerivedGrid/AttackMultiplierValue
@onready var speed_mult_value_label: Label = $RootPanel/Margin/VBox/DerivedGrid/SpeedMultiplierValue
@onready var accel_mult_value_label: Label = $RootPanel/Margin/VBox/DerivedGrid/AccelerationMultiplierValue
@onready var mp_regen_value_label: Label = $RootPanel/Margin/VBox/DerivedGrid/MpRegenValue

var _player: Node
var _stat_rows: Dictionary = {}


func _ready() -> void:
	_ensure_input_actions()
	_player = get_node_or_null(player_path)
	_cache_stat_rows()
	_connect_player_signals()
	root_panel.visible = false
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_attribute_panel"):
		get_viewport().set_input_as_handled()
		root_panel.visible = not root_panel.visible
		if root_panel.visible:
			_refresh_all()


func _cache_stat_rows() -> void:
	_register_stat_row(PlayerAttributeProfile.ATTRIBUTE_ATTACK, $RootPanel/Margin/VBox/Stats/AttackRow)
	_register_stat_row(PlayerAttributeProfile.ATTRIBUTE_AGILITY, $RootPanel/Margin/VBox/Stats/AgilityRow)
	_register_stat_row(PlayerAttributeProfile.ATTRIBUTE_VITALITY, $RootPanel/Margin/VBox/Stats/VitalityRow)
	_register_stat_row(PlayerAttributeProfile.ATTRIBUTE_SPIRIT, $RootPanel/Margin/VBox/Stats/SpiritRow)

	($RootPanel/Margin/VBox/Actions/AddPointButton as Button).pressed.connect(_on_add_point_pressed.bind(1))
	($RootPanel/Margin/VBox/Actions/AddFivePointsButton as Button).pressed.connect(_on_add_point_pressed.bind(5))
	($RootPanel/Margin/VBox/Actions/RestoreButton as Button).pressed.connect(_on_restore_resources_pressed)


func _register_stat_row(attribute_id: StringName, row: HBoxContainer) -> void:
	var plus_button: Button = row.get_node("PlusButton")
	var minus_button: Button = row.get_node("MinusButton")
	plus_button.pressed.connect(_on_plus_pressed.bind(attribute_id))
	minus_button.pressed.connect(_on_minus_pressed.bind(attribute_id))

	_stat_rows[attribute_id] = {
		"value_label": row.get_node("Value") as Label,
		"plus_button": plus_button,
		"minus_button": minus_button,
	}


func _connect_player_signals() -> void:
	if _player == null:
		return
	if _player.has_signal("attribute_profile_changed"):
		_player.connect("attribute_profile_changed", Callable(self, "_on_player_values_changed"))
	if _player.has_signal("resources_changed"):
		_player.connect("resources_changed", Callable(self, "_on_player_values_changed"))


func _on_player_values_changed(_a = null, _b = null, _c = null, _d = null) -> void:
	_refresh_all()


func _refresh_all() -> void:
	if _player == null:
		return

	var snapshot: Dictionary = _player.call("get_attribute_snapshot") as Dictionary
	var total_stats: Dictionary = snapshot.get("total_stats", {})
	var allocated_stats: Dictionary = snapshot.get("allocated_stats", {})
	var free_points: int = int(snapshot.get("free_stat_points", 0))

	free_points_value_label.text = str(free_points)
	profession_value_label.text = String(snapshot.get("profession_name", "Unknown"))

	for attribute_id in _stat_rows.keys():
		var row_data: Dictionary = _stat_rows[attribute_id]
		var total_value: int = int(total_stats.get(String(attribute_id), 0))
		var allocated_value: int = int(allocated_stats.get(String(attribute_id), 0))
		var value_label: Label = row_data["value_label"]
		var plus_button: Button = row_data["plus_button"]
		var minus_button: Button = row_data["minus_button"]

		value_label.text = "%d  (+%d)" % [total_value, allocated_value]
		plus_button.disabled = free_points <= 0
		minus_button.disabled = allocated_value <= 0

	hp_value_label.text = "%.0f / %.0f" % [
		float(snapshot.get("current_hp", 0.0)),
		float(snapshot.get("effective_max_hp", 0.0)),
	]
	mp_value_label.text = "%.0f / %.0f" % [
		float(snapshot.get("current_mp", 0.0)),
		float(snapshot.get("effective_max_mp", 0.0)),
	]

	var derived: Dictionary = snapshot.get("derived", {})
	atk_mult_value_label.text = "%.2fx" % float(derived.get("attack_damage_multiplier", 1.0))
	speed_mult_value_label.text = "%.2fx" % float(derived.get("movement_speed_multiplier", 1.0))
	accel_mult_value_label.text = "%.2fx" % float(derived.get("acceleration_multiplier", 1.0))
	mp_regen_value_label.text = "%.1f / s" % float(derived.get("mp_regen_per_sec", 0.0))


func _on_plus_pressed(attribute_id: StringName) -> void:
	if _player == null or not _player.has_method("allocate_free_stat_points"):
		return
	_player.call("allocate_free_stat_points", attribute_id, 1)
	_refresh_all()


func _on_minus_pressed(attribute_id: StringName) -> void:
	if _player == null or not _player.has_method("refund_free_stat_points"):
		return
	_player.call("refund_free_stat_points", attribute_id, 1)
	_refresh_all()


func _on_add_point_pressed(amount: int) -> void:
	if _player == null or not _player.has_method("add_free_stat_points"):
		return
	_player.call("add_free_stat_points", amount)
	_refresh_all()


func _on_restore_resources_pressed() -> void:
	if _player == null or not _player.has_method("restore_debug_resources"):
		return
	_player.call("restore_debug_resources")
	_refresh_all()


func _ensure_input_actions() -> void:
	_ensure_key_action("debug_toggle_attribute_panel", [KEY_U])


func _ensure_key_action(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for keycode in keycodes:
		var already_bound := false
		for event in existing_events:
			if event is InputEventKey and event.keycode == keycode:
				already_bound = true
				break
		if already_bound:
			continue

		var key_event := InputEventKey.new()
		key_event.keycode = keycode as Key
		key_event.physical_keycode = keycode as Key
		InputMap.action_add_event(action_name, key_event)
