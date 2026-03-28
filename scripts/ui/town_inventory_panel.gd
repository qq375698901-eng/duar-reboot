extends Control

const CONTAINER_BACKPACK := &"backpack"
const CONTAINER_WAREHOUSE := &"warehouse"
const ITEM_TYPE_WEAPON := "weapon"
const SLOT_SELECTION_COLOR := Color(0.92, 0.76, 0.32, 0.28)
const SLOT_OCCUPIED_COLOR := Color(0.26, 0.33, 0.4, 0.92)
const SLOT_EMPTY_COLOR := Color(0.09, 0.12, 0.16, 0.82)

@export var backpack_grid_path: NodePath
@export var warehouse_grid_path: NodePath
@export var slot_texture: Texture2D
@export var backpack_slot_count: int = 24
@export var warehouse_slot_count: int = 64

@onready var backpack_grid: GridContainer = get_node_or_null(backpack_grid_path)
@onready var warehouse_grid: GridContainer = get_node_or_null(warehouse_grid_path)
@onready var equip_slot_frame: Control = $PanelShell/EquipCard/EquipSlotFrame
@onready var equip_name_label: Label = $PanelShell/EquipCard/EquipName
@onready var equip_meta_label: Label = $PanelShell/EquipCard/EquipMeta
@onready var equip_hint_body_label: Label = $PanelShell/EquipCard/EquipHintBody
@onready var backpack_hint_label: Label = $PanelShell/BackpackCard/BackpackHint
@onready var warehouse_hint_label: Label = $PanelShell/WarehouseCard/WarehouseHint
@onready var prev_page_button: Button = $PanelShell/WarehouseCard/PrevPageButton
@onready var next_page_button: Button = $PanelShell/WarehouseCard/NextPageButton
@onready var page_label: Label = $PanelShell/WarehouseCard/PageLabel

var _inventory_runtime: Node
var _backpack_slot_widgets: Array = []
var _warehouse_slot_widgets: Array = []
var _equip_slot_button: Button
var _equip_slot_highlight: ColorRect
var _selected_container: StringName = &""
var _selected_index: int = -1
var _warehouse_page: int = 0


func _ready() -> void:
	_inventory_runtime = get_node_or_null("/root/InventoryRuntime")
	_build_slot_grid(backpack_grid, backpack_slot_count, Vector2(84.0, 84.0), CONTAINER_BACKPACK)
	_build_slot_grid(warehouse_grid, warehouse_slot_count, Vector2(44.0, 44.0), CONTAINER_WAREHOUSE)
	_setup_equip_slot_button()
	prev_page_button.pressed.connect(_on_prev_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)
	_connect_inventory_signals()
	refresh_display()


func refresh_display() -> void:
	_refresh_all()


func _connect_inventory_signals() -> void:
	if _inventory_runtime == null or not _inventory_runtime.has_signal("inventory_changed"):
		return

	var callback: Callable = Callable(self, "_on_inventory_changed")
	if not _inventory_runtime.is_connected("inventory_changed", callback):
		_inventory_runtime.connect("inventory_changed", callback)


func _on_inventory_changed() -> void:
	_refresh_all()


