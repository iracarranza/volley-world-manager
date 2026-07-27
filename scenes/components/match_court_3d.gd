class_name MatchCourt3D
extends Node3D

# Default scene fallback
const FALLBACK_PLAYER_SCENE = preload("res://scenes/components/player_actor_3d.tscn")

@export var court_width: float = 9.0   # X-axis (-4.5 to 4.5 meters)
@export var court_length: float = 18.0 # Z-axis (-9.0 to 9.0 meters)

## Assign player_actor_3d.tscn in the Inspector (falls back to preload if null)
@export var player_actor_scene: PackedScene

@onready var camera_3d: Camera3D = $Camera3D
@onready var ball_actor: BallActor3D = $BallActor3D
@onready var players_container: Node3D = $Players if has_node("Players") else self

var player_actors: Dictionary = {} # Maps player_id -> PlayerActor3D instance


## Converts 2D normalized tactical court coords (0.0 to 1.0) into 3D world meters
func tactical_to_world(tactical_x: float, tactical_y: float, height: float = 0.0) -> Vector3:
	# Map (0.0 to 1.0) tactical space to 3D world centered at (0, 0, 0)
	var world_x: float = (tactical_x - 0.5) * court_width
	var world_z: float = (tactical_y - 0.5) * court_length
	var world_y: float = height

	return Vector3(world_x, world_y, world_z)


## Clears existing player nodes and spawns actors for the current rotation lineup
func setup_players_from_lineup(lineup: Variant) -> void:
	# Clean existing player actors
	for child in players_container.get_children():
		child.queue_free()
	player_actors.clear()

	var scene_to_use = player_actor_scene if player_actor_scene != null else FALLBACK_PLAYER_SCENE

	# Default 12-player positions matching event actor_ids
	var default_roster = {
		# Home Team
		"1": Vector2(0.5, 0.65), "2": Vector2(0.3, 0.65), "3": Vector2(0.2, 0.85),
		"4": Vector2(0.5, 0.85), "5": Vector2(0.8, 0.85), "6": Vector2(0.7, 0.65),

		# Away / Opponent Team
		"101": Vector2(0.8, 0.08), "102": Vector2(0.5, 0.15), "103": Vector2(0.4, 0.47),
		"104": Vector2(0.2, 0.15), "105": Vector2(0.8, 0.35), "106": Vector2(0.2, 0.35)
	}

	var active_data: Dictionary = default_roster.duplicate()
	if lineup is Dictionary and not lineup.is_empty():
		for k in lineup:
			active_data[str(k)] = lineup[k]

	# Spawn player models
	for p_id in active_data:
		var pos_val = active_data[p_id]
		var pos_2d: Vector2 = pos_val if pos_val is Vector2 else Vector2(0.5, 0.5)

		var player_instance = scene_to_use.instantiate()
		players_container.add_child(player_instance)

		var id_str: String = str(p_id)
		player_actors[id_str] = player_instance

		# Position actor on court floor (Y = 0)
		player_instance.global_position = tactical_to_world(pos_2d.x, pos_2d.y, 0.0)
