extends Control

const CONTAINER_BACKPACK := &"backpack"
const CONTAINER_EQUIPPED := &"equipped"
const CONTAINER_EQUIPPED_POTION := &"equipped_potion"
const SLOT_SELECTION_COLOR := Color(0.92, 0.76, 0.32, 0.28)
const SLOT_OCCUPIED_COLOR := Color(0.26, 0.33, 0.4, 0.92)
const SLOT_EMPTY_COLOR := Color(0.09, 0.12, 0.16, 0.82)
const EQUIPMENT_TOOLTIP_SCENE := preload("res://scenes/ui/equipment_hover_tooltip.tscn")
const REINFORCEMENT_POPUP_SCENE := preload("res://scenes/ui/reinforcement_popup.tscn")
const CRAFTING_POPUP_SCENE := preload("res://scenes/ui/crafting_popup.tscn")
const ITEM_TYPE_REINFORCEMENT_STONE := "reinforcement_stone"
const ITEM_TYPE_WEAPON := "weapon"
const ITEM_TYPE_POTION := "potion"
const ITEM_TYPE_CRAFTING_MATERIAL := "crafting_material"
const DOUBLE_CLICK_THRESHOLD_SEC := 0.28

@export var player_path: NodePath
@export var backpack_grid_path: NodePath
@export var slot_texture: Texture2D
@export var slot_count: int = 24
@export var slot_size: Vector2 = Vector2(30.0, 30.0)

@onready var backpack_grid: GridContainer = get_node_or_null(backpack_grid_path)
@onready var equip_slot_frame: TextureRect = $PanelShell/EquipCard/EquipSlotFrame
@onready var equip_slot_label: Label = $PanelShell/EquipCard/EquipSlotFrame/EquipSlotLabel
@onready var equip_name_label: Label = $PanelShell/EquipCard/EquipName
@onready var equip_meta_label: Label = $PanelShell/EquipCard/EquipMeta
@onready var carry_hint_label: Label = $PanelShell/EquipCard/CarryHint
@onready var capacity_label: Label = $PanelShell/BackpackCard/CapacityLabel

var _inventory_service: Node
var _player: Node
var _slot_widgets: Array = []
var _equip_slot_button: Button
var _equip_slot_highlight: ColorRect
var _equip_slot_icon: TextureRect
var _potion_slot_button: Button
var _potion_slot_highlight: ColorRect
var _potion_slot_icon: TextureRect
var _potion_slot_label: Label
var _potion_meta_label: Label
var _selected_backpack_index: int = -1
var _tooltip_layer: CanvasLayer
var _reinforcement_popup: Control
var _crafting_popup: Control
var _last_clicked_backpack_index: int = -1
var _last_clicked_time_sec: float = -1.0


func _ready() -> void:
	visible = false
	_inventory_service = get_node_or_null("/root/InventoryService")
	_player = get_node_or_null(player_path)
	_ensure_input_actions()
	_build_grid()
	_setup_equip_slot_button()
	_setup_potion_slot_button()
	_setup_tooltip_layer()
	_setup_reinforcement_popup()
	_setup_crafting_popup()
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
		else:
			_hide_item_tooltip()


func _connect_inventory_signals() -> void:
	if _inventory_service == null or not _inventory_service.has_signal("inventory_changed"):
		return

	var callback: Callable = Callable(self, "_on_inventory_changed")
	if not _inventory_service.is_connected("inventory_changed", callback):
		_inventory_service.connect("inventory_changed", callback)


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
		slot_button.mouse_entered.connect(_on_backpack_slot_mouse_entered.bind(index))
		slot_button.mouse_exited.connect(_on_backpack_slot_mouse_exited.bind(index))

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

		var icon: TextureRect = TextureRect.new()
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = slot_size.x - 4.0
		icon.offset_bottom = slot_size.y - 4.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(icon)

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
			"icon": icon,
			"highlight": highlight,
		})


