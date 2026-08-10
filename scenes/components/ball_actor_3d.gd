class_name BallActor3D
extends Node3D

const SignatureSurgeScript := preload(
	"res://scenes/components/signature_surge_3d.gd"
)

## The ball, and the streak behind it.
##
## The trail is not decoration. Playback shows a rally at speed with no numbers
## on screen, and the two things a viewer needs to read off a flight are *how
## well was that contact made* and *how hard was it struck* -- which is exactly
## what the caption used to have to say in words after the fact. So the trail
## carries both, and carries them on separate channels:
##
## - **Colour is quality**, on the five grade tiers every rating in the game is
##   already coloured by: gold, green, blue, white, red. One scale to learn.
## - **Length and weight are power.** A driven spike leaves a long heavy streak;
##   a floated set leaves almost nothing behind it.
##
## Splitting them is the whole point. Asked to carry both, one channel makes red
## mean "hammered" and "shanked" at once, and those are the two readings a
## viewer most needs to tell apart. See `BallPresentation.trail_style`.

## Ghosts at full power. Fourteen at the trail's own spacing reaches a bit over
## two metres behind the ball, which is long enough to read as a streak at
## broadcast camera distance and short enough not to arrive before the ball does.
const MAX_GHOSTS: int = 14
## The shortest streak a moving ball leaves. Not zero: a ball with no trail at
## all reads as a bug rather than as a soft touch.
const MIN_GHOSTS: int = 2
## How far apart samples are taken. Constant in metres rather than in time, so a
## fast ball's streak is genuinely longer instead of merely more finely sampled.
const GHOST_SPACING_METERS: float = 0.16
const GHOST_RADIUS: float = 0.115
## How wide the streak is at its head, from a soft ball to a driven one.
const HEAD_SCALE_MIN: float = 0.44
const HEAD_SCALE_MAX: float = 0.86
## How solid the streak is at its head, on the same axis.
const HEAD_ALPHA_MIN: float = 0.26
const HEAD_ALPHA_MAX: float = 0.72

@onready var ball_mesh: MeshInstance3D = $BallMesh
@onready var trail_root: Node3D = $Trail

var sample_history: Array[Vector3] = []
var _ghosts: Array[MeshInstance3D] = []
var _ghost_material: StandardMaterial3D = null
var _trail_color: Color = Color(0.95, 0.95, 0.95)
var _trail_power: float = 0.5
var _live_ghosts: int = MIN_GHOSTS
var _impact_root: Node3D
var _impact_ring: MeshInstance3D
var _impact_sparks: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_trail()
	_build_signature_impact()


## Built here rather than authored in the scene, because how many ghosts a
## flight uses is decided by that flight. Four were parked in
## `ball_actor_3d.tscn` and the count was therefore a property of the file.
func _build_trail() -> void:
	if not _ghosts.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = GHOST_RADIUS
	mesh.height = GHOST_RADIUS * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	_ghost_material = StandardMaterial3D.new()
	## Unshaded, and additive at the head. A trail lit like a solid object reads
	## as a queue of balls; a trail that glows reads as the path one ball took.
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ghost_material.disable_receive_shadows = true
	mesh.material = _ghost_material
	for index in range(MAX_GHOSTS):
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.visible = false
		## Its own material, because each ghost carries a different alpha and a
		## StandardMaterial3D has no per-instance colour to vary. Fourteen small
		## materials built once at startup, not per flight.
		ghost.material_override = _ghost_material.duplicate()
		trail_root.add_child(ghost)
		_ghosts.append(ghost)


## Successful signature contact belongs to the ball. A thin expanding ring and
## radial fragments are generated once and animated around this actor, so the
## flare follows the sampled ball position rather than hanging over the voli.
func _build_signature_impact() -> void:
	if _impact_root != null:
		return
	_impact_root = Node3D.new()
	_impact_root.name = "SignatureImpact"
	add_child(_impact_root)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.20
	ring_mesh.outer_radius = 0.215
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 5
	_impact_ring = MeshInstance3D.new()
	_impact_ring.name = "Shockwave"
	_impact_ring.mesh = ring_mesh
	_impact_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact_ring.material_override = _new_impact_material()
	_impact_root.add_child(_impact_ring)

	var spark_mesh := CylinderMesh.new()
	spark_mesh.top_radius = 0.003
	spark_mesh.bottom_radius = 0.008
	spark_mesh.height = 1.0
	spark_mesh.radial_segments = 4
	for index in range(12):
		var spark := MeshInstance3D.new()
		spark.name = "ImpactSpark%02d" % index
		spark.mesh = spark_mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.material_override = _new_impact_material()
		_impact_root.add_child(spark)
		_impact_sparks.append(spark)
	_impact_root.visible = false


func _new_impact_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_receive_shadows = true
	material.emission_enabled = true
	return material


