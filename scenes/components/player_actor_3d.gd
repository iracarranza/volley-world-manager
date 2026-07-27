class_name PlayerActor3D
extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

## Animates player movement toward a target 3D world position
func animate_to_event(target_pos: Vector3, duration: float, action_type: String = "move") -> void:
	if duration <= 0.0:
		global_position = target_pos
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	# Smoothly interpolate position to target point
	tween.tween_property(self, "global_position", target_pos, duration)