func _setup_equip_slot_button() -> void:
	_equip_slot_button = Button.new()
	_equip_slot_button.flat = true
	_equip_slot_button.focus_mode = Control.FOCUS_NONE
	_equip_slot_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_equip_slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_equip_slot_button.pressed.connect(_on_equip_slot_pressed)
	_equip_slot_button.mouse_entered.connect(_on_equip_slot_mouse_entered)
	_equip_slot_button.mouse_exited.connect(_on_equip_slot_mouse_exited)
	equip_slot_frame.add_child(_equip_slot_button)

	_equip_slot_icon = TextureRect.new()
	_equip_slot_icon.offset_left = 12.0
	_equip_slot_icon.offset_top = 12.0
	_equip_slot_icon.offset_right = 72.0
	_equip_slot_icon.offset_bottom = 72.0
	_equip_slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_equip_slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_equip_slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_slot_frame.add_child(_equip_slot_icon)

	_equip_slot_highlight = ColorRect.new()
	_equip_slot_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_equip_slot_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equip_slot_highlight.color = SLOT_SELECTION_COLOR
	_equip_slot_highlight.visible = false
	equip_slot_frame.add_child(_equip_slot_highlight)


func _setup_potion_slot_button() -> void:
	var parent_card: Control = equip_slot_frame.get_parent()
	if parent_card == null:
		return

	var frame := TextureRect.new()
	frame.name = "PotionSlotFrame"
	frame.offset_left = 274.0
	frame.offset_top = 18.0
	frame.offset_right = 344.0
	frame.offset_bottom = 88.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture = equip_slot_frame.texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parent_card.add_child(frame)

	_potion_meta_label = Label.new()
	_potion_meta_label.name = "PotionSlotMeta"
	_potion_meta_label.offset_left = 258.0
	_potion_meta_label.offset_top = 92.0
	_potion_meta_label.offset_right = 356.0
	_potion_meta_label.offset_bottom = 120.0
	_potion_meta_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.74, 1.0))
	_potion_meta_label.add_theme_font_size_override("font_size", 12)
	_potion_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_potion_meta_label.text = "Potion"
	parent_card.add_child(_potion_meta_label)

	_potion_slot_button = Button.new()
	_potion_slot_button.flat = true
	_potion_slot_button.focus_mode = Control.FOCUS_NONE
	_potion_slot_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_potion_slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_potion_slot_button.pressed.connect(_on_potion_slot_pressed)
	_potion_slot_button.mouse_entered.connect(_on_potion_slot_mouse_entered)
	_potion_slot_button.mouse_exited.connect(_on_potion_slot_mouse_exited)
	frame.add_child(_potion_slot_button)

	_potion_slot_icon = TextureRect.new()
	_potion_slot_icon.offset_left = 8.0
	_potion_slot_icon.offset_top = 8.0
	_potion_slot_icon.offset_right = 62.0
	_potion_slot_icon.offset_bottom = 62.0
	_potion_slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_potion_slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_potion_slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_potion_slot_icon)

	_potion_slot_label = Label.new()
	_potion_slot_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_potion_slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_potion_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_potion_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_potion_slot_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95, 1.0))
	_potion_slot_label.add_theme_font_size_override("font_size", 11)
	frame.add_child(_potion_slot_label)

	_potion_slot_highlight = ColorRect.new()
	_potion_slot_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_potion_slot_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_potion_slot_highlight.color = SLOT_SELECTION_COLOR
	_potion_slot_highlight.visible = false
	frame.add_child(_potion_slot_highlight)


func _setup_tooltip_layer() -> void:
	if _tooltip_layer != null:
		return
	_tooltip_layer = EQUIPMENT_TOOLTIP_SCENE.instantiate() as CanvasLayer
	if _tooltip_layer == null:
		return
	_tooltip_layer.name = "EquipmentHoverTooltip"
	add_child(_tooltip_layer)


func _refresh_all() -> void:
	var backpack_slots: Array = _get_backpack_slots()
	var equipped_item: Dictionary = _get_equipped_weapon()
	var equipped_potion: Dictionary = _get_equipped_potion()

	_refresh_equip_card(equipped_item, equipped_potion)
	_refresh_backpack_slots(backpack_slots)
	capacity_label.text = "Items %d / %d" % [_count_used_slots(backpack_slots), backpack_slots.size()]