func _build_slot_grid(grid: GridContainer, count: int, slot_size: Vector2, container_id: StringName) -> void:
	if grid == null or slot_texture == null:
		return
	if grid.get_child_count() > 0:
		return

	var target_widgets: Array = _backpack_slot_widgets if container_id == CONTAINER_BACKPACK else _warehouse_slot_widgets
	for local_index in range(count):
		var slot_button: Button = Button.new()
		slot_button.flat = true
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.custom_minimum_size = slot_size
		slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot_button.pressed.connect(_on_slot_pressed.bind(container_id, local_index))

		var slot_texture_rect: TextureRect = TextureRect.new()
		slot_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_texture_rect.texture = slot_texture
		slot_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(slot_texture_rect)

		var fill: ColorRect = ColorRect.new()
		fill.offset_left = 6.0
		fill.offset_top = 6.0
		fill.offset_right = slot_size.x - 6.0
		fill.offset_bottom = slot_size.y - 6.0
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = SLOT_EMPTY_COLOR
		slot_button.add_child(fill)

		var label: Label = Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 11 if slot_size.x < 60.0 else 15)
		label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95, 1.0))
		slot_button.add_child(label)

		var highlight: ColorRect = ColorRect.new()
		highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.color = SLOT_SELECTION_COLOR
		highlight.visible = false
		slot_button.add_child(highlight)

		grid.add_child(slot_button)
		target_widgets.append({
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
	var equipped_item: Dictionary = _get_equipped_weapon()
	var backpack_slots: Array = _get_backpack_slots()
	var warehouse_slots: Array = _get_warehouse_slots()

	_refresh_equip_card(equipped_item)
	_refresh_slot_widgets(_backpack_slot_widgets, backpack_slots, CONTAINER_BACKPACK, 0)
	_refresh_slot_widgets(_warehouse_slot_widgets, warehouse_slots, CONTAINER_WAREHOUSE, _warehouse_page * warehouse_slot_count)
	_refresh_warehouse_paging(warehouse_slots.size())
	_refresh_hints()


func _refresh_equip_card(item: Dictionary) -> void:
	if item.is_empty():
		equip_name_label.text = "Unarmed"
		equip_meta_label.text = "ATK 0\nDEF 0%\nTier 0"
	else:
		equip_name_label.text = String(item.get("display_name", "Unknown"))
		equip_meta_label.text = "ATK %s\nDEF %d%%\nTier %d" % [
			str(snappedf(float(item.get("base_attack_power", 0.0)), 0.1)),
			int(round(float(item.get("base_defense_ratio", 0.0)) * 100.0)),
			int(item.get("weapon_tier", 1)),
		]

	_equip_slot_highlight.visible = _selected_container == CONTAINER_BACKPACK and _selected_index >= 0


func _refresh_slot_widgets(widgets: Array, slots: Array, container_id: StringName, start_index: int) -> void:
	for local_index in range(widgets.size()):
		var widget: Dictionary = widgets[local_index]
		var actual_index: int = start_index + local_index
		var item: Dictionary = {}
		if actual_index >= 0 and actual_index < slots.size():
			var value: Variant = slots[actual_index]
			if value is Dictionary:
				item = (value as Dictionary)

		var button: Button = widget["button"]
		var fill: ColorRect = widget["fill"]
		var label: Label = widget["label"]
		var highlight: ColorRect = widget["highlight"]
		var selected: bool = _selected_container == container_id and _selected_index == actual_index

		fill.color = SLOT_OCCUPIED_COLOR if not item.is_empty() else SLOT_EMPTY_COLOR
		label.text = _build_slot_label(item, actual_index, button.custom_minimum_size.x < 60.0)
		button.tooltip_text = _build_slot_tooltip(item, actual_index)
		highlight.visible = selected
		button.disabled = actual_index >= slots.size()


func _refresh_warehouse_paging(total_slots: int) -> void:
	var total_pages: int = max(1, int(ceil(float(total_slots) / float(max(1, warehouse_slot_count)))))
	_warehouse_page = clampi(_warehouse_page, 0, total_pages - 1)
	page_label.text = "%d / %d" % [_warehouse_page + 1, total_pages]
	prev_page_button.disabled = _warehouse_page <= 0
	next_page_button.disabled = _warehouse_page >= total_pages - 1


func _refresh_hints() -> void:
	if _selected_index >= 0:
		var container_label: String = "Backpack" if _selected_container == CONTAINER_BACKPACK else "Warehouse"
		backpack_hint_label.text = "Selected %s slot %d. Click another slot to move/swap." % [container_label, _selected_index + 1]
		warehouse_hint_label.text = "Click equip slot to wear a backpack weapon. Click the same slot again to cancel."
		equip_hint_body_label.text = "Selected item ready.\nMove between backpack and warehouse, or click equip slot to wear."
		return

	backpack_hint_label.text = "Click an item to select it, then click another slot to move or swap it."
	warehouse_hint_label.text = "Warehouse paging is ready for future expansion. Current storage uses one page."
	equip_hint_body_label.text = "Click the equipped weapon slot to unequip it into the backpack.\nSelect a backpack weapon first if you want to wear it."


func _on_slot_pressed(container_id: StringName, local_index: int) -> void:
	var actual_index: int = _resolve_actual_slot_index(container_id, local_index)
	var item: Dictionary = _get_item_from_container(container_id, actual_index)
	if _selected_index < 0:
		if item.is_empty():
			return
		_selected_container = container_id
		_selected_index = actual_index
		_refresh_all()
		return

	if _selected_container == container_id and _selected_index == actual_index:
		_clear_selection()
		_refresh_all()
		return

	if _inventory_runtime != null and _inventory_runtime.has_method("move_item"):
		_inventory_runtime.call("move_item", _selected_container, _selected_index, container_id, actual_index)
	_clear_selection()
	_refresh_all()


func _on_equip_slot_pressed() -> void:
	if _inventory_runtime == null:
		return

	var did_change: bool = false
	if _selected_container == CONTAINER_BACKPACK and _selected_index >= 0 and _inventory_runtime.has_method("equip_from_backpack"):
		did_change = bool(_inventory_runtime.call("equip_from_backpack", _selected_index))
	elif _selected_index < 0:
		if _inventory_runtime.has_method("unequip_to_backpack"):
			did_change = bool(_inventory_runtime.call("unequip_to_backpack"))

	if did_change:
		_clear_selection()
	_refresh_all()


func _on_prev_page_pressed() -> void:
	_warehouse_page = max(0, _warehouse_page - 1)
	_refresh_all()


func _on_next_page_pressed() -> void:
	_warehouse_page += 1
	_refresh_all()


func _resolve_actual_slot_index(container_id: StringName, local_index: int) -> int:
	if container_id == CONTAINER_WAREHOUSE:
		return _warehouse_page * warehouse_slot_count + local_index
	return local_index


func _get_item_from_container(container_id: StringName, slot_index: int) -> Dictionary:
	var slots: Array = _get_backpack_slots() if container_id == CONTAINER_BACKPACK else _get_warehouse_slots()
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	var value: Variant = slots[slot_index]
	if value is Dictionary:
		return (value as Dictionary)
	return {}


func _get_backpack_slots() -> Array:
	if _inventory_runtime != null and _inventory_runtime.has_method("get_backpack_slots"):
		return _inventory_runtime.call("get_backpack_slots") as Array
	return []


func _get_warehouse_slots() -> Array:
	if _inventory_runtime != null and _inventory_runtime.has_method("get_warehouse_slots"):
		return _inventory_runtime.call("get_warehouse_slots") as Array
	return []


func _get_equipped_weapon() -> Dictionary:
	if _inventory_runtime != null and _inventory_runtime.has_method("get_equipped_weapon"):
		return _inventory_runtime.call("get_equipped_weapon") as Dictionary
	return {}


func _build_slot_label(item: Dictionary, slot_index: int, compact: bool) -> String:
	if item.is_empty():
		return ""
	if compact:
		return "LS\n%d" % (slot_index + 1)
	return "Longsword\n#%d" % (slot_index + 1)


func _build_slot_tooltip(item: Dictionary, slot_index: int) -> String:
	if item.is_empty():
		return "Empty slot"
	return "%s\nATK %s  DEF %d%%\nSlot %d" % [
		String(item.get("display_name", "Unknown")),
		str(snappedf(float(item.get("base_attack_power", 0.0)), 0.1)),
		int(round(float(item.get("base_defense_ratio", 0.0)) * 100.0)),
		slot_index + 1,
	]


func _clear_selection() -> void:
	_selected_container = &""
	_selected_index = -1
