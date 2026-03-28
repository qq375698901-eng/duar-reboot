extends Control

const CONTAINER_BACKPACK := &"backpack"
const SLOT_SELECTION_COLOR := Color(0.92, 0.76, 0.32, 0.28)
const SLOT_OCCUPIED_COLOR := Color(0.26, 0.33, 0.4, 0.92)
const SLOT_EMPTY_COLOR := Color(0.09, 0.12, 0.16, 0.82)

@export var player_path: NodePath
@export var backpack_grid_path: NodePath
@export var slot_texture: Texture2D
@export var slot_count: int = 24
@export var slot_size: Vector2 = Vector2(30.0, 30.0)

@onready var backpack_grid: GridContainer = get_node_or_null(backpack_grid_path)
@onready var equip_slot_frame: Control = $PanelShell/EquipCard/EquipSlotFrame
@onready var equip_name_label: Label = $PanelShell/EquipCard/EquipName
@onready var equip_meta_label: Label = $PanelShell/EquipCard/EquipMeta
@onready var carry_hint_label: Label = $PanelShell/EquipCard/CarryHint
@onready var capacity_label: Label = $PanelShell/BackpackCard/CapacityLabel

var _inventory_runtime: Node
var _player: Node
var _slot_widgets: Array = []
var _equip_slot_button: Button
var _equip_slot_highlight: ColorRect
var _selected_backpack_index: int = -1


func _ready() -> void:
	visible = false
	_inventory_runtime = get_node_or_null("/root/InventoryRuntime")
	_player = get_node_or_null(player_path)
	_ensure_input_actions()
	_build_grid()
	_setup_equip_slot_button()
	_connect_inventory_signals()
	refresh_display()


func refresh_display() -> void:
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_battle_inventory"):
		get_viewport().set_input_as_handled()
		visible = not visible
		if visible:
			_refresh_all()


func _connect_inventory_signals() -> void:
	if _inventory_runtime == null or not _inventory_runtime.has_signal("inventory_changed"):
		return

	var callback: Callable = Callable(self, "_on_inventory_changed")
	if not _inventory_runtime.is_connected("inventory_changed", callback):
		_inventory_runtime.connect("inventory_changed", callback)


func _on_inventory_changed() -> void:
	_refresh_all()


func _build_grid() -> void:
	if backpack_grid == null or slot_texture == null:
		return
	if backpack_grid.get_child_count() > 0:
		return

	for index in range(slot_count):
		var slot_button: Button = Button.new()
		slot_button.flat = true
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.custom_minimum_size = slot_size
		slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot_button.pressed.connect(_on_backpack_slot_pressed.bind(index))

		var slot_texture_rect: TextureRect = TextureRect.new()
		slot_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_texture_rect.texture = slot_texture
		slot_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(slot_texture_rect)

		var fill: ColorRect = ColorRect.new()
		fill.offset_left = 4.0
		fill.offset_top = 4.0
		fill.offset_right = slot_size.x - 4.0
		fill.offset_bottom = slot_size.y - 4.0
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = SLOT_EMPTY_COLOR
		slot_button.add_child(fill)

		var label: Label = Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95, 1.0))
		slot_button.add_child(label)

		var highlight: ColorRect = ColorRect.new()
		highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.color = SLOT_SELECTION_COLOR
		highlight.visible = false
		slot_button.add_child(highlight)

		backpack_grid.add_child(slot_button)
		_slot_widgets.append({
			"button": slot_button,
			"fill": fill,
			"label": label,
			"highlight": highlight,
		})


func _setup_equip_slot_button() -> void:
	_equip_slot_button = Button.new()
	_equip_slot_button.flat = true
	_equip_slot_button.focus_mode = Control.FOCUS_NONE
	_equip_slot_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_equip_slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_equip_slot_button.pressed.connect(_on_equip_slot_pressed)
	equip_slot_frame.add_child(_equip_slot_button)

	_equip_slot_highlight = ColorRect.new()
	_equip_slot_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_equip_slot_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equip_slot_highlight.color = SLOT_SELECTION_COLOR
	_equip_slot_highlight.visible = false
	equip_slot_frame.add_child(_equip_slot_highlight)


func _refresh_all() -> void:
	var backpack_slots: Array = _get_backpack_slots()
	var equipped_item: Dictionary = _get_equipped_weapon()

	_refresh_equip_card(equipped_item)
	_refresh_backpack_slots(backpack_slots)
	capacity_label.text = "Items %d / %d" % [_count_used_slots(backpack_slots), backpack_slots.size()]


