class_name BallActor3D
extends Node3D

@onready var ball_mesh: MeshInstance3D = $BallMesh
@onready var trail_ghosts: Array[MeshInstance3D] = [
	$Trail/Ghost1,
	$Trail/Ghost2,
	$Trail/Ghost3,
	$Trail/Ghost4,
]

var sample_history: Array[Vector3] = []


func reset_flight() -> void:
	visible = false
	sample_history.clear()
	for ghost in trail_ghosts:
		ghost.visible = false


func set_flight_sample(world_position: Vector3, velocity: Vector3) -> void:
	visible = true
	global_position = world_position
	if velocity.length_squared() > 0.0001:
		ball_mesh.rotate_object_local(Vector3.RIGHT, velocity.length() * 0.012)
	_push_trail_sample(world_position)


func _push_trail_sample(world_position: Vector3) -> void:
	if sample_history.is_empty() or sample_history[-1].distance_to(world_position) > 0.12:
		sample_history.append(world_position)
	while sample_history.size() > trail_ghosts.size() + 1:
		sample_history.pop_front()
	for index in range(trail_ghosts.size()):
		var history_index := sample_history.size() - 2 - index
		var ghost := trail_ghosts[index]
		ghost.visible = history_index >= 0
		if history_index >= 0:
			ghost.global_position = sample_history[history_index]
			var fade := 1.0 - float(index + 1) / float(trail_ghosts.size() + 1)
			ghost.scale = Vector3.ONE * lerpf(0.32, 0.70, fade)
