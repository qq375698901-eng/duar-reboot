extends Control

@export var backpack_grid_path: NodePath
@export var slot_texture: Texture2D
@export var slot_count: int = 24
@export var slot_size: Vector2 = Vector2(30.0, 30.0)
@export var accent_slots: PackedInt32Array = PackedInt32Array([0, 1, 5, 8, 13])
@export var selected_slot: int = 1

@onready var backpack_grid: GridContainer = get_node_or_null(backpack_grid_path)


func _ready() -> void:
	_fill_grid()


func _fill_grid() -> void:
	if backpack_grid == null or slot_texture == null:
		return
	if backpack_grid.get_child_count() > 0:
		return

	for i in range(slot_count):
		var slot_root := Control.new()
		slot_root.custom_minimum_size = slot_size
		slot_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var slot := TextureRect.new()
		slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.texture = slot_texture
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if accent_slots.has(i):
			slot.modulate = Color(1.0, 0.96, 0.88, 1.0)
		else:
			slot.modulate = Color(0.82, 0.86, 0.92, 0.8)
		slot_root.add_child(slot)

		if accent_slots.has(i):
			var core := ColorRect.new()
			core.offset_left = 10.0
			core.offset_top = 10.0
			core.offset_right = slot_size.x - 10.0
			core.offset_bottom = slot_size.y - 10.0
			core.mouse_filter = Control.MOUSE_FILTER_IGNORE
			core.color = Color(0.31, 0.38, 0.44, 0.95)
			slot_root.add_child(core)

		if i == selected_slot:
			var selected := ColorRect.new()
			selected.offset_left = 4.0
			selected.offset_top = 4.0
			selected.offset_right = slot_size.x - 4.0
			selected.offset_bottom = slot_size.y - 4.0
			selected.mouse_filter = Control.MOUSE_FILTER_IGNORE
			selected.color = Color(0.9, 0.75, 0.34, 0.18)
			slot_root.add_child(selected)

		backpack_grid.add_child(slot_root)
