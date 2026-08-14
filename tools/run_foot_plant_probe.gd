extends Node

## Does the stance foot stay where it was put?
##
##     xvfb-run -a godot --path . res://tools/foot_plant_probe.tscn
##
## The question procedural foot placement exists to answer, asked of the drawn
## rig rather than of the model: while a foot is on the floor, how far does it
## travel in world space between frames? A planted foot moves zero. A foot that
## moves with the body is skating, and the amount it skates is the amount the
## stride cycle and the ground disagree by.
##
## **Aggregated over a whole stance, not per frame.** A per-frame ratio divides
## two small numbers, and the denominator is one frame of body travel -- which
## headless is whatever the loop happened to take. That reads a max of 150 off a
## walk and means nothing. Summed across each contiguous stance phase and divided
## by the body travel over the same frames, the jitter cancels and the number is
## the thing being asked about: over one step, how much of the body's travel did
## the planted foot copy?
##
## 0 is a foot that stayed where it was put. 1 is a foot that moved with the
## hips, which is what a rig with no plant does -- and the probe runs both ways
## on the same actor so that comparison is measured rather than asserted.
##
## Run at three speeds because the residual is not constant. `stride_cycle`
## advances by `travelled / stride_length_m`, and how far the foot actually
## sweeps in a stance depends on hip amplitude and leg length -- both of which
## move with the walk-to-run blend and neither of which is `stride_length_m`.
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const SPEEDS: Array[float] = [1.1, 2.8, 5.2]
const DIRECTIONS: Array[Dictionary] = [
	{"name": "forward", "world": Vector3(0.0, 0.0, -1.0)},
	{"name": "lateral", "world": Vector3(1.0, 0.0, 0.0)},
	{"name": "backpedal", "world": Vector3(0.0, 0.0, 1.0)},
]
## Long enough for a stable median at every speed above. 180 gave four stance
## phases at a walk and a median that moved from 0.82 to 2.33 between runs, which
## is not a measurement -- a walk covers less ground per frame, so it needs more
## frames for the same number of steps, not fewer.
const FRAMES: int = 900
var _last_max_pitch_correction: float = 0.0
var _last_max_roll_correction: float = 0.0
## **Driven at the frame rate the engine is actually running at**, not at a fixed
## step. The actor derives its own speed from displacement over
## `get_process_delta_time()`, so a step chosen independently of that clock draws
## a gait at whatever speed the mismatch implies rather than at the one asked
## for -- and headless, with nothing to draw, that clock runs far faster than 60
## frames a second.


func _ready() -> void:
	await get_tree().process_frame
	var selected_direction := ""
	var selected_speed := -1.0
	var frame_count := FRAMES
	## A full direction matrix is deliberately long. These selectors keep the
	## same drawn-process measurement useful while tuning one failure instead of
	## replacing it with a shorter, differently-clocked micro-probe.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--direction="):
			selected_direction = argument.trim_prefix("--direction=")
		elif argument.begins_with("--speed="):
			selected_speed = argument.trim_prefix("--speed=").to_float()
		elif argument.begins_with("--frames="):
			frame_count = maxi(argument.trim_prefix("--frames=").to_int(), 60)
	print("=== stance-foot slip, as a fraction of body travel over the stance")
	print("%10s %8s %8s %8s %8s %8s %8s %8s %8s" % [
		"direction", "speed", "plant", "steps", "median", "p95", "max",
		"hip_d", "roll_d",
	])
	for direction in DIRECTIONS:
		if not selected_direction.is_empty() \
				and str(direction.name) != selected_direction:
			continue
		for speed in SPEEDS:
			if selected_speed >= 0.0 \
					and not is_equal_approx(speed, selected_speed):
				continue
			for planted in [false, true]:
				var slips := await _walk(
					speed, planted, Vector3(direction.world), frame_count
				)
				slips.sort()
				if slips.is_empty():
					print("%10s %8.1f %8s  no stance phases -- the gait never put a foot down"
						% [direction.name, speed, "on" if planted else "off"])
					continue
				print("%10s %8.1f %8s %8d %8.3f %8.3f %8.3f %8.1f %8.1f" % [
					direction.name, speed, "on" if planted else "off", slips.size(),
					slips[slips.size() / 2],
					slips[mini(int(float(slips.size()) * 0.95), slips.size() - 1)],
					slips[-1],
					_last_max_pitch_correction, _last_max_roll_correction,
				])
	print("--- 0.000 is a planted foot; 1.000 is a foot travelling with the hips")
	get_tree().quit()


