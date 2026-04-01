extends Node2D
class_name DungeonLootChest2D

signal loot_opened(chest_size: int, granted_definition_ids: PackedStringArray)
signal interaction_requested(peer_id: int)

enum ChestSize {
	SMALL,
	MEDIUM,
	LARGE,
}

const FLOOR_SNAP_COLLISION_MASK := 1 | 4
const FLOOR_SNAP_UP_DISTANCE := 48.0
const FLOOR_SNAP_DOWN_DISTANCE := 160.0

const CLOSED_TEXTURES := {
	ChestSize.SMALL: preload("res://art/Medieval/PNG/Objects/chest_closed.png"),
	ChestSize.MEDIUM: preload("res://art/Medieval/PNG/Objects/chest_closed_medium.png"),
	ChestSize.LARGE: preload("res://art/Medieval/PNG/Objects/chest_closed_large.png"),
}

const OPEN_TEXTURES := {
	ChestSize.SMALL: preload("res://art/Medieval/PNG/Objects/chest_opened.png"),
	ChestSize.MEDIUM: preload("res://art/Medieval/PNG/Objects/chest_opened_medium.png"),
	ChestSize.LARGE: preload("res://art/Medieval/PNG/Objects/chest_opened_large.png"),
}

const VISIBLE_PIXEL_BOUNDS_BY_SIZE := {
	ChestSize.SMALL: Rect2(4.0, 8.0, 23.0, 15.0),
	ChestSize.MEDIUM: Rect2(8.0, 16.0, 46.0, 30.0),
	ChestSize.LARGE: Rect2(12.0, 24.0, 69.0, 45.0),
}

const TEMP_PLACEHOLDER_ROLL_COUNT_BY_SIZE := {
	ChestSize.SMALL: 1,
	ChestSize.MEDIUM: 2,
	ChestSize.LARGE: 3,
}

const EXP_REWARD_BY_SIZE := {
	ChestSize.SMALL: 100,
	ChestSize.MEDIUM: 500,
	ChestSize.LARGE: 2000,
}

