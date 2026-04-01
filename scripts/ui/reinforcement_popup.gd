extends Control

signal reinforcement_applied(result: Dictionary)

const CONTAINER_BACKPACK := &"backpack"
const CONTAINER_WAREHOUSE := &"warehouse"
const CONTAINER_EQUIPPED := &"equipped"

@onready var overlay_dim: ColorRect = $OverlayDim
@onready var panel_shell: PanelContainer = $PanelShell
@onready var title_label: Label = $PanelShell/Margin/VBox/TitleLabel
@onready var stone_name_label: Label = $PanelShell/Margin/VBox/StoneNameLabel
@onready var effect_label: Label = $PanelShell/Margin/VBox/EffectLabel
@onready var target_select: OptionButton = $PanelShell/Margin/VBox/TargetSelect
@onready var status_label: Label = $PanelShell/Margin/VBox/StatusLabel
@onready var confirm_button: Button = $PanelShell/Margin/VBox/ButtonRow/ConfirmButton
@onready var cancel_button: Button = $PanelShell/Margin/VBox/ButtonRow/CancelButton

var _inventory_runtime: Node
var _source_container: StringName = &""
var _source_index: int = -1
var _available_targets: Array = []
var _allowed_target_containers: Array = [CONTAINER_EQUIPPED, CONTAINER_BACKPACK, CONTAINER_WAREHOUSE]


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_dim.gui_input.connect(_on_overlay_gui_input)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	target_select.item_selected.connect(_on_target_selected)


func open_popup(inventory_runtime: Node, source_container: StringName, source_index: int, allowed_target_containers: Array = []) -> void:
	_inventory_runtime = inventory_runtime
	_source_container = source_container
	_source_index = source_index
	_allowed_target_containers = allowed_target_containers.duplicate()
	if _allowed_target_containers.is_empty():
		_allowed_target_containers = [CONTAINER_EQUIPPED, CONTAINER_BACKPACK, CONTAINER_WAREHOUSE]

	var source_item: Dictionary = _get_source_item()
	if source_item.is_empty():
		hide()
		return

	title_label.text = "Reinforcement"
	stone_name_label.text = String(source_item.get("display_name", "Stone"))
	effect_label.text = _build_stone_effect_text(source_item)
	_rebuild_target_options()
	show()
	visible = true
	grab_focus()


func close_popup() -> void:
	hide()
	visible = false
	_available_targets.clear()
	target_select.clear()
	_status_set("Choose a weapon.")


func is_open() -> bool:
	return visible


func _rebuild_target_options() -> void:
	_available_targets.clear()
	target_select.clear()

	var equipped_item: Dictionary = _get_equipped_weapon()
	if _allowed_target_containers.has(CONTAINER_EQUIPPED) and not equipped_item.is_empty():
		_available_targets.append({
			"container": CONTAINER_EQUIPPED,
			"index": -1,
			"item": equipped_item,
			"label": "Equipped - %s (%s)" % [String(equipped_item.get("display_name", "Weapon")), _build_reinforcement_label(equipped_item)],
		})

	if _allowed_target_containers.has(CONTAINER_BACKPACK):
		var backpack_slots: Array = _get_backpack_slots()
		for slot_index in range(backpack_slots.size()):
			var item_value: Variant = backpack_slots[slot_index]
			if item_value is Dictionary:
				var backpack_item: Dictionary = item_value as Dictionary
				if _can_target_item(backpack_item):
					_available_targets.append({
						"container": CONTAINER_BACKPACK,
						"index": slot_index,
						"item": backpack_item,
						"label": "Backpack %d - %s (%s)" % [slot_index + 1, String(backpack_item.get("display_name", "Weapon")), _build_reinforcement_label(backpack_item)],
					})

	if _allowed_target_containers.has(CONTAINER_WAREHOUSE):
		var warehouse_slots: Array = _get_warehouse_slots()
		for slot_index in range(warehouse_slots.size()):
			var item_value: Variant = warehouse_slots[slot_index]
			if item_value is Dictionary:
				var warehouse_item: Dictionary = item_value as Dictionary
				if _can_target_item(warehouse_item):
					_available_targets.append({
						"container": CONTAINER_WAREHOUSE,
						"index": slot_index,
						"item": warehouse_item,
						"label": "Warehouse %d - %s (%s)" % [slot_index + 1, String(warehouse_item.get("display_name", "Weapon")), _build_reinforcement_label(warehouse_item)],
					})

	for entry_value in _available_targets:
		var entry: Dictionary = entry_value as Dictionary
		target_select.add_item(String(entry.get("label", "")))

	var has_targets: bool = not _available_targets.is_empty()
	target_select.disabled = not has_targets
	confirm_button.disabled = not has_targets
	if has_targets:
		target_select.select(0)
		_update_status_from_selection(0)
	else:
		_status_set("No weapon can be reinforced.")


