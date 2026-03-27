extends Node2D
class_name DungeonRoom2D

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
}

@export var room_id: StringName
@export var room_display_name: String = ""
@export var region_kind: RegionKind = RegionKind.DUNGEON
@export var room_type: RoomType = RoomType.UNKNOWN
@export var room_type_label: String = ""
@export var gameplay_tags: PackedStringArray = []
@export_range(0, 10, 1) var encounter_level: int = 0


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
		_:
			return &"unknown"
