class_name BallActor3D
extends Node3D

## Standard linear parabolic trajectory flight
func play_trajectory(start_pos: Vector3, end_pos: Vector3, apex_height: float, duration: float) -> void:
	visible = true
	if duration <= 0.0:
		global_position = end_pos
		return

	var elapsed: float = 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t: float = clamp(elapsed / duration, 0.0, 1.0)

		# Linear X/Z interpolation
		var current_pos: Vector3 = start_pos.lerp(end_pos, t)

		# Parabolic Y height arc
		var parabolic_arc: float = 4.0 * apex_height * t * (1.0 - t)
		current_pos.y = lerp(start_pos.y, end_pos.y, t) + parabolic_arc

		global_position = current_pos
		await get_tree().process_frame

	global_position = end_pos


## Quadratic Bezier trajectory flight using control point for sets and spikes
func play_bezier_trajectory(p0: Vector3, p1: Vector3, p2: Vector3, duration: float) -> void:
	visible = true
	if duration <= 0.0:
		global_position = p2
		return

	var elapsed: float = 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t: float = clamp(elapsed / duration, 0.0, 1.0)

		# Quadratic Bezier formula: (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
		var q0: Vector3 = p0.lerp(p1, t)
		var q1: Vector3 = p1.lerp(p2, t)
		global_position = q0.lerp(q1, t)

		await get_tree().process_frame

	global_position = p2