func _refresh_equip_card(item: Dictionary, potion_item: Dictionary) -> void:
	if item.is_empty():
		equip_name_label.text = "Unarmed"
		equip_meta_label.text = "ATK 0    DEF 0%"
		_equip_slot_icon.texture = null
		equip_slot_label.visible = true
	else:
		equip_name_label.text = String(item.get("display_name", _zh("5pyq55+l6KOF5aSH")))
		equip_meta_label.text = "ATK %s    DEF %d%%    R %s" % [
			str(snappedf(_get_total_base_attack_power(item), 0.1)),
			int(round(_get_total_base_defense_ratio(item) * 100.0)),
			_get_reinforcement_label(item),
		]
		_equip_slot_icon.texture = _resolve_item_icon(item)
		equip_slot_label.visible = false

	_equip_slot_highlight.visible = _is_selected_item_type(ITEM_TYPE_WEAPON)
	if _selected_backpack_index >= 0:
		carry_hint_label.text = "Selected backpack slot %d. Use the matching equip slot." % (_selected_backpack_index + 1)
	else:
		carry_hint_label.text = "Click the weapon or potion slot to unequip. Click backpack items to select or reorder."

	if _potion_slot_icon != null and _potion_slot_label != null and _potion_meta_label != null:
		if potion_item.is_empty():
			_potion_slot_icon.texture = null
			_potion_slot_icon.visible = false
			_potion_slot_label.visible = true
			_potion_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_potion_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_potion_slot_label.text = "P"
			_potion_meta_label.text = "Potion"
		else:
			_potion_slot_icon.texture = _resolve_item_icon(potion_item)
			_potion_slot_icon.visible = _potion_slot_icon.texture != null
			_potion_slot_label.visible = true
			_potion_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_potion_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_potion_slot_label.text = _get_stack_badge_text(potion_item)
			_potion_meta_label.text = "HP +%d  x%d/%d" % [
				int(round(float(potion_item.get("restore_hp_value", 0.0)))),
				_get_item_stack_count(potion_item),
				_get_item_max_stack(potion_item),
			]
		_potion_slot_highlight.visible = _is_selected_item_type(ITEM_TYPE_POTION)


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
		var icon: TextureRect = widget["icon"]
		var highlight: ColorRect = widget["highlight"]

		fill.color = SLOT_OCCUPIED_COLOR if not item.is_empty() else SLOT_EMPTY_COLOR
		icon.texture = _resolve_item_icon(item)
		icon.visible = not item.is_empty() and icon.texture != null
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if icon.visible:
			label.text = _get_stack_badge_text(item)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		elif not item.is_empty():
			if String(item.get("item_type", "")) == ITEM_TYPE_REINFORCEMENT_STONE:
				label.text = "ST"
			elif String(item.get("item_type", "")) == ITEM_TYPE_CRAFTING_MATERIAL:
				label.text = "MT"
			elif String(item.get("item_type", "")) == ITEM_TYPE_POTION:
				label.text = "P"
			else:
				label.text = "LS"
		else:
			label.text = ""
		button.tooltip_text = ""
		highlight.visible = _selected_backpack_index == slot_index


func _on_backpack_slot_pressed(slot_index: int) -> void:
	if _is_player_equipment_operation_locked():
		return
	var item: Dictionary = _get_backpack_item(slot_index)
	var item_type: String = String(item.get("item_type", ""))
	var is_double_click: bool = _is_backpack_double_click(slot_index)
	if item_type == ITEM_TYPE_REINFORCEMENT_STONE and _try_open_reinforcement_popup(slot_index, item, is_double_click):
		return
	if item_type == ITEM_TYPE_CRAFTING_MATERIAL and _try_open_crafting_popup(slot_index, item, is_double_click):
		return
	_update_last_backpack_click(slot_index)
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

	if _inventory_service != null and _inventory_service.has_method("move_item"):
		_inventory_service.call("move_item", CONTAINER_BACKPACK, _selected_backpack_index, CONTAINER_BACKPACK, slot_index)
	_selected_backpack_index = -1
	_refresh_all()


func _on_equip_slot_pressed() -> void:
	if _is_player_equipment_operation_locked():
		return
	if _inventory_service == null:
		return

	var did_change: bool = false
	if _selected_backpack_index >= 0 and _is_selected_item_type(ITEM_TYPE_WEAPON) and _inventory_service.has_method("equip_from_backpack"):
		did_change = bool(_inventory_service.call("equip_from_backpack", _selected_backpack_index))
	else:
		if _inventory_service.has_method("unequip_to_backpack"):
			did_change = bool(_inventory_service.call("unequip_to_backpack"))

	if did_change:
		_selected_backpack_index = -1
		_sync_player_weapon()
	_refresh_all()