const TEMP_PLACEHOLDER_LOOT_TABLE_BY_SIZE := {
	ChestSize.SMALL: [
		{"definition_id": "potion_t1_red", "weight": 5},
		{"definition_id": "reinforcement_stone_t1_attack", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_defense", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_power", "weight": 3},
		{"definition_id": "reinforcement_stone_t1_agility", "weight": 3},
		{"definition_id": "reinforcement_stone_t1_vitality", "weight": 3},
		{"definition_id": "reinforcement_stone_t1_spirit", "weight": 3},
	],
	ChestSize.MEDIUM: [
		{"definition_id": "potion_t1_red", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_attack", "weight": 5},
		{"definition_id": "reinforcement_stone_t1_defense", "weight": 5},
		{"definition_id": "reinforcement_stone_t1_power", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_agility", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_vitality", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_spirit", "weight": 4},
		{"definition_id": "longsword_basic", "weight": 1},
	],
	ChestSize.LARGE: [
		{"definition_id": "potion_t1_red", "weight": 3},
		{"definition_id": "reinforcement_stone_t1_attack", "weight": 5},
		{"definition_id": "reinforcement_stone_t1_defense", "weight": 5},
		{"definition_id": "reinforcement_stone_t1_power", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_agility", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_vitality", "weight": 4},
		{"definition_id": "reinforcement_stone_t1_spirit", "weight": 4},
		{"definition_id": "longsword_basic", "weight": 2},
	],
}

@export var chest_size: ChestSize = ChestSize.SMALL
@export var status_display_sec: float = 1.8

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var collision_shape: CollisionShape2D = $InteractArea/CollisionShape2D
@onready var prompt_label: Label = $PromptLabel
@onready var status_label: Label = $StatusLabel

var _rng := RandomNumberGenerator.new()
var _is_unlocked: bool = false
var _is_opened: bool = false
var _player_inside_count: int = 0
var _status_timer: float = 0.0
var _interacting_player: Node
var _local_interacting_peer_id: int = 1


func _ready() -> void:
	_rng.randomize()
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_refresh_size_layout()
	_refresh_visual_state()
	_refresh_prompt_state()
	_hide_status()


func _physics_process(delta: float) -> void:
	_refresh_local_interaction_state()
	if _status_timer > 0.0:
		_status_timer = maxf(0.0, _status_timer - delta)
		if _status_timer <= 0.0:
			_hide_status()

	if _is_opened or not _is_unlocked or _player_inside_count <= 0:
		return

	if _is_interact_up_just_pressed():
		if _should_route_interaction_to_network():
			interaction_requested.emit(_local_interacting_peer_id)
		return


func set_chest_size(value: int) -> void:
	chest_size = clampi(value, ChestSize.SMALL, ChestSize.LARGE)
	if not is_node_ready():
		return
	_refresh_size_layout()
	_refresh_visual_state()
	_refresh_prompt_state()


func set_is_unlocked(unlocked: bool) -> void:
	_is_unlocked = unlocked
	_refresh_prompt_state()


func set_is_opened(opened: bool, status_message: String = "") -> void:
	_is_opened = opened
	_refresh_visual_state()
	_refresh_prompt_state()
	if status_message.is_empty():
		if not _is_opened:
			_hide_status()
		return
	_show_status(status_message)


func is_opened() -> bool:
	return _is_opened


func can_player_interact(player: Node) -> bool:
	return not _is_opened and _is_unlocked and _is_player_close_enough(player)


func force_singleplayer_interact(player: Node = null) -> bool:
	if not can_player_interact(player):
		return false
	_interacting_player = player
	_local_interacting_peer_id = _resolve_body_peer_id(player)
	_try_open_chest()
	return true


func _should_route_interaction_to_network() -> bool:
	return multiplayer.has_multiplayer_peer() and not get_signal_connection_list("interaction_requested").is_empty()


func show_status_message(message: String) -> void:
	if message.is_empty():
		_hide_status()
		return
	_show_status(message)


func roll_reward_payload() -> Dictionary:
	return {
		"exp_reward": int(EXP_REWARD_BY_SIZE.get(chest_size, 0)),
		"definition_ids": _roll_placeholder_loot(),
	}


func grant_reward_payload_to_local_player(reward_payload: Dictionary, reward_player: Node = null) -> Dictionary:
	var target_player: Node = reward_player
	if target_player == null:
		target_player = _resolve_reward_player()
	var exp_reward: int = _grant_experience_to_player(target_player, int(reward_payload.get("exp_reward", 0)))
	var granted_definition_ids: PackedStringArray = _grant_definition_ids(
		_coerce_definition_ids(reward_payload.get("definition_ids", PackedStringArray()))
	)
	return {
		"exp_reward": exp_reward,
		"granted_definition_ids": granted_definition_ids,
	}


func snap_to_floor() -> void:
	if not is_inside_tree():
		return

	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return

	var from_point := global_position + Vector2(0.0, -FLOOR_SNAP_UP_DISTANCE)
	var to_point := global_position + Vector2(0.0, FLOOR_SNAP_DOWN_DISTANCE)
	var query := PhysicsRayQueryParameters2D.create(from_point, to_point, FLOOR_SNAP_COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return

	global_position.y = float(result.get("position", global_position).y)


func _try_open_chest() -> void:
	var reward_result := grant_reward_payload_to_local_player(roll_reward_payload(), _interacting_player)
	var exp_reward: int = int(reward_result.get("exp_reward", 0))
	var granted_definition_ids: PackedStringArray = _coerce_definition_ids(reward_result.get("granted_definition_ids", PackedStringArray()))

	_is_opened = true
	_refresh_visual_state()
	_refresh_prompt_state()
	_show_status(_build_open_status(exp_reward, granted_definition_ids.size()))
	loot_opened.emit(int(chest_size), granted_definition_ids)


func _roll_placeholder_loot() -> PackedStringArray:
	var table: Array = TEMP_PLACEHOLDER_LOOT_TABLE_BY_SIZE.get(chest_size, [])
	if table.is_empty():
		return PackedStringArray()

	var roll_count: int = int(TEMP_PLACEHOLDER_ROLL_COUNT_BY_SIZE.get(chest_size, 1))
	var results := PackedStringArray()
	for _index in range(max(1, roll_count)):
		var rolled_definition_id: String = _roll_weighted_definition_id(table)
		if not rolled_definition_id.is_empty():
			results.append(rolled_definition_id)
	return results


func _roll_weighted_definition_id(table: Array) -> String:
	var total_weight: int = 0
	for entry_value in table:
		if not (entry_value is Dictionary):
			continue
		total_weight += max(0, int((entry_value as Dictionary).get("weight", 0)))

	if total_weight <= 0:
		return ""

	var roll: int = _rng.randi_range(1, total_weight)
	var accumulated_weight: int = 0
	for entry_value in table:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		accumulated_weight += max(0, int(entry.get("weight", 0)))
		if roll <= accumulated_weight:
			return String(entry.get("definition_id", ""))
	return ""


func _grant_placeholder_loot(definition_ids: PackedStringArray) -> PackedStringArray:
	return _grant_definition_ids(definition_ids)


func _grant_definition_ids(definition_ids: PackedStringArray) -> PackedStringArray:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("add_item_to_backpack_by_definition"):
		return PackedStringArray()

	var granted := PackedStringArray()
	for definition_id in definition_ids:
		if bool(inventory_service.call("add_item_to_backpack_by_definition", definition_id)):
			granted.append(definition_id)
	return granted


func _refresh_visual_state() -> void:
	var texture: Texture2D = CLOSED_TEXTURES.get(chest_size, CLOSED_TEXTURES[ChestSize.SMALL])
	if _is_opened:
		texture = OPEN_TEXTURES.get(chest_size, OPEN_TEXTURES[ChestSize.SMALL])

	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _refresh_size_layout() -> void:
	var texture: Texture2D = CLOSED_TEXTURES.get(chest_size, CLOSED_TEXTURES[ChestSize.SMALL])
	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()
	var visible_bounds: Rect2 = VISIBLE_PIXEL_BOUNDS_BY_SIZE.get(
		chest_size,
		Rect2(0.0, 0.0, texture_size.x, texture_size.y)
	)
	var visible_bottom_y: float = visible_bounds.position.y + visible_bounds.size.y - 1.0
	var visible_height: float = visible_bounds.size.y
	sprite.position = Vector2(0.0, texture_size.y * 0.5 - visible_bottom_y - 1.0)

	var rect_shape := collision_shape.shape as RectangleShape2D
	if rect_shape != null:
		rect_shape.size = Vector2(maxf(36.0, visible_bounds.size.x * 0.82), maxf(24.0, visible_height * 0.55))
	collision_shape.position = Vector2(0.0, -visible_height * 0.45)

	var prompt_width: float = maxf(84.0, visible_bounds.size.x + 32.0)
	prompt_label.position = Vector2(-prompt_width * 0.5, -visible_height - 38.0)
	prompt_label.size = Vector2(prompt_width, 34.0)

	var status_width: float = maxf(108.0, visible_bounds.size.x + 52.0)
	status_label.position = Vector2(-status_width * 0.5, -visible_height - 70.0)
	status_label.size = Vector2(status_width, 32.0)


func _refresh_prompt_state() -> void:
	if _is_opened:
		prompt_label.visible = false
		return

	prompt_label.text = "UP\nLOOT"
	prompt_label.visible = _is_unlocked and _player_inside_count > 0


func _refresh_local_interaction_state() -> void:
	if interact_area == null:
		return

	var overlapping_local_player_count: int = 0
	var resolved_player: Node = null
	var resolved_peer_id: int = _local_interacting_peer_id
	for body in interact_area.get_overlapping_bodies():
		if not _is_local_interaction_body(body):
			continue
		overlapping_local_player_count += 1
		if resolved_player == null:
			resolved_player = body
			resolved_peer_id = _resolve_body_peer_id(body)

	if overlapping_local_player_count <= 0:
		var fallback_player: Node = _find_local_interaction_player()
		if _is_player_close_enough(fallback_player):
			overlapping_local_player_count = 1
			resolved_player = fallback_player
			resolved_peer_id = _resolve_body_peer_id(fallback_player)

	if overlapping_local_player_count == _player_inside_count \
			and resolved_player == _interacting_player \
			and resolved_peer_id == _local_interacting_peer_id:
		return

	_player_inside_count = overlapping_local_player_count
	_interacting_player = resolved_player
	_local_interacting_peer_id = resolved_peer_id
	_refresh_prompt_state()


func _is_interact_up_just_pressed() -> bool:
	return Input.is_action_just_pressed("interact_up") or Input.is_action_just_pressed("ui_up")


func _show_status(message: String) -> void:
	status_label.text = message
	status_label.visible = true
	_status_timer = maxf(0.0, status_display_sec)


func _hide_status() -> void:
	status_label.visible = false
	_status_timer = 0.0


func _on_body_entered(body: Node) -> void:
	if not _is_local_interaction_body(body):
		return
	_player_inside_count += 1
	_interacting_player = body
	_local_interacting_peer_id = _resolve_body_peer_id(body)
	_refresh_prompt_state()


func _on_body_exited(body: Node) -> void:
	if not _is_local_interaction_body(body):
		return
	_player_inside_count = max(0, _player_inside_count - 1)
	if _interacting_player == body:
		_interacting_player = null
	_refresh_prompt_state()


func _grant_experience_reward() -> int:
	var exp_reward: int = int(EXP_REWARD_BY_SIZE.get(chest_size, 0))
	return _grant_experience_to_player(_resolve_reward_player(), exp_reward)


func _grant_experience_to_player(player: Node, exp_reward: int) -> int:
	if exp_reward <= 0:
		return 0

	if player != null:
		if player.has_method("add_specialization_exp"):
			player.call("add_specialization_exp", exp_reward)
		if player.has_method("add_current_weapon_mastery_exp"):
			player.call("add_current_weapon_mastery_exp", exp_reward)
		return exp_reward

	var account_service: Node = _get_account_service()
	if account_service != null:
		if account_service.has_method("add_specialization_exp"):
			account_service.call("add_specialization_exp", exp_reward)

		var track_id: String = _resolve_weapon_mastery_track_id()
		if account_service.has_method("add_weapon_mastery_exp"):
			account_service.call("add_weapon_mastery_exp", track_id, exp_reward)
		return exp_reward

	return 0


func _resolve_reward_player() -> Node:
	if _interacting_player != null and is_instance_valid(_interacting_player):
		return _interacting_player

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	for child in current_scene.get_children():
		if String(child.name).begins_with("Player"):
			return child
	return current_scene.find_child("Player", true, false)


func _resolve_weapon_mastery_track_id() -> String:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service != null and inventory_service.has_method("get_equipped_weapon"):
		var equipped_item: Dictionary = inventory_service.call("get_equipped_weapon") as Dictionary
		var track_id: String = String(equipped_item.get("weapon_mastery_track_id", ""))
		if not track_id.is_empty():
			return track_id
	return PlayerAttributeProfile.DEFAULT_WEAPON_MASTERY_TRACK


func _get_account_service() -> Node:
	return get_node_or_null("/root/AccountService")


func _get_inventory_service() -> Node:
	return get_node_or_null("/root/InventoryService")


func _build_open_status(exp_reward: int, loot_count: int) -> String:
	if exp_reward > 0:
		return "EXP +%d" % exp_reward
	if loot_count > 0:
		return "Loot x%d" % loot_count
	return "Opened"


func _coerce_definition_ids(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var definition_ids := PackedStringArray()
	if value is Array:
		for entry in value:
			definition_ids.append(String(entry))
	return definition_ids


func _is_local_interaction_body(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not String(body.name).begins_with("Player"):
		return false
	var local_input_enabled: Variant = body.get("enable_local_input")
	if local_input_enabled is bool:
		return bool(local_input_enabled)
	return true


func _resolve_body_peer_id(body: Node) -> int:
	if body == null or not is_instance_valid(body):
		return 1
	if body is Node:
		return int((body as Node).get_multiplayer_authority())
	return 1


func _find_local_interaction_player() -> Node:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	for child in current_scene.get_children():
		if _is_local_interaction_body(child):
			return child
	return current_scene.find_child("Player", true, false)


func _is_player_close_enough(body: Node) -> bool:
	if not _is_local_interaction_body(body):
		return false
	if not (body is Node2D):
		return false

	var body_position: Vector2 = (body as Node2D).global_position
	var offset: Vector2 = body_position - global_position
	var half_size := Vector2(20.0, 14.0)
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		half_size = (collision_shape.shape as RectangleShape2D).size * 0.5
	return absf(offset.x - collision_shape.position.x) <= half_size.x + 14.0 \
		and absf(offset.y - collision_shape.position.y) <= half_size.y + 20.0
