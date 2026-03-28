extends Control

@export var backpack_grid_path: NodePath
@export var warehouse_grid_path: NodePath
@export var slot_texture: Texture2D
@export var backpack_slot_count: int = 24
@export var warehouse_slot_count: int = 64

@onready var backpack_grid: GridContainer = get_node_or_null(backpack_grid_path)
@onready var warehouse_grid: GridContainer = get_node_or_null(warehouse_grid_path)


func _ready() -> void:
	_fill_grid(backpack_grid, backpack_slot_count, Vector2(84.0, 84.0))
	_fill_grid(warehouse_grid, warehouse_slot_count, Vector2(44.0, 44.0))


func _fill_grid(grid: GridContainer, count: int, slot_size: Vector2) -> void:
	if grid == null or slot_texture == null:
		return
	if grid.get_child_count() > 0:
		return

	for i in range(count):
		var slot := TextureRect.new()
		slot.custom_minimum_size = slot_size
		slot.texture = slot_texture
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(slot)