func _on_potion_slot_pressed() -> void:
	if _is_player_equipment_operation_locked():
		return
	if _inventory_service == null:
		return

	var did_change: bool = false
	if _selected_backpack_index >= 0 and _is_selected_item_type(ITEM_TYPE_POTION) and _inventory_service.has_method("equip_potion_from_backpack"):
		did_change = bool(_inventory_service.call("equip_potion_from_backpack", _selected_backpack_index))
	elif _selected_backpack_index < 0 and _inventory_service.has_method("unequip_potion_to_backpack"):
		did_change = bool(_inventory_service.call("unequip_potion_to_backpack"))

	if did_change:
		_selected_backpack_index = -1
	_refresh_all()


func _on_backpack_slot_mouse_entered(slot_index: int) -> void:
	_show_item_tooltip(_get_backpack_item(slot_index))


func _on_backpack_slot_mouse_exited(_slot_index: int) -> void:
	_hide_item_tooltip()


func _on_equip_slot_mouse_entered() -> void:
	_show_item_tooltip(_get_equipped_weapon())


func _on_equip_slot_mouse_exited() -> void:
	_hide_item_tooltip()


func _on_potion_slot_mouse_entered() -> void:
	_show_item_tooltip(_get_equipped_potion())


func _on_potion_slot_mouse_exited() -> void:
	_hide_item_tooltip()


func _get_backpack_slots() -> Array:
	if _inventory_service != null and _inventory_service.has_method("get_backpack_slots"):
		return _inventory_service.call("get_backpack_slots") as Array
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
	if _inventory_service != null and _inventory_service.has_method("get_equipped_weapon"):
		return _inventory_service.call("get_equipped_weapon") as Dictionary
	return {}


func _get_equipped_potion() -> Dictionary:
	if _inventory_service != null and _inventory_service.has_method("get_equipped_potion"):
		return _inventory_service.call("get_equipped_potion") as Dictionary
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
	if String(item.get("item_type", "")) == ITEM_TYPE_REINFORCEMENT_STONE:
		return "%s\n%s\nSlot %d" % [
			String(item.get("display_name", _zh("5by65YyW55+z"))),
			String(item.get("effect_description", _zh("55So5LqO5by65YyW6KOF5aSH55qE5p2Q5paZ44CC"))),
			slot_index + 1,
		]
	if String(item.get("item_type", "")) == ITEM_TYPE_CRAFTING_MATERIAL:
		return "%s\n%s\nSlot %d" % [
			String(item.get("display_name", _zh("5Yi25L2c5p2Q5paZ"))),
			String(item.get("effect_description", _zh("55So5LqO5Yi25L2c6KOF5aSH55qE5p2Q5paZ44CC"))),
			slot_index + 1,
		]
	return "%s\nATK %s  DEF %d%%\nSlot %d" % [
		String(item.get("display_name", _zh("5pyq55+l6KOF5aSH"))),
		str(snappedf(_get_total_base_attack_power(item), 0.1)),
		int(round(_get_total_base_defense_ratio(item) * 100.0)),
		slot_index + 1,
	]


func _sync_player_weapon() -> void:
	if _player == null:
		_player = get_node_or_null(player_path)
	if _player == null or not _player.has_method("equip_weapon_scene_path"):
		return

	var equipped_item: Dictionary = _get_equipped_weapon()
	var scene_path: String = String(equipped_item.get("scene_path", ""))
	_player.call("equip_weapon_scene_path", scene_path, equipped_item)


func _is_player_equipment_operation_locked() -> bool:
	if _player == null:
		_player = get_node_or_null(player_path)
	if _player == null or not _player.has_method("is_potion_use_active"):
		return false
	return bool(_player.call("is_potion_use_active"))


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


func _show_item_tooltip(item: Dictionary) -> void:
	if _tooltip_layer == null or not _tooltip_layer.has_method("show_item"):
		return
	if item.is_empty():
		_hide_item_tooltip()
		return
	_tooltip_layer.call("show_item", item)


func _hide_item_tooltip() -> void:
	if _tooltip_layer == null or not _tooltip_layer.has_method("hide_tooltip"):
		return
	_tooltip_layer.call("hide_tooltip")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_hide_item_tooltip()
		if _reinforcement_popup != null and _reinforcement_popup.has_method("close_popup"):
			_reinforcement_popup.call("close_popup")
		if _crafting_popup != null and _crafting_popup.has_method("close_popup"):
			_crafting_popup.call("close_popup")


