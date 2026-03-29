extends Node2D
class_name DungeonRoom2D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const EXIT_DOOR_SCENE := preload("res://scenes/maps/dungeon_exit_door_2d.tscn")
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

var _exit_door: Node2D


func _ready() -> void:
	call_deferred("_bootstrap_room")


func _physics_process(_delta: float) -> void:
	_update_exit_door_state()


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
	_ensure_exit_door()
	_update_exit_door_state()


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

	_retarget_room_nodes(existing_player)


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


func _update_exit_door_state() -> void:
	if _exit_door == null or not is_instance_valid(_exit_door):
		return
	if not _exit_door.has_method("set_is_open"):
		return

	_exit_door.call("set_is_open", _get_alive_enemy_count() <= 0)


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
