extends CanvasLayer

const TOGGLE_ACTION := &"debug_toggle_item_panel"

@onready var root_panel: PanelContainer = $Panel
@onready var list_box: VBoxContainer = $Panel/Margin/VBox/ListScroll/ListBox
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

var _inventory_service: Node


func _ready() -> void:
	layer = 90
	_inventory_service = get_node_or_null("/root/InventoryService")
	_ensure_input_actions()
	_connect_inventory_signals()
	_rebuild_list()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		get_viewport().set_input_as_handled()
		visible = not visible
		if visible:
			_rebuild_list()


func _connect_inventory_signals() -> void:
	if _inventory_service == null or not _inventory_service.has_signal("inventory_changed"):
		return
	var callback := Callable(self, "_on_inventory_changed")
	if not _inventory_service.is_connected("inventory_changed", callback):
		_inventory_service.connect("inventory_changed", callback)


func _on_inventory_changed() -> void:
	if visible:
		_rebuild_list()


func _rebuild_list() -> void:
	for child in list_box.get_children():
		child.queue_free()

	if _inventory_service == null or not _inventory_service.has_method("get_debug_item_catalog"):
		status_label.text = "Inventory service unavailable."
		return

	var catalog: Array = _inventory_service.call("get_debug_item_catalog") as Array
	for entry_value in catalog:
		if not (entry_value is Dictionary):
			continue
		var item: Dictionary = entry_value as Dictionary
		list_box.add_child(_build_item_row(item))

	status_label.text = "Press I to close. Click Add to put one item into backpack."


func _build_item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 54.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36.0, 36.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _resolve_item_icon(item)
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = String(item.get("display_name", "Item"))
	name_label.add_theme_font_size_override("font_size", 15)
	text_box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.text = _build_item_description(item)
	desc_label.add_theme_font_size_override("font_size", 11)
	text_box.add_child(desc_label)
	row.add_child(text_box)

	var add_button := Button.new()
	add_button.text = "Add"
	add_button.custom_minimum_size = Vector2(68.0, 30.0)
	add_button.pressed.connect(_on_add_pressed.bind(String(item.get("definition_id", "")), String(item.get("display_name", "Item"))))
	row.add_child(add_button)

	return row


func _on_add_pressed(definition_id: String, display_name: String) -> void:
	if _inventory_service == null or not _inventory_service.has_method("add_item_to_backpack_by_definition"):
		status_label.text = "Add failed."
		return

	var success: bool = bool(_inventory_service.call("add_item_to_backpack_by_definition", definition_id))
	if success:
		status_label.text = "%s added to backpack." % display_name
	else:
		status_label.text = "Backpack full or invalid item."


func _resolve_item_icon(item: Dictionary) -> Texture2D:
	var icon_path: String = String(item.get("icon_path", ""))
	if icon_path.is_empty():
		return null
	var resource: Resource = load(icon_path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _build_item_description(item: Dictionary) -> String:
	var item_type: String = String(item.get("item_type", ""))
	if item_type == "weapon":
		var inventory_service: Node = get_node_or_null("/root/InventoryService")
		var atk: float = float(item.get("base_attack_power", 0.0))
		var defense_ratio: float = float(item.get("base_defense_ratio", 0.0))
		if inventory_service != null and inventory_service.has_method("get_item_total_base_attack_power"):
			atk = float(inventory_service.call("get_item_total_base_attack_power", item))
		if inventory_service != null and inventory_service.has_method("get_item_total_base_defense_ratio"):
			defense_ratio = float(inventory_service.call("get_item_total_base_defense_ratio", item))
		return "Weapon | ATK %s | DEF %d%%" % [
			str(snappedf(atk, 0.1)),
			int(round(defense_ratio * 100.0)),
		]
	if item_type == "potion":
		return "Potion | Heal %d HP | Stack %d" % [
			int(round(float(item.get("restore_hp_value", 0.0)))),
			max(1, int(item.get("max_stack", 1))),
		]

	return String(item.get("effect_description", "Item"))


func _ensure_input_actions() -> void:
	_ensure_key_action(TOGGLE_ACTION, [KEY_I])


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

		var key_event := InputEventKey.new()
		key_event.keycode = keycode as Key
		key_event.physical_keycode = keycode as Key
		InputMap.action_add_event(action_name, key_event)