## `phase == 0` is contact. The ring's normal is the resolved contact direction:
## Block Crush punches diagonally down; High Hands rises almost vertically with
## a small component along the ball's path.
func set_signature_impact(
	move: String, charge: float, succeeded: bool, phase: float,
	travel_direction: Vector3
) -> void:
	if _impact_root == null:
		return
	if move.is_empty() or not succeeded or phase < -0.08 or phase > 0.48:
		_impact_root.visible = false
		return
	var profile: Dictionary = SignatureSurgeScript.profile_for(move)
	var colour := Color(profile.colour)
	var normal := impact_normal_for(str(profile.move), travel_direction)
	_impact_root.quaternion = Quaternion(Vector3.UP, normal)
	_impact_root.visible = true

	var release := smoothstep(-0.08, 0.04, phase)
	var fade := 1.0 - smoothstep(0.18, 0.48, phase)
	var weight := release * fade * lerpf(0.48, 1.0, clampf(charge, 0.0, 1.0))
	var expansion := smoothstep(-0.06, 0.38, phase)
	_impact_ring.scale = Vector3.ONE * lerpf(0.42, 3.25, expansion)
	_set_impact_alpha(_impact_ring, colour, weight * 0.92)

	for index in range(_impact_sparks.size()):
		var spark := _impact_sparks[index]
		var angle := float(index) / float(_impact_sparks.size()) * TAU \
			+ phase * (0.8 if index % 2 == 0 else -0.55)
		## The impact root's local XZ plane is the shockwave plane.
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var radius := lerpf(0.10, 0.92, expansion) \
			* (0.78 + 0.22 * sin(float(index) * 2.4))
		var length := lerpf(0.05, 0.22, weight) \
			* (0.70 + 0.30 * absf(sin(phase * 31.0 + float(index))))
		spark.position = radial * radius
		spark.quaternion = Quaternion(Vector3.UP, radial)
		spark.scale = Vector3(1.0, maxf(length, 0.02), 1.0)
		_set_impact_alpha(
			spark, colour, weight * (0.42 + 0.38 * absf(sin(
				phase * 27.0 + float(index) * 1.7
			))),
		)


static func impact_normal_for(move: String, travel_direction: Vector3) -> Vector3:
	var flat := Vector3(travel_direction.x, 0.0, travel_direction.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	else:
		flat = flat.normalized()
	var normal := (flat + Vector3.UP * 0.14).normalized()
	if move.to_lower().replace(" ", "_") == "block_crush":
		normal = (flat * 0.72 + Vector3.DOWN * 0.82).normalized()
	elif move.to_lower().replace(" ", "_") == "high_hands":
		normal = (flat * 0.20 + Vector3.UP).normalized()
	return normal


func clear_signature_impact() -> void:
	if _impact_root != null:
		_impact_root.visible = false


func _set_impact_alpha(
	visual: MeshInstance3D, colour: Color, alpha: float
) -> void:
	var material := visual.material_override as StandardMaterial3D
	if material == null:
		return
	var shown := colour
	shown.a = clampf(alpha, 0.0, 1.0)
	material.albedo_color = shown
	material.emission = Color(colour.r, colour.g, colour.b, 1.0) * lerpf(
		1.0, 3.2, clampf(alpha, 0.0, 1.0)
	)


func reset_flight() -> void:
	visible = false
	sample_history.clear()
	clear_signature_impact()
	for ghost in _ghosts:
		ghost.visible = false


## Leaves the ball resting where the point ended instead of hiding it.
##
## Playback used to call `reset_flight()` the moment the last flight finished,
## so the landing was drawn for a single frame and then vanished -- the ball
## appeared to disappear in mid-air. Where the point ended is the thing a
## viewer most wants to look at, and it matters more now that a swing ruled
## out actually lands past the painted line: hiding it immediately threw away
## the only frame that showed the ball was out. The trail is cleared because a
## resting ball has no flight behind it, but the ball itself stays put until
## the next rally, a replay, or closing the screen resets it.
func hold_at_rest() -> void:
	sample_history.clear()
	for ghost in _ghosts:
		ghost.visible = false


## What this flight looked like, set once when it starts.
##
## Called before the first sample rather than derived per frame: quality and
## power are properties of the *contact*, and a trail that changed colour partway
## down a flight would be saying the contact changed its mind.
func set_flight_style(color: Color, power: float) -> void:
	_trail_color = color
	_trail_power = clampf(power, 0.0, 1.0)
	_live_ghosts = int(round(lerpf(
		float(MIN_GHOSTS), float(MAX_GHOSTS), _trail_power
	)))
	sample_history.clear()
	for ghost in _ghosts:
		ghost.visible = false


func set_flight_sample(world_position: Vector3, velocity: Vector3) -> void:
	visible = true
	global_position = world_position
	if velocity.length_squared() > 0.0001:
		ball_mesh.rotate_object_local(Vector3.RIGHT, velocity.length() * 0.012)
	_push_trail_sample(world_position)


func _push_trail_sample(world_position: Vector3) -> void:
	if sample_history.is_empty() \
			or sample_history[-1].distance_to(world_position) > GHOST_SPACING_METERS:
		sample_history.append(world_position)
	while sample_history.size() > _live_ghosts + 1:
		sample_history.pop_front()
	var head_scale := lerpf(HEAD_SCALE_MIN, HEAD_SCALE_MAX, _trail_power)
	var head_alpha := lerpf(HEAD_ALPHA_MIN, HEAD_ALPHA_MAX, _trail_power)
	for index in range(_ghosts.size()):
		var ghost := _ghosts[index]
		if index >= _live_ghosts:
			ghost.visible = false
			continue
		var history_index := sample_history.size() - 2 - index
		ghost.visible = history_index >= 0
		if history_index < 0:
			continue
		ghost.global_position = sample_history[history_index]
		## Tapered along the streak rather than stepped: the fade is the ghost's
		## own position in the tail, so the same code draws a two-ghost stub and a
		## fourteen-ghost comet without a second set of constants.
		var along := 1.0 - float(index + 1) / float(_live_ghosts + 1)
		ghost.scale = Vector3.ONE * head_scale * lerpf(0.30, 1.0, along)
		var material := ghost.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color(
				_trail_color, head_alpha * along * along
			)