func _refresh_equip_card(item: Dictionary) -> void:
	if item.is_empty():
		equip_name_label.text = "Unarmed"
		equip_meta_label.text = "ATK 0    DEF 0%"
	else:
		equip_name_label.text = String(item.get("display_name", "Unknown"))
		equip_meta_label.text = "ATK %s    DEF %d%%" % [
			str(snappedf(float(item.get("base_attack_power", 0.0)), 0.1)),
			int(round(float(item.get("base_defense_ratio", 0.0)) * 100.0)),
		]

	_equip_slot_highlight.visible = _selected_backpack_index >= 0
	if _selected_backpack_index >= 0:
		carry_hint_label.text = "Selected backpack slot %d. Click the weapon slot to equip it." % (_selected_backpack_index + 1)
	else:
		carry_hint_label.text = "Click an equipped weapon slot to unequip. Click backpack items to select or reorder."


func _refresh_backpack_slots(backpack_slots: Array) -> void:
	for slot_index in range(_slot_widgets.size()):
		var widget: Dictionary = _slot_widgets[slot_index] as Dictionary
		var item: Dictionary = {}
		if slot_index < backpack_slots.size():
			var value: Variant = backpack_slots[slot_index]
			if value is Dictionary:
				item = value as Dictionary

		var button: Button = widget["button"]
		var fill: ColorRect = widget["fill"]
		var label: Label = widget["label"]
		var highlight: ColorRect = widget["highlight"]

		fill.color = SLOT_OCCUPIED_COLOR if not item.is_empty() else SLOT_EMPTY_COLOR
		label.text = "LS" if not item.is_empty() else ""
		button.tooltip_text = _build_slot_tooltip(item, slot_index)
		highlight.visible = _selected_backpack_index == slot_index


func _on_backpack_slot_pressed(slot_index: int) -> void:
	var item: Dictionary = _get_backpack_item(slot_index)
	if _selected_backpack_index < 0:
		if item.is_empty():
			return
		_selected_backpack_index = slot_index
		_refresh_all()
		return

	if _selected_backpack_index == slot_index:
		_selected_backpack_index = -1
		_refresh_all()
		return

	if _inventory_runtime != null and _inventory_runtime.has_method("move_item"):
		_inventory_runtime.call("move_item", CONTAINER_BACKPACK, _selected_backpack_index, CONTAINER_BACKPACK, slot_index)
	_selected_backpack_index = -1
	_refresh_all()


func _on_equip_slot_pressed() -> void:
	if _inventory_runtime == null:
		return

	var did_change: bool = false
	if _selected_backpack_index >= 0 and _inventory_runtime.has_method("equip_from_backpack"):
		did_change = bool(_inventory_runtime.call("equip_from_backpack", _selected_backpack_index))
	else:
		if _inventory_runtime.has_method("unequip_to_backpack"):
			did_change = bool(_inventory_runtime.call("unequip_to_backpack"))

	if did_change:
		_selected_backpack_index = -1
		_sync_player_weapon()
	_refresh_all()


func _get_backpack_slots() -> Array:
	if _inventory_runtime != null and _inventory_runtime.has_method("get_backpack_slots"):
		return _inventory_runtime.call("get_backpack_slots") as Array
	return []


func _get_backpack_item(slot_index: int) -> Dictionary:
	var backpack_slots: Array = _get_backpack_slots()
	if slot_index < 0 or slot_index >= backpack_slots.size():
		return {}
	var value: Variant = backpack_slots[slot_index]
	if value is Dictionary:
		return value as Dictionary
	return {}


func _get_equipped_weapon() -> Dictionary:
	if _inventory_runtime != null and _inventory_runtime.has_method("get_equipped_weapon"):
		return _inventory_runtime.call("get_equipped_weapon") as Dictionary
	return {}


func _count_used_slots(slots: Array) -> int:
	var used: int = 0
	for item in slots:
		if item != null:
			used += 1
	return used


func _build_slot_tooltip(item: Dictionary, slot_index: int) -> String:
	if item.is_empty():
		return "Empty slot"
	return "%s\nATK %s  DEF %d%%\nSlot %d" % [
		String(item.get("display_name", "Unknown")),
		str(snappedf(float(item.get("base_attack_power", 0.0)), 0.1)),
		int(round(float(item.get("base_defense_ratio", 0.0)) * 100.0)),
		slot_index + 1,
	]


func _sync_player_weapon() -> void:
	if _player == null:
		_player = get_node_or_null(player_path)
	if _player == null or not _player.has_method("equip_weapon_scene_path"):
		return

	var equipped_item: Dictionary = _get_equipped_weapon()
	var scene_path: String = String(equipped_item.get("scene_path", ""))
	_player.call("equip_weapon_scene_path", scene_path)


func _ensure_input_actions() -> void:
	_ensure_key_action("toggle_battle_inventory", [KEY_TAB])


func _ensure_key_action(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for keycode in keycodes:
		var already_bound: bool = false
		for event in existing_events:
			if event is InputEventKey and event.keycode == keycode:
				already_bound = true
				break
		if already_bound:
			continue

		var key_event: InputEventKey = InputEventKey.new()
		key_event.keycode = keycode as Key
		key_event.physical_keycode = keycode as Key
		InputMap.action_add_event(action_name, key_event)