## Walk one actor in a straight line and watch its shoes.
func _walk(
	speed_mps: float,
	planted: bool,
	world_direction: Vector3,
	frame_count: int = FRAMES,
) -> Array[float]:
	var stage := Node3D.new()
	get_tree().root.add_child(stage)
	var actor: Node3D = ACTOR.instantiate()
	stage.add_child(actor)
	actor.configure(
		1, true, "Voli", "Right",
		{"height_cm": 190.0, "wingspan_cm": 194.0, "body_type": "Feli"},
	)
	actor.foot_plant_enabled = planted
	var slips: Array[float] = []
	## Per side: where the shoe was last frame, whether it was down, and the two
	## running totals for the stance phase currently underway.
	var previous := {}
	var travelled := 0.0
	var max_pitch_correction := 0.0
	var max_roll_correction := 0.0
	## One frame to settle: the first placement is an arrival rather than a step,
	## and the actor treats it as one.
	actor.set_tactical_position(Vector2.ZERO, Vector3.ZERO)
	await get_tree().process_frame
	for _frame in range(frame_count):
		var step := speed_mps * maxf(get_process_delta_time(), 0.0001)
		travelled += step
		actor.set_tactical_position(
			Vector2.ZERO, world_direction * travelled
		)
		## The branch every off-ball voli is in, which is the branch the plant
		## lives in. Posing through `set_pose` rather than reading the gait
		## directly is the whole point: the correction is applied there, and a
		## probe that reimplements it measures itself.
		actor.set_pose(
			RallyEventModel.EventType.SERVE, 0.0, 0.0, Vector2(0.0, -1.0), false
		)
		var gait := GaitBiomechanics.resolve(
			actor.stride_cycle, actor.ground_speed_mps, actor.travel_heading_offset
		)
		max_pitch_correction = maxf(max_pitch_correction, maxf(
			absf(actor.left_leg.rotation_degrees.x - float(gait.left_hip_degrees)),
			absf(actor.right_leg.rotation_degrees.x - float(gait.right_hip_degrees)),
		))
		max_roll_correction = maxf(max_roll_correction, maxf(
			absf(actor.left_leg.rotation_degrees.z + float(gait.abduction_degrees)),
			absf(actor.right_leg.rotation_degrees.z - float(gait.abduction_degrees)),
		))
		for side in ["Left", "Right"]:
			var shoe := actor.get_node_or_null(
				"BodyPivot/%sLeg/Knee/Shoe" % side
			) as Node3D
			if shoe == null:
				continue
			var here := shoe.global_position
			var down := bool(gait.get("%s_in_stance" % side.to_lower(), false))
			var was: Dictionary = previous.get(side, {})
			var foot_sum := float(was.get("foot", 0.0))
			var body_sum := float(was.get("body", 0.0))
			var carried := not was.is_empty() and down and bool(was.down)
			if carried:
				## Only frames where the foot was already down on the previous
				## one -- the frame it lands on is a placement, not a slip, and
				## counting it would report the step length as an error.
				foot_sum += Vector2(
					here.x - Vector3(was.at).x, here.z - Vector3(was.at).z
				).length()
				body_sum += step
			else:
				## Toe-off, or the first frame of a new stance. Bank the phase
				## that just ended if it covered enough ground to divide by.
				if body_sum > 0.05:
					slips.append(foot_sum / body_sum)
				foot_sum = 0.0
				body_sum = 0.0
			previous[side] = {
				"at": here, "down": down, "foot": foot_sum, "body": body_sum,
			}
		await get_tree().process_frame
	stage.queue_free()
	await get_tree().process_frame
	_last_max_pitch_correction = max_pitch_correction
	_last_max_roll_correction = max_roll_correction
	return slips
