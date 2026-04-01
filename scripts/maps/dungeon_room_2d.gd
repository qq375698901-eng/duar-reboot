extends Node2D
class_name DungeonRoom2D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const EXIT_DOOR_SCENE := preload("res://scenes/maps/dungeon_exit_door_2d.tscn")
const LOOT_CHEST_SCENE := preload("res://scenes/objects/dungeon_loot_chest_2d.tscn")
const ENEMY_BODY_GROUP := &"enemy_bodies"

signal exit_requested(room_id: StringName)

enum RegionKind {
	DUNGEON,
	TOWN,
}

enum RoomType {
	UNKNOWN,
	MONSTER,
	ELITE_MONSTER,
	RESOURCE,
	BOSS,
	EXTRACTION,
	BATTLE_ROOM,
}

enum LootChestSize {
	NONE,
	SMALL,
	MEDIUM,
	LARGE,
}

@export var room_id: StringName
@export var room_display_name: String = ""
@export var region_kind: RegionKind = RegionKind.DUNGEON
@export var room_type: RoomType = RoomType.UNKNOWN
@export var room_type_label: String = ""
@export var gameplay_tags: PackedStringArray = []
@export_range(0, 10, 1) var encounter_level: int = 0
@export var player_spawn_path: NodePath = NodePath("PlayerSpawn")
@export var exit_door_spawn_path: NodePath = NodePath("ExitDoorSpawn")
@export_file("*.tscn") var exit_target_scene_path: String = ""
@export var fall_death_y: float = 960.0
@export var enemy_fall_death_y: float = 960.0
@export var loot_chest_size: LootChestSize = LootChestSize.NONE
@export var loot_chest_spawn_path: NodePath = NodePath("LootChestSpawn")
@export var loot_chest_spawn_offset: Vector2 = Vector2(84.0, 12.0)

var _exit_door: Node2D
var _loot_chest: Node2D


func _ready() -> void:
	call_deferred("_bootstrap_room")


func _physics_process(_delta: float) -> void:
	_update_room_clear_interactables()


func is_dungeon_room() -> bool:
	return region_kind == RegionKind.DUNGEON


func get_room_type_key() -> StringName:
	match room_type:
		RoomType.MONSTER:
			return &"monster"
		RoomType.ELITE_MONSTER:
			return &"elite_monster"
		RoomType.RESOURCE:
			return &"resource"
		RoomType.BOSS:
			return &"boss"
		RoomType.EXTRACTION:
			return &"extraction"
		RoomType.BATTLE_ROOM:
			return &"battle_room"
		_:
			return &"unknown"


func _bootstrap_room() -> void:
	_ensure_room_player()
	_configure_room_enemies()
	_ensure_exit_door()
	_ensure_loot_chest()
	_update_room_clear_interactables()


func _ensure_room_player() -> void:
	var existing_player: Node2D = get_node_or_null("Player") as Node2D
	if existing_player == null:
		existing_player = PLAYER_SCENE.instantiate() as Node2D
		if existing_player == null:
			return
		existing_player.name = "Player"
		add_child(existing_player)
		var spawn_node: Node2D = get_node_or_null(player_spawn_path) as Node2D
		if spawn_node != null:
			existing_player.global_position = spawn_node.global_position

	if existing_player != null and existing_player.has_method("set_fall_death_y"):
		existing_player.call("set_fall_death_y", fall_death_y)

	_retarget_room_nodes(existing_player)


func _configure_room_enemies() -> void:
	for node in get_tree().get_nodes_in_group(ENEMY_BODY_GROUP):
		if not (node is Node):
			continue
		var body: Node = node as Node
		if body == self or not is_ancestor_of(body):
			continue
		if body.has_method("set_fall_death_y"):
			body.call("set_fall_death_y", enemy_fall_death_y)


func _ensure_exit_door() -> void:
	if _exit_door != null and is_instance_valid(_exit_door):
		return

	var existing_door: Node2D = get_node_or_null("ExitDoor") as Node2D
	if existing_door != null:
		_exit_door = existing_door
	else:
		var spawn_node: Node2D = get_node_or_null(exit_door_spawn_path) as Node2D
		if spawn_node == null:
			return
		_exit_door = EXIT_DOOR_SCENE.instantiate() as Node2D
		if _exit_door == null:
			return
		_exit_door.name = "ExitDoor"
		add_child(_exit_door)
		_exit_door.global_position = spawn_node.global_position

	if _exit_door != null and _exit_door.has_signal("exit_interacted"):
		var callback: Callable = Callable(self, "_on_exit_door_interacted")
		if not _exit_door.is_connected("exit_interacted", callback):
			_exit_door.connect("exit_interacted", callback)

	_place_exit_door_in_draw_order()


