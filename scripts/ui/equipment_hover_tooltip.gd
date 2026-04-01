extends CanvasLayer

const FOLLOW_OFFSET := Vector2(18.0, 18.0)

@onready var panel: PanelContainer = $Panel
@onready var icon_rect: TextureRect = $Panel/Margin/VBox/Header/IconFrame/Icon
@onready var name_label: Label = $Panel/Margin/VBox/Header/TextColumn/NameLabel
@onready var type_label: Label = $Panel/Margin/VBox/Header/TextColumn/TypeLabel
@onready var body_label: Label = $Panel/Margin/VBox/BodyLabel


func _ready() -> void:
	hide_tooltip()


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_position_to_mouse()


func show_item(item: Dictionary) -> void:
	if item.is_empty():
		hide_tooltip()
		return

	name_label.text = String(item.get("display_name", "Unknown"))
	type_label.text = _build_type_label(item)
	body_label.text = _build_body_text(item)
	icon_rect.texture = _load_item_icon(item)
	visible = true
	panel.visible = true
	set_process(true)
	_update_position_to_mouse()


func hide_tooltip() -> void:
	visible = false
	panel.visible = false
	set_process(false)


func _build_type_label(item: Dictionary) -> String:
	var item_type: String = String(item.get("item_type", ""))
	if item_type == "weapon":
		return _zh("6KOF5aSHIC8g5q2m5Zmo")
	if item_type == "potion":
		return _zh("5raI6ICX5ZOBIC8g6I2v5rC0")
	if item_type == "reinforcement_stone":
		return _zh("54mp5ZOBIC8g5by65YyW55+z")
	if item_type == "crafting_material":
		return _zh("54mp5ZOBIC8g5Yi25L2c5p2Q5paZ")
	return _zh("54mp5ZOB")


func _build_body_text(item: Dictionary) -> String:
	var item_type: String = String(item.get("item_type", ""))
	if item_type == "potion":
		return _build_potion_text(item)
	if item_type == "reinforcement_stone":
		return _build_reinforcement_stone_text(item)
	if item_type == "crafting_material":
		return _build_crafting_material_text(item)

	var base_attack_power: float = _get_total_base_attack_power(item)
	var defense_ratio: float = _get_total_base_defense_ratio(item)
	var lines := [
		"%s  %s" % [_zh("5by65YyW"), _get_reinforcement_label(item)],
		"%s  %s" % [_zh("5Z+656GA5pS75Ye7"), str(snappedf(base_attack_power, 0.1))],
		"%s  %d%%" % [_zh("6Ziy5b6h546H"), int(round(defense_ratio * 100.0))],
	]
	var bonus_lines: Array = _build_equipment_bonus_lines(item)
	for bonus_line in bonus_lines:
		lines.append(String(bonus_line))
	return "\n".join(lines)


func _build_potion_text(item: Dictionary) -> String:
	var lines := [
		"%s  x%d / %d" % [
			_zh("5aCG5Y+g"),
			max(1, int(item.get("stack_count", 1))),
			max(1, int(item.get("max_stack", 1))),
		],
		"%s  %d" % [_zh("5oGi5aSN55Sf5ZG9"), int(round(float(item.get("restore_hp_value", 0.0))))],
		"%s  %.1f%s" % [_zh("5L2/55So5pe26Ze0"), float(item.get("use_startup_sec", 0.0)), _zh("56eS")],
	]
	return "\n".join(lines)


func _load_item_icon(item: Dictionary) -> Texture2D:
	var icon_path: String = String(item.get("icon_path", ""))
	if icon_path.is_empty():
		return null
	var resource: Resource = load(icon_path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _update_position_to_mouse() -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position() + FOLLOW_OFFSET
	var panel_size: Vector2 = panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel.reset_size()
		panel_size = panel.size

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var target_position := mouse_position
	if target_position.x + panel_size.x > viewport_size.x - 8.0:
		target_position.x = viewport_size.x - panel_size.x - 8.0
	if target_position.y + panel_size.y > viewport_size.y - 8.0:
		target_position.y = viewport_size.y - panel_size.y - 8.0
	target_position.x = maxf(8.0, target_position.x)
	target_position.y = maxf(8.0, target_position.y)
	panel.position = target_position


func _get_total_base_attack_power(item: Dictionary) -> float:
	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if inventory_runtime != null and inventory_runtime.has_method("get_item_total_base_attack_power"):
		return float(inventory_runtime.call("get_item_total_base_attack_power", item))
	return float(item.get("base_attack_power", 0.0))


func _get_total_base_defense_ratio(item: Dictionary) -> float:
	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if inventory_runtime != null and inventory_runtime.has_method("get_item_total_base_defense_ratio"):
		return float(inventory_runtime.call("get_item_total_base_defense_ratio", item))
	return float(item.get("base_defense_ratio", 0.0))


func _get_reinforcement_label(item: Dictionary) -> String:
	var inventory_runtime: Node = get_node_or_null("/root/InventoryRuntime")
	if inventory_runtime != null and inventory_runtime.has_method("get_item_reinforcement_label"):
		return String(inventory_runtime.call("get_item_reinforcement_label", item))
	return "%d/4" % int(item.get("reinforcement_level", 0))


func _build_reinforcement_stone_text(item: Dictionary) -> String:
	var description: String = String(item.get("effect_description", ""))
	if not description.is_empty():
		return description

	var effect_key: String = String(item.get("reinforcement_effect_key", ""))
	var min_value: float = float(item.get("reinforcement_value_min", 0.0))
	var max_value: float = float(item.get("reinforcement_value_max", 0.0))
	if effect_key == "base_defense_ratio":
		return _zh("5Z+656GA6Ziy5b6h546HICslZCUlfiVkJSU=") % [int(round(min_value * 100.0)), int(round(max_value * 100.0))]
	return _zh("5Z+656GA5pS75Ye75YqbICslZH4lZA==") % [int(round(min_value)), int(round(max_value))]


func _build_crafting_material_text(item: Dictionary) -> String:
	var lines := [
		"%s  x%d / %d" % [
			_zh("5aCG5Y+g"),
			max(1, int(item.get("stack_count", 1))),
			max(1, int(item.get("max_stack", 1))),
		],
		String(item.get("effect_description", _zh("5Yi25L2c5p2Q5paZ44CC"))),
		_zh("5Y+M5Ye75Y+v6L+b6KGM5Yi25L2c44CC"),
	]
	return "\n".join(lines)


func _build_equipment_bonus_lines(item: Dictionary) -> Array:
	var reinforcement_bonus: Dictionary = item.get("reinforcement_bonus", {}) as Dictionary
	if reinforcement_bonus.is_empty():
		return []

	var lines: Array = []
	var power_bonus: int = int(reinforcement_bonus.get("attack", 0))
	var agility_bonus: int = int(reinforcement_bonus.get("agility", 0))
	var vitality_bonus: int = int(reinforcement_bonus.get("vitality", 0))
	var spirit_bonus: int = int(reinforcement_bonus.get("spirit", 0))
	if power_bonus > 0:
		lines.append(_zh("5Yqb6YePICArJWQ=") % power_bonus)
	if agility_bonus > 0:
		lines.append(_zh("5pWP5o23ICArJWQ=") % agility_bonus)
	if vitality_bonus > 0:
		lines.append(_zh("5L2T6LSoICArJWQ=") % vitality_bonus)
	if spirit_bonus > 0:
		lines.append(_zh("57K+56WeICArJWQ=") % spirit_bonus)
	return lines


func _zh(encoded: String) -> String:
	return Marshalls.base64_to_utf8(encoded)
