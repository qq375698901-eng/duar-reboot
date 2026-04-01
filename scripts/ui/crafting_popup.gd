extends Control

signal crafting_confirmed(result: Dictionary)

const CONTAINER_BACKPACK := &"backpack"
const CONTAINER_WAREHOUSE := &"warehouse"

@onready var overlay_dim: ColorRect = $OverlayDim
@onready var panel_shell: PanelContainer = $PanelShell
@onready var title_label: Label = $PanelShell/Margin/VBox/TitleLabel
@onready var material_name_label: Label = $PanelShell/Margin/VBox/MaterialNameLabel
@onready var description_label: Label = $PanelShell/Margin/VBox/DescriptionLabel
@onready var recipe_select: OptionButton = $PanelShell/Margin/VBox/RecipeSelect
@onready var recipe_detail_label: Label = $PanelShell/Margin/VBox/RecipeDetailLabel
@onready var status_label: Label = $PanelShell/Margin/VBox/StatusLabel
@onready var confirm_button: Button = $PanelShell/Margin/VBox/ButtonRow/ConfirmButton
@onready var cancel_button: Button = $PanelShell/Margin/VBox/ButtonRow/CancelButton

var _inventory_runtime: Node
var _source_container: StringName = &""
var _source_index: int = -1
var _recipes: Array = []


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_dim.gui_input.connect(_on_overlay_gui_input)
	recipe_select.item_selected.connect(_on_recipe_selected)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func open_popup(inventory_runtime: Node, source_container: StringName, source_index: int) -> void:
	_inventory_runtime = inventory_runtime
	_source_container = source_container
	_source_index = source_index

	var source_item: Dictionary = _get_source_item()
	if source_item.is_empty():
		close_popup()
		return

	title_label.text = _zh("5Yi25L2c6KOF5aSH")
	material_name_label.text = String(source_item.get("display_name", _zh("5p2Q5paZ")))
	description_label.text = String(source_item.get("effect_description", _zh("6K+36YCJ5oup6KaB5Yi25L2c55qE54mp5ZOB44CC")))
	_rebuild_recipe_options()
	show()
	visible = true
	grab_focus()


func close_popup() -> void:
	hide()
	visible = false
	_recipes.clear()
	recipe_select.clear()
	_status_set(_zh("6K+36YCJ5oup6KaB5Yi25L2c55qE6KOF5aSH44CC"))


func is_open() -> bool:
	return visible


func _rebuild_recipe_options() -> void:
	_recipes.clear()
	recipe_select.clear()

	if _inventory_runtime != null and _inventory_runtime.has_method("get_scrap_metal_crafting_recipes"):
		_recipes = _inventory_runtime.call("get_scrap_metal_crafting_recipes") as Array

	for recipe_value in _recipes:
		if not (recipe_value is Dictionary):
			continue
		var recipe: Dictionary = recipe_value as Dictionary
		recipe_select.add_item(String(recipe.get("product_display_name", _zh("5pyq55+l6KOF5aSH"))))

	var has_recipes: bool = recipe_select.item_count > 0
	recipe_select.disabled = not has_recipes
	confirm_button.disabled = not has_recipes
	if has_recipes:
		recipe_select.select(0)
		_update_recipe_details(0)
	else:
		recipe_detail_label.text = _zh("5b2T5YmN5rKh5pyJ5Y+v5Yi25L2c55qE6YWN5pa544CC")
		_status_set(_zh("5b2T5YmN5rKh5pyJ5Y+v5Yi25L2c55qE6KOF5aSH44CC"))


func _on_recipe_selected(index: int) -> void:
	_update_recipe_details(index)


func _update_recipe_details(index: int) -> void:
	if index < 0 or index >= _recipes.size():
		recipe_detail_label.text = _zh("5b2T5YmN5rKh5pyJ5Y+v5Yi25L2c55qE6YWN5pa544CC")
		confirm_button.disabled = true
		_status_set(_zh("6K+36YCJ5oup6KaB5Yi25L2c55qE6KOF5aSH44CC"))
		return

	var recipe: Dictionary = _recipes[index] as Dictionary
	var cost_display_name: String = String(recipe.get("cost_display_name", _zh("5p2Q5paZ")))
	var cost_count: int = max(1, int(recipe.get("cost_count", 1)))
	var description: String = String(recipe.get("description", _zh("5Yi25L2c6KOF5aSH44CC")))
	recipe_detail_label.text = "%s\n%s%d %s%s" % [description, _zh("5raI6ICX77ya"), cost_count, _zh("5Liq"), cost_display_name]
	confirm_button.disabled = false
	_status_set("%s%s" % [_zh("5Y+v5Yi25L2c77ya"), String(recipe.get("product_display_name", _zh("6KOF5aSH")))])


func _on_confirm_pressed() -> void:
	if _inventory_runtime == null or not _inventory_runtime.has_method("craft_from_scrap_metal"):
		return
	var selected_index: int = recipe_select.selected
	if selected_index < 0 or selected_index >= _recipes.size():
		return

	var recipe: Dictionary = _recipes[selected_index] as Dictionary
	var product_definition_id: String = String(recipe.get("product_definition_id", ""))
	var result: Dictionary = _inventory_runtime.call(
		"craft_from_scrap_metal",
		_source_container,
		_source_index,
		product_definition_id
	) as Dictionary

	if bool(result.get("success", false)):
		crafting_confirmed.emit(result)
		close_popup()
		return

	_status_set(_build_failure_text(String(result.get("reason", ""))))


func _on_cancel_pressed() -> void:
	close_popup()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close_popup()


func _get_source_item() -> Dictionary:
	if _inventory_runtime == null:
		return {}
	if _source_container == CONTAINER_BACKPACK and _inventory_runtime.has_method("get_backpack_slots"):
		var backpack_slots: Array = _inventory_runtime.call("get_backpack_slots") as Array
		if _source_index >= 0 and _source_index < backpack_slots.size():
			var backpack_value: Variant = backpack_slots[_source_index]
			if backpack_value is Dictionary:
				return backpack_value as Dictionary
	if _source_container == CONTAINER_WAREHOUSE and _inventory_runtime.has_method("get_warehouse_slots"):
		var warehouse_slots: Array = _inventory_runtime.call("get_warehouse_slots") as Array
		if _source_index >= 0 and _source_index < warehouse_slots.size():
			var warehouse_value: Variant = warehouse_slots[_source_index]
			if warehouse_value is Dictionary:
				return warehouse_value as Dictionary
	return {}


func _build_failure_text(reason: String) -> String:
	match reason:
		"backpack_full":
			return _zh("6IOM5YyF5bey5ruh44CC")
		"insufficient_material":
			return _zh("5bqf5byD6YeR5bGe5LiN6Laz44CC")
		"invalid_recipe":
			return _zh("6YWN5pa55LiN5Y+v55So44CC")
		_:
			return _zh("5Yi25L2c5aSx6LSl44CC")


func _status_set(text: String) -> void:
	status_label.text = text


func _zh(encoded: String) -> String:
	return Marshalls.base64_to_utf8(encoded)