func _ensure_loot_chest() -> void:
	if loot_chest_size == LootChestSize.NONE:
		return
	if _loot_chest != null and is_instance_valid(_loot_chest):
		_apply_loot_chest_configuration()
		return

	var existing_chest: Node2D = get_node_or_null("LootChest") as Node2D
	if existing_chest != null:
		_loot_chest = existing_chest
	else:
		_loot_chest = LOOT_CHEST_SCENE.instantiate() as Node2D
		if _loot_chest == null:
			return
		_loot_chest.name = "LootChest"
		add_child(_loot_chest)

	_apply_loot_chest_configuration()
	_place_loot_chest_in_draw_order()


func _retarget_room_nodes(player: Node2D) -> void:
	for node in _collect_descendants(self):
		if node == player:
			continue
		if not _has_target_path_property(node):
			continue
		node.set("target_path", node.get_path_to(player))


func _collect_descendants(root: Node) -> Array[Node]:
	var results: Array[Node] = []
	for child in root.get_children():
		if child is Node:
			results.append(child)
			results.append_array(_collect_descendants(child))
	return results


func _has_target_path_property(node: Node) -> bool:
	for property_info in node.get_property_list():
		if String(property_info.get("name", "")) == "target_path":
			return true
	return false


func _update_room_clear_interactables() -> void:
	var room_cleared: bool = _get_alive_enemy_count() <= 0
	if _exit_door == null or not is_instance_valid(_exit_door):
		pass
	elif _exit_door.has_method("set_is_open"):
		_exit_door.call("set_is_open", room_cleared)

	if _loot_chest == null or not is_instance_valid(_loot_chest):
		return
	if _loot_chest.has_method("set_is_unlocked"):
		_loot_chest.call("set_is_unlocked", room_cleared)


func _get_alive_enemy_count() -> int:
	var alive_count: int = 0
	for node in get_tree().get_nodes_in_group(ENEMY_BODY_GROUP):
		if not (node is Node):
			continue
		var body: Node = node as Node
		if body == self or not is_ancestor_of(body):
			continue
		if body.has_method("is_dead") and bool(body.call("is_dead")):
			continue
		alive_count += 1
	return alive_count


func _on_exit_door_interacted() -> void:
	if _get_alive_enemy_count() > 0:
		return
	exit_requested.emit(room_id)
	var flow_runtime: Node = get_node_or_null("/root/DungeonFlowRuntime")
	if flow_runtime != null \
			and flow_runtime.has_method("is_run_active") \
			and bool(flow_runtime.call("is_run_active")) \
			and flow_runtime.has_method("advance_after_room_exit"):
		flow_runtime.call_deferred("advance_after_room_exit")
		return
	if not exit_target_scene_path.is_empty():
		get_tree().change_scene_to_file(exit_target_scene_path)


func _place_exit_door_in_draw_order() -> void:
	if _exit_door == null or not is_instance_valid(_exit_door):
		return

	var target_index: int = get_child_count() - 1
	for index in range(get_child_count()):
		var child: Node = get_child(index)
		if child == _exit_door:
			continue
		if child is CharacterBody2D:
			target_index = index
			break

	move_child(_exit_door, target_index)


func _apply_loot_chest_configuration() -> void:
	if _loot_chest == null or not is_instance_valid(_loot_chest):
		return

	var mapped_chest_size: int = max(0, int(loot_chest_size) - 1)
	if _loot_chest.has_method("set_chest_size"):
		_loot_chest.call("set_chest_size", mapped_chest_size)
	_loot_chest.global_position = _resolve_loot_chest_spawn_position()
	if _loot_chest.has_method("snap_to_floor"):
		_loot_chest.call_deferred("snap_to_floor")


func _resolve_loot_chest_spawn_position() -> Vector2:
	var spawn_node: Node2D = get_node_or_null(loot_chest_spawn_path) as Node2D
	if spawn_node != null:
		return spawn_node.global_position

	var exit_spawn_node: Node2D = get_node_or_null(exit_door_spawn_path) as Node2D
	if exit_spawn_node != null:
		return exit_spawn_node.global_position + loot_chest_spawn_offset

	return global_position + loot_chest_spawn_offset


func _place_loot_chest_in_draw_order() -> void:
	if _loot_chest == null or not is_instance_valid(_loot_chest):
		return

	var target_index: int = get_child_count() - 1
	for index in range(get_child_count()):
		var child: Node = get_child(index)
		if child == _loot_chest:
			continue
		if child is CharacterBody2D:
			target_index = max(0, index - 1)
			break

	move_child(_loot_chest, target_index)