func _on_target_selected(index: int) -> void:
	_update_status_from_selection(index)


func _update_status_from_selection(index: int) -> void:
	if index < 0 or index >= _available_targets.size():
		confirm_button.disabled = true
		_status_set("Choose a weapon.")
		return

	var entry: Dictionary = _available_targets[index] as Dictionary
	var item: Dictionary = entry.get("item", {}) as Dictionary
	confirm_button.disabled = not _can_target_item(item)
	if confirm_button.disabled:
		_status_set("This weapon is already at 4/4.")
		return
	_status_set("Ready: %s" % String(entry.get("label", "")))


func _on_confirm_pressed() -> void:
	if _inventory_runtime == null:
		return
	var selected_index: int = target_select.selected
	if selected_index < 0 or selected_index >= _available_targets.size():
		return

	var target_entry: Dictionary = _available_targets[selected_index] as Dictionary
	if not _inventory_runtime.has_method("apply_reinforcement_stone"):
		return

	var result: Dictionary = _inventory_runtime.call(
		"apply_reinforcement_stone",
		_source_container,
		_source_index,
		target_entry.get("container", CONTAINER_BACKPACK),
		int(target_entry.get("index", -1))
	) as Dictionary

	if bool(result.get("success", false)):
		reinforcement_applied.emit(result)
		close_popup()
		return

	_status_set("Reinforcement failed.")


func _on_cancel_pressed() -> void:
	close_popup()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close_popup()


func _get_source_item() -> Dictionary:
	if _inventory_runtime == null:
		return {}
	if not _inventory_runtime.has_method("get_backpack_slots") and not _inventory_runtime.has_method("get_warehouse_slots"):
		return {}
	if _source_container == CONTAINER_BACKPACK:
		var backpack_slots: Array = _get_backpack_slots()
		if _source_index >= 0 and _source_index < backpack_slots.size():
			var value: Variant = backpack_slots[_source_index]
			if value is Dictionary:
				return value as Dictionary
	elif _source_container == CONTAINER_WAREHOUSE:
		var warehouse_slots: Array = _get_warehouse_slots()
		if _source_index >= 0 and _source_index < warehouse_slots.size():
			var value: Variant = warehouse_slots[_source_index]
			if value is Dictionary:
				return value as Dictionary
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


func _can_target_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if _inventory_runtime != null and _inventory_runtime.has_method("can_item_be_reinforced"):
		return bool(_inventory_runtime.call("can_item_be_reinforced", item))
	return false


func _build_reinforcement_label(item: Dictionary) -> String:
	if _inventory_runtime != null and _inventory_runtime.has_method("get_item_reinforcement_label"):
		return String(_inventory_runtime.call("get_item_reinforcement_label", item))
	return "%d/4" % int(item.get("reinforcement_level", 0))


func _build_stone_effect_text(item: Dictionary) -> String:
	var description: String = String(item.get("effect_description", ""))
	if not description.is_empty():
		return description
	return "Use on a weapon."


func _status_set(text: String) -> void:
	status_label.text = text