func _resolve_item_icon(item: Dictionary) -> Texture2D:
	if item.is_empty():
		return null
	var icon_path: String = String(item.get("icon_path", ""))
	if icon_path.is_empty():
		return null
	var resource: Resource = load(icon_path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _get_total_base_attack_power(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	if _inventory_service != null and _inventory_service.has_method("get_item_total_base_attack_power"):
		return float(_inventory_service.call("get_item_total_base_attack_power", item))
	return float(item.get("base_attack_power", 0.0))


func _get_total_base_defense_ratio(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	if _inventory_service != null and _inventory_service.has_method("get_item_total_base_defense_ratio"):
		return float(_inventory_service.call("get_item_total_base_defense_ratio", item))
	return float(item.get("base_defense_ratio", 0.0))


func _get_reinforcement_label(item: Dictionary) -> String:
	if item.is_empty():
		return "0/4"
	if _inventory_service != null and _inventory_service.has_method("get_item_reinforcement_label"):
		return String(_inventory_service.call("get_item_reinforcement_label", item))
	return "%d/4" % int(item.get("reinforcement_level", 0))


func _get_item_stack_count(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	return max(1, int(item.get("stack_count", 1)))


func _get_item_max_stack(item: Dictionary) -> int:
	if item.is_empty():
		return 1
	return max(1, int(item.get("max_stack", 1)))


func _get_stack_badge_text(item: Dictionary) -> String:
	if item.is_empty() or _get_item_max_stack(item) <= 1:
		return ""
	return "x%d" % _get_item_stack_count(item)


func _is_selected_item_type(item_type: String) -> bool:
	if _selected_backpack_index < 0:
		return false
	return String(_get_backpack_item(_selected_backpack_index).get("item_type", "")) == item_type


func _setup_reinforcement_popup() -> void:
	if _reinforcement_popup != null:
		return
	_reinforcement_popup = REINFORCEMENT_POPUP_SCENE.instantiate() as Control
	if _reinforcement_popup == null:
		return
	_reinforcement_popup.name = "ReinforcementPopup"
	add_child(_reinforcement_popup)


func _setup_crafting_popup() -> void:
	if _crafting_popup != null:
		return
	_crafting_popup = CRAFTING_POPUP_SCENE.instantiate() as Control
	if _crafting_popup == null:
		return
	_crafting_popup.name = "CraftingPopup"
	add_child(_crafting_popup)


func _try_open_reinforcement_popup(slot_index: int, item: Dictionary, is_double_click: bool) -> bool:
	if item.is_empty():
		return false
	if String(item.get("item_type", "")) != ITEM_TYPE_REINFORCEMENT_STONE:
		return false
	if not is_double_click:
		return false

	if _reinforcement_popup == null or not _reinforcement_popup.has_method("open_popup"):
		return false

	_selected_backpack_index = -1
	_clear_last_backpack_click()
	_hide_item_tooltip()
	_reinforcement_popup.call("open_popup", _inventory_service, CONTAINER_BACKPACK, slot_index, [CONTAINER_EQUIPPED, CONTAINER_BACKPACK])
	_refresh_all()
	return true


func _try_open_crafting_popup(slot_index: int, item: Dictionary, is_double_click: bool) -> bool:
	if item.is_empty():
		return false
	if String(item.get("item_type", "")) != ITEM_TYPE_CRAFTING_MATERIAL:
		return false
	if not is_double_click:
		return false
	if _crafting_popup == null or not _crafting_popup.has_method("open_popup"):
		return false

	_selected_backpack_index = -1
	_clear_last_backpack_click()
	_hide_item_tooltip()
	_crafting_popup.call("open_popup", _inventory_service, CONTAINER_BACKPACK, slot_index)
	_refresh_all()
	return true


func _is_backpack_double_click(slot_index: int) -> bool:
	var now_sec: float = _get_time_seconds()
	return _last_clicked_backpack_index == slot_index \
		and _last_clicked_time_sec >= 0.0 \
		and (now_sec - _last_clicked_time_sec) <= DOUBLE_CLICK_THRESHOLD_SEC


func _update_last_backpack_click(slot_index: int) -> void:
	_last_clicked_backpack_index = slot_index
	_last_clicked_time_sec = _get_time_seconds()


func _clear_last_backpack_click() -> void:
	_last_clicked_backpack_index = -1
	_last_clicked_time_sec = -1.0


func _get_time_seconds() -> float:
	return float(Time.get_ticks_msec()) * 0.001


func _zh(encoded: String) -> String:
	return Marshalls.base64_to_utf8(encoded)
