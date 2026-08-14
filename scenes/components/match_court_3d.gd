class_name MatchCourt3D
extends Node3D

const FALLBACK_PLAYER_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const UIPalette := preload("res://scripts/data/ui_palette.gd")

@export var court_width: float = 9.0
@export var court_length: float = 18.0
@export var player_actor_scene: PackedScene

@onready var camera_3d: Camera3D = $Camera3D
@onready var ball_actor: BallActor3D = $BallActor3D
@onready var players_container: Node3D = $Players

var player_actors: Dictionary = {}
var live_positions: Dictionary = {}
var home_player_ids: Dictionary = {}
var camera_preset: int = 0
var light_mode_enabled: bool = false

const CAMERA_PRESETS: Array[Dictionary] = [
	{"name": "Broadcast", "position": Vector3(12.5, 8.2, 10.8), "fov": 48.0},
	{"name": "End line", "position": Vector3(0.0, 7.1, 15.8), "fov": 46.0},
	{"name": "High tactical", "position": Vector3(0.0, 15.2, 9.4), "fov": 43.0},
]


func _ready() -> void:
	add_to_group("ui_palette_3d")
	apply_ui_palette(false)
	_apply_camera_preset()
	ball_actor.reset_flight()


func tactical_to_world(tactical_x: float, tactical_y: float, height: float = 0.0) -> Vector3:
	return Vector3(
		(tactical_x - 0.5) * court_width,
		height,
		(tactical_y - 0.5) * court_length,
	)


func setup_players(
	initial_home_positions: Dictionary,
	initial_opponent_positions: Dictionary,
	player_names: Dictionary = {},
	player_handedness: Dictionary = {},
	player_physical_profiles: Dictionary = {},
) -> void:
	for child in players_container.get_children():
		child.free()
	player_actors.clear()
	live_positions.clear()
	home_player_ids.clear()
	for raw_player_id in initial_home_positions:
		_spawn_player(
			int(raw_player_id), Vector2(initial_home_positions[raw_player_id]),
			true, str(player_names.get(int(raw_player_id), "HOME %s" % raw_player_id)),
			str(player_handedness.get(int(raw_player_id), "Right")),
			Dictionary(player_physical_profiles.get(int(raw_player_id), {})),
		)
	for raw_player_id in initial_opponent_positions:
		_spawn_player(
			int(raw_player_id), Vector2(initial_opponent_positions[raw_player_id]),
			false, str(player_names.get(int(raw_player_id), "AWAY %s" % raw_player_id)),
			str(player_handedness.get(int(raw_player_id), "Right")),
			Dictionary(player_physical_profiles.get(int(raw_player_id), {})),
		)


func ensure_player(
	player_id: int,
	position: Vector2,
	home_team: bool,
	display_name: String,
	dominant_hand: String = "Right",
	physical_profile: Dictionary = {},
) -> PlayerActor3D:
	if player_actors.has(player_id):
		return player_actors[player_id] as PlayerActor3D
	return _spawn_player(
		player_id, position, home_team, display_name, dominant_hand, physical_profile
	)


func _spawn_player(
	player_id: int,
	position: Vector2,
	home_team: bool,
	display_name: String,
	dominant_hand: String,
	physical_profile: Dictionary,
) -> PlayerActor3D:
	var scene_to_use := player_actor_scene if player_actor_scene != null else FALLBACK_PLAYER_SCENE
	var actor := scene_to_use.instantiate() as PlayerActor3D
	players_container.add_child(actor)
	actor.configure(
		player_id, home_team, display_name, dominant_hand, physical_profile
	)
	actor.apply_ui_palette(light_mode_enabled)
	player_actors[player_id] = actor
	live_positions[player_id] = position
	if home_team:
		home_player_ids[player_id] = true
	actor.set_tactical_position(position, tactical_to_world(position.x, position.y))
	return actor


func apply_ui_palette(light_mode: bool) -> void:
	light_mode_enabled = light_mode
	_apply_mesh_color($ArenaFloor, UIPalette.color(&"court_floor", light_mode))
	_apply_mesh_color($CourtSurface, UIPalette.color(&"court_surface", light_mode))
	for line in [
		$EndLineHome, $EndLineAway, $AttackLineHome, $AttackLineAway,
		$SidelineLeft, $SidelineRight,
	]:
		_apply_mesh_color(line, UIPalette.color(&"court_line", light_mode))
	_apply_mesh_color($Net, UIPalette.color(&"court_net", light_mode), true)
	_apply_mesh_color($LeftPost, UIPalette.color(&"court_post", light_mode), false, 0.18)
	_apply_mesh_color($RightPost, UIPalette.color(&"court_post", light_mode), false, 0.18)
	_apply_lighting(light_mode)
	for actor in player_actors.values():
		(actor as PlayerActor3D).apply_ui_palette(light_mode)


## The room the court is in, rather than a studio the court is photographed in.
##
## **The palette was never the problem.** `court_surface` is `d97a45`, a warm
## terracotta, and it was reaching the screen as a hard lemon yellow. Reported as
## reading like a template for realistic lighting rather than something cozy,
## which is exactly what was on top of it:
##
## - `tonemap_mode = 2` is Filmic, a curve whose whole purpose is to imitate the
##   response of photographic film -- it lifts highlights toward white and
##   crushes shadows, because that is what film does
## - the fill was an `OmniLight3D` at **energy 5.0** sitting six metres above a
##   nine-by-eighteen metre court, which saturates the surface long before the
##   tonemapper sees it
## - and the key was *cool* (0.92, 0.95, 1.0) against a *warm* fill, which is a
##   three-point product-render rig. Two opposed colour temperatures is the
##   single most recognisable signature of a photographed object, and this
##   interface is drawn rather than photographed
##
## So the rig is rebuilt around what makes a room feel warm rather than what
## makes a product look expensive: **one temperature, high ambient, low
## contrast**. A cozy room is not a dark room with a bright lamp -- it is a room
## where light arrives from everywhere and nothing is harshly lit, which in a
## renderer means most of the illumination coming from ambient and the
## directional lights only shaping.
##
## Linear tonemapping for the same reason the medium is halftone and pen: the
## rest of this interface is ink on stock, and a film curve is a claim about a
## camera that is not in the room.
const KEY_ENERGY: float = 0.62
const FILL_ENERGY: float = 0.95
## Ambient does most of the work. At the old 0.72 against a key of 1.15 and a
## fill of 5.0, ambient was a rounding error and every surface was either lit or
## in shadow; there was no third state, which is what "harsh" means.
const AMBIENT_ENERGY: float = 1.35
## Both lights on the warm side of neutral, and near enough to each other that
## the court does not read as two-toned. The fill is the warmer of the two
## because it stands in for bounce off a wooden floor.
const KEY_COLOR := Color(1.0, 0.96, 0.90)
const FILL_COLOR := Color(1.0, 0.90, 0.78)
## And the air, which is the third light and the largest of the three.
const AMBIENT_COLOR := Color(0.92, 0.87, 0.80)


func _apply_lighting(light_mode: bool) -> void:
	var environment := $WorldEnvironment.environment.duplicate() as Environment
	## Linear, not Filmic. See above.
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.background_color = UIPalette.color(&"canvas", light_mode).darkened(0.18)
	## **Warm, and it has to be warm.**
	##
	## `ink_muted` is a *text* colour and was being used as the light in the
	## arena -- a cool blue-grey, which is how a warm court came to sit in cold
	## shadow and why every voli's skin read as muddy olive. Ambient is most of
	## the illumination here, so its temperature is the room's temperature, and
	## a cool ambient makes warm pigment dirty rather than warm.
	##
	## Tinted toward the canvas rather than taken from it, so the two themes are
	## not the same room, but never far enough to go cool again.
	environment.ambient_light_color = AMBIENT_COLOR.lerp(
		UIPalette.color(&"canvas", light_mode), 0.22
	)
	environment.ambient_light_energy = AMBIENT_ENERGY
	$WorldEnvironment.environment = environment
	var key := $KeyLight as DirectionalLight3D
	key.light_color = KEY_COLOR
	key.light_energy = KEY_ENERGY
	var fill := $FillLight as OmniLight3D
	fill.light_color = FILL_COLOR
	fill.light_energy = FILL_ENERGY
	## Reaching well past the court rather than falling off inside it. A short
	## range is what made the fill a hotspot on one half and nothing on the
	## other; a fill that is visibly a lamp is not a fill.
	fill.omni_range = 34.0


func _apply_mesh_color(
	mesh_instance: MeshInstance3D,
	color: Color,
	transparent: bool = false,
	metallic: float = 0.0,
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = metallic
	if transparent or color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material

func set_player_position(player_id: int, position: Vector2) -> void:
	if not player_actors.has(player_id):
		return
	## **Facing is the actor's decision, and this used to overrule it.**
	##
	## `set_tactical_position` already derives the travel heading and then decides
	## whether to turn onto it -- a cone, a speed bound that is higher sideways
	## than backwards, and the rule that a blocker never turns their back on the
	## net. All of that exists so that a voli can move without turning: shuffle
	## along the line, open the hips and backpedal, keep their eyes on the ball.
	##
	## This method called `face_travel` unconditionally on the line above, before
	## any of it ran. So facing always equalled travel, `travel_heading_offset`
	## measured about zero because the two agreed by construction, and no voli
	## ever shuffled or backpedalled anywhere.
	##
	## Two symptoms, both reported from the same frame. Volis are not watching
	## the ball -- `look_toward` clamps the head to `HEAD_YAW_LIMIT_DEGREES` off
	## the *body*, so a voli force-turned away from the ball physically cannot
	## look at it. And a receiver ran to the ball facing their own footwork and
	## then span into their platform as the contact pose landed, because the
	## contact facing in `set_pose` is applied last and wins.
	##
	## It became much more visible with off-ball movement, for the obvious
	## reason: far more volis travel now, so far more of them were being spun.
	## One fact with two sources, and the cruder source ran first.
	live_positions[player_id] = position
	var actor := player_actors[player_id] as PlayerActor3D
	actor.set_tactical_position(position, tactical_to_world(position.x, position.y))


## How far along its own journey a leg is, which is not how far along the ball is.
##
## Every leg used to be sampled at the ball's `progress`, so a long walk inside a
## short flight was simply drawn fast -- unboundedly so. A plan entry may now
## carry `seconds`, the time the leg actually takes at the player's own top
## speed; where it does, the leg is sampled against that clock and is allowed to
## still be in progress when the flight ends. The next window's plan starts from
## wherever the body got to, so an unfinished leg continues rather than snapping.
##
## Entries without `seconds`, and calls that pass no window, keep the old
## behaviour exactly: the leg is the flight.
func _plan_fraction(
	movement: Dictionary, progress: float, window_seconds: float
) -> float:
	var delay_seconds := maxf(float(movement.get("delay_seconds", 0.0)), 0.0)
	var elapsed := clampf(progress, 0.0, 1.0) * maxf(window_seconds, 0.0)
	if delay_seconds > 0.0 and elapsed <= delay_seconds:
		return 0.0
	var active_elapsed := maxf(elapsed - delay_seconds, 0.0)
	var leg_seconds := float(movement.get("seconds", 0.0))
	if window_seconds <= 0.0:
		return clampf(progress, 0.0, 1.0)
	if leg_seconds <= 0.0:
		return clampf(
			active_elapsed / maxf(window_seconds - delay_seconds, 0.0001),
			0.0, 1.0,
		)
	return clampf(active_elapsed / leg_seconds, 0.0, 1.0)


## Continuous progress for a planned leg.
##
## This used to quantise short journeys into whole steps: move for 55% of a
## slot, hold for the rest, then begin the next step. The rig already advances
## its gait from distance travelled, so quantising the *body* as well produced
## exactly the visible stop/start and single-frame pops it was intended to hide.
## A player's feet may step; their centre of mass does not teleport between
## footholds. Keep the public helper while callers migrate, but make it a
## continuous ease whose velocity reaches zero cleanly at both seams.
##
## Static and pure so the suite can hold continuity without a court to run it in.
## How close two teammates may be drawn, centre to centre, in metres.
##
## The same figure `match_screen.MIN_BODY_SEPARATION_METERS` opens stacked plan
## targets with, deliberately: one number for how much room a body takes up,
## whether the crowding is at the end of a leg or in the middle of one. It is
## comfortably wider than the 0.715 m the resolver treats as a torso, because
## two volis brushing shoulders is legal and two volis inside each other is not.
const BODY_CLEARANCE_METERS: float = 0.62
const UNSTACK_PASSES: int = 2

const STEP_QUANTISE_MAX_METERS: float = 2.6
## What share of each step is spent moving. The remainder is the body arriving
## and standing on it, which is the half that makes a step read as a step.
const STEP_DUTY: float = 0.55
const MAX_QUANTISED_STEPS: int = 4

## The least time a single step may be drawn in, in seconds.
##
## **Measured, after shipping this without measuring it.** Quantising packs each
## step's travel into `STEP_DUTY` of its slot, so a leg cut into three steps
## inside a short window gives each step a slot of a few hundredths and its
## moving part a fraction of that. Below one frame, the entire step lands on one
## frame: over eight rallies the worst single-frame displacement went from about
## 5 m/s before quantising to **13-25 m/s for seven of twelve volis**, all of
## them in the brief windows around a block. That is a pop, and it is the same
## thing quantising was meant to remove.
##
## So a step has to be affordable before it is drawn. At 60 fps this is about
## seven frames of movement per step, which is a step rather than a jump; a
## window too short to pay for that keeps the continuous lerp, which is honest
## -- a body crossing half a metre in a twelfth of a second is not taking a
## visible step either.
const MIN_STEP_SECONDS: float = 0.20


static func step_quantised_fraction(
	fraction: float,
	_leg_metres: float,
	_stride_metres: float,
	## How long the leg is being drawn over. Defaulted to something generous so
	## the pure-function gate can ask about shape without describing a window.
	_window_seconds: float = 1.0,
) -> float:
	var t := clampf(fraction, 0.0, 1.0)
	return smoothstep(0.0, 1.0, t)


## Where a leg is at a given fraction of itself, corner included.
func _plan_sample(movement: Dictionary, fraction: float, fallback: Vector2) -> Vector2:
	var start := Vector2(movement.get("start", fallback))
	var target := Vector2(movement.get("target", start))
	var waypoint: Variant = movement.get("waypoint", null)
	if not (waypoint is Vector2):
		return start.lerp(target, fraction)
	var corner := Vector2(waypoint)
	var first_distance := start.distance_to(corner)
	var second_distance := corner.distance_to(target)
	var corner_fraction := first_distance / maxf(first_distance + second_distance, 0.0001)
	if fraction <= corner_fraction:
		return start.lerp(corner, fraction / maxf(corner_fraction, 0.0001))
	return corner.lerp(
		target, (fraction - corner_fraction) / maxf(1.0 - corner_fraction, 0.0001)
	)


func apply_movement_plan(
	plan: Dictionary,
	progress: float,
	window_seconds: float = 0.0,
	## The voli about to play the ball. They are never pushed: their position is
	## the contact point, and moving it draws the contact away from the ball.
	immovable_id: int = -1,
) -> void:
	## Everyone gets sampled, including the players who are not going anywhere.
	##
	## The actor's gait is driven by the distance between successive placements,
	## so a player who stops being placed keeps whatever speed they last had --
	## and `set_pose` reads that every frame, so they hold a mid-stride pose
	## indefinitely. Frozen mid-stride is exactly the thing the gait model's own
	## test forbids at zero speed, arrived at from outside the model.
	##
	## Re-placing a stationary player at their current position costs a Vector2
	## compare and lets their speed estimate decay to zero, which puts their legs
	## under them. It matters much more now that standing still is the default
	## rather than something almost nobody did.
	for raw_player_id in live_positions:
		if plan.has(raw_player_id):
			continue
		set_player_position(int(raw_player_id), Vector2(live_positions[raw_player_id]))
	var sampled := {}
	for raw_player_id in plan:
		var player_id := int(raw_player_id)
		var movement: Dictionary = plan[raw_player_id]
		var fallback: Vector2 = live_positions.get(player_id, Vector2.ZERO)
		sampled[player_id] = _plan_sample(
			movement,
			_stepped(player_id, movement, _plan_fraction(
				movement, progress, window_seconds
			), window_seconds),
			fallback,
		)
	## Target separation is solved once, when the movement plan is built. The
	## former per-frame `_unstack` recomputed a shove axis from sampled positions;
	## as two blockers crossed the overlap boundary that axis could flip, visibly
	## swapping their order and making both bodies jitter.
	for player_id in sampled:
		set_player_position(int(player_id), Vector2(sampled[player_id]))


## Push bodies out of each other, every frame.
##
## `match_screen._separate_plan` already opens stacked *targets*, and that is a
## different problem from this one: it runs once when the plan is built and only
## looks at where legs end. Two volis whose endpoints are metres apart still
## walk straight through one another in the middle, which is what an outside
## hitter crossing the setter's ground looks like -- the endpoints were never
## the overlap.
##
## The mover's route is bent by `_navigation_waypoint` in the resolver, but that
## reads the positions once at leg start and cannot know where a body will have
## walked to by the time the mover gets there. This is the drawn half: the
## resolver charges the detour, and this stops two rigs occupying one space
## while it happens.
##
## Teammates only -- the net keeps the sides apart, and a voli across it is not
## in the way. The voli about to touch the ball is immovable, because moving
## them draws the contact happening somewhere the ball is not.
func _unstack(sampled: Dictionary, immovable_id: int) -> void:
	var here := {}
	for raw_player_id in live_positions:
		here[int(raw_player_id)] = _to_court_metres(
			Vector2(live_positions[raw_player_id])
		)
	for raw_player_id in sampled:
		here[int(raw_player_id)] = _to_court_metres(Vector2(sampled[raw_player_id]))
	var ids: Array = here.keys()
	if ids.size() < 2:
		return
	for _pass_index in range(UNSTACK_PASSES):
		for a_index in range(ids.size()):
			for b_index in range(a_index + 1, ids.size()):
				var a := int(ids[a_index])
				var b := int(ids[b_index])
				if (a < 100) != (b < 100):
					continue
				var a_movable := sampled.has(a) and a != immovable_id
				var b_movable := sampled.has(b) and b != immovable_id
				if not a_movable and not b_movable:
					continue
				var offset: Vector2 = here[b] - here[a]
				var gap := offset.length()
				if gap >= BODY_CLEARANCE_METERS:
					continue
				## Derived from the ids when two bodies are exactly coincident, so
				## a rally re-resolved from its seed opens the same stack the same
				## way -- the replay gate would otherwise catch this as drift.
				var axis := offset / gap if gap > 0.001 \
					else Vector2(1.0, 0.0).rotated(float((a + b) % 8) * PI * 0.25)
				var share := 0.5 if a_movable and b_movable else 1.0
				var overlap := (BODY_CLEARANCE_METERS - gap) * share
				if a_movable:
					here[a] = here[a] - axis * overlap
				if b_movable:
					here[b] = here[b] + axis * overlap
	for raw_player_id in sampled:
		var player_id := int(raw_player_id)
		if player_id == immovable_id:
			continue
		sampled[raw_player_id] = _from_court_metres(here[player_id])


func _to_court_metres(court_position: Vector2) -> Vector2:
	return Vector2(
		court_position.x * court_width, court_position.y * court_length
	)


func _from_court_metres(metres: Vector2) -> Vector2:
	return Vector2(
		metres.x / maxf(court_width, 0.001), metres.y / maxf(court_length, 0.001)
	)


## The leg's own fraction, quantised into whole steps when it is short enough to
## be walked rather than run. Stride length comes off the body, which already
## carries it -- a 1.72 m libero takes a shorter step than a 2.06 m middle and
## the difference is already modelled.
func _stepped(
	player_id: int, movement: Dictionary, fraction: float, window_seconds: float
) -> float:
	var actor := player_actors.get(player_id) as PlayerActor3D
	if actor == null:
		return fraction
	var start := Vector2(movement.get("start", Vector2.ZERO))
	var target := Vector2(movement.get("target", start))
	var delta := target - start
	var metres := Vector2(delta.x * court_width, delta.y * court_length).length()
	## The leg's own clock where it has one, not the flight's. A paced leg runs
	## longer than the window and therefore has more time per step, which is
	## exactly the case that can afford them.
	var seconds := maxf(float(movement.get("seconds", window_seconds)), window_seconds)
	return step_quantised_fraction(
		fraction, metres, actor.stride_length_m, seconds
	)


## Settle every leg where the window actually left it.
##
## This used to snap unconditionally to `target`, which was harmless while every
## leg finished with the flight and is not harmless now that a leg may be paced
## slower than the ball. A leg still travelling is left where it got to and
## picked up by the next window's plan, which starts from live positions.
func finish_movement_plan(plan: Dictionary, window_seconds: float = 0.0) -> void:
	for raw_player_id in plan:
		var player_id := int(raw_player_id)
		var movement: Dictionary = plan[raw_player_id]
		var fallback: Vector2 = live_positions.get(player_id, Vector2.ZERO)
		## **Stepped, exactly as the window was drawn.**
		##
		## This settled the leg from the *unquantised* fraction while every frame
		## before it used the quantised one, so the final frame of every window
		## jumped from wherever the step was holding to wherever the smooth curve
		## had got to -- up to a whole step, landing on one frame. Measured over
		## eight rallies: 0.41 m in a single frame, 24.7 m/s, on the short windows
		## around a block. Quantising was removing a glide and adding a pop at the
		## seam, and the seam is the frame the next window starts from.
		set_player_position(player_id, _plan_sample(
			movement,
			_stepped(
				player_id, movement,
				_plan_fraction(movement, 1.0, window_seconds), window_seconds
			),
			fallback,
		))


## The actor for a voli, or null. Public because a caller that needs to know
## where a body is *facing* -- to measure a platform against it, say -- cannot
## get that from a position.
func actor_for(player_id: int) -> PlayerActor3D:
	return player_actors.get(player_id) as PlayerActor3D


func set_player_pose(
	player_id: int,
	event_type: int,
	elevation: float,
	phase: float,
	direction: Vector2,
	highlighted: bool,
	contact_posture: String = "planted",
	contact_recovery: String = "platform",
	## Where the forearms have to point, solved by `PlatformAim` from the two
	## flights on the event. Empty for every contact that is not a pass, and for
	## a pass whose trajectories were not published -- the posture's own constant
	## is then still the fallback.
	platform_aim: Dictionary = {},
	action_context: Dictionary = {},
) -> void:
	if not player_actors.has(player_id):
		return
	var actor := player_actors[player_id] as PlayerActor3D
	actor.set_highlighted(highlighted)
	## Carried rather than derived here. The resolver already decided how
	## strained this contact was; the court's job is to hand that verdict to the
	## actor, not to form a second opinion from the positions.
	actor.contact_posture = contact_posture
	actor.contact_recovery = contact_recovery
	actor.contact_platform_aim = platform_aim
	## How much of a wall this blocker got up, from the resolver rather than from
	## the positions. `two` for anyone who is not blocking, which is what the rig
	## does with it anyway -- the branch only runs inside the block pose.
	actor.block_arms = StringName(str(
		Dictionary(action_context.get("block_jump_timing", {}))
			.get(player_id, {}).get("arms", "two")
	))
	actor.set_pose(
		event_type, elevation, phase, direction, highlighted, action_context
	)


## What this voli stands like between contacts. See `ReadyStance`.
##
## Separate from `set_player_pose` on purpose: a stance outlives the pose. It is
## set once per window for every body on the court, including the ten that
## `set_player_pose` is never called for, and those ten are the whole reason the
## stance exists.
func set_player_stance(player_id: int, stance_name: String) -> void:
	if not player_actors.has(player_id):
		return
	(player_actors[player_id] as PlayerActor3D).ready_stance = stance_name


## Whether this voli is standing at the net, in the normalised court space
## `live_positions` uses.
##
## The net is y = 0.5 and the court is `court_length` metres long, so the band
## has to be converted rather than written as a normalised constant -- a figure
## in normalised units is a distance whose meaning changes if the court does,
## which is the measured-with-the-wrong-instrument failure in miniature.
func at_the_net(player_id: int) -> bool:
	if not live_positions.has(player_id):
		return false
	var here: Vector2 = live_positions[player_id]
	return absf(here.y - 0.5) * court_length <= ReadyStance.NET_BAND_METERS


func reset_player_poses() -> void:
	for actor_resource in player_actors.values():
		var actor := actor_resource as PlayerActor3D
		actor.set_highlighted(false)
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)


func trajectory_world_position(trajectory: Dictionary, progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var start := Vector2(trajectory.get("start_position", Vector2(0.5, 0.5)))
	var control := Vector2(trajectory.get("control_position", start.lerp(
		Vector2(trajectory.get("end_position", start)), 0.5
	)))
	var end := Vector2(trajectory.get("end_position", start))
	var inverse := 1.0 - t
	var court_position := inverse * inverse * start \
		+ 2.0 * inverse * t * control + t * t * end
	## The same parabola `BallTrajectory.height_at_progress` draws, from the same
	## function, because it is the same ball. These were two hand-kept copies of
	## one curve -- the court sampled a Dictionary and the resource sampled its own
	## fields -- and a court that disagreed with the model about where the ball was
	## would have been invisible until something checked one against the other.
	var height := BallFlightModel.height_between(
		float(trajectory.get("start_height_meters", 1.0)),
		float(trajectory.get("end_height_meters", 1.0)),
		float(trajectory.get("duration", 0.5)),
		t,
	)
	return tactical_to_world(court_position.x, court_position.y, height)


func trajectory_world_velocity(trajectory: Dictionary, progress: float) -> Vector3:
	var lower := maxf(progress - 0.004, 0.0)
	var upper := minf(progress + 0.004, 1.0)
	if is_equal_approx(lower, upper):
		return Vector3.ZERO
	return (trajectory_world_position(trajectory, upper) \
		- trajectory_world_position(trajectory, lower)) / (upper - lower)


## What this flight is going to look like, before its first frame.
##
## The colour and weight belong to the contact that launched the ball, so they
## are set once here rather than recomputed every frame from a sample -- a trail
## that changed colour halfway down a flight would be saying the contact changed
## its mind. `light_mode_enabled` is read because the grade palette has a light
## variant and a gold trail on a pale court has to be a darker gold to read.
func begin_ball_flight(trajectory: Dictionary, quality: float) -> void:
	var style := BallPresentation.trail_style(
		quality, trajectory, light_mode_enabled
	)
	ball_actor.set_flight_style(Color(style.color), float(style.power))


func set_ball_trajectory_sample(trajectory: Dictionary, progress: float) -> void:
	var ball_position := trajectory_world_position(trajectory, progress)
	ball_actor.set_flight_sample(
		ball_position,
		trajectory_world_velocity(trajectory, progress),
	)
	_watch_the_ball(ball_position)


## Everybody on the court follows the ball with their eyes.
##
## `PlayerActor3D` has had a full head-look since the rig gained a neck -- an
## absolute heading in, clamped to what a neck can actually do, stored relative
## to the body so a player can watch the ball without turning to it. It had
## never been called. Twelve volis stared straight ahead through every rally
## while the machinery to do otherwise sat there complete.
##
## Driven from the ball's own sampled position rather than from the event's end
## point, so a head tracks the *flight* and not the destination -- watching
## where a ball is going to land is what a spectator does, not a player.
func _watch_the_ball(ball_position: Vector3) -> void:
	for raw_id in player_actors:
		var actor := player_actors[raw_id] as PlayerActor3D
		if actor == null:
			continue
		var offset := ball_position - actor.global_position
		var flat := Vector2(offset.x, offset.z)
		if flat.length_squared() < 0.0004:
			continue
		## Same convention as every other heading in the rig: Godot's forward is
		## -Z, so a direction (dx, dz) is `atan2(-dx, -dz)`. `flat` already holds
		## that pair, so the world's z is its y.
		var heading := atan2(-flat.x, -flat.y)
		## Pitch from the ball's height above the eyes rather than above the
		## floor -- a tall voli looks *down* at a ball a short one looks up at.
		var eye_height := actor.global_position.y + actor.shoulder_offset.y + 0.18
		var rise := ball_position.y - eye_height
		## The body first, then the head relative to it.
		##
		## `look_toward` clamps head yaw to HEAD_YAW_LIMIT_DEGREES off the torso,
		## so turning the head at a body pointed the wrong way buys nothing -- the
		## neck runs out of range and the voli stares past the play. Facing the
		## body at the ball is what gives the neck somewhere to work, and it is
		## also simply what a volleyball player does when nothing else is asking
		## anything of them.
		## Unless the body has a job that says otherwise. A voli at the net is
		## there to block, and a blocker never turns their back on it -- the same
		## rule `set_pose` applies to a blocker mid-jump, which until now reached
		## only the one voli playback had chosen to draw as the contact.
		##
		## The net is z = 0, so which side of it the body stands on is the whole
		## of the heading.
		if ReadyStance.faces_the_net(actor.ready_stance):
			actor.face_ball(0.0 if actor.global_position.z > 0.0 else PI)
		else:
			actor.face_ball(heading)
		## The head tracks the ball either way, and that is the point: a middle
		## facing the net still watches the play over their shoulder, out to the
		## neck's own limit, and loses sight of a ball that goes behind them.
		actor.look_toward(heading, rad_to_deg(atan2(rise, flat.length())))


func cycle_camera() -> String:
	camera_preset = (camera_preset + 1) % CAMERA_PRESETS.size()
	_apply_camera_preset()
	return str(CAMERA_PRESETS[camera_preset]["name"])


func _apply_camera_preset() -> void:
	if camera_3d == null:
		return
	var preset: Dictionary = CAMERA_PRESETS[camera_preset]
	camera_3d.position = Vector3(preset["position"])
	camera_3d.fov = float(preset["fov"])
	camera_3d.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)


## The rally's cognition stream, and the sampler both playback paths share.
##
## `active_by_player_for_spectators` rather than the unfiltered sampler the
## tactical board uses: this presentation is a camera in a gym and a setter's
## private weighing of three options is not something a camera can see. That is
## the only difference between the two renderers, and it is a difference of
## audience rather than of meaning -- everything about *what* a cue means is
## decided once, in `CognitionBadge`.
var cognition_cues: Array = []


func set_cognition_stream(cues: Array) -> void:
	cognition_cues = cues
	clear_cognition()


func sample_cognition(simulation_time: float) -> void:
	if cognition_cues.is_empty():
		return
	var active: Dictionary = CognitionTimeline.active_by_player_for_spectators(
		cognition_cues, simulation_time
	)
	for raw_id in player_actors:
		var player_id := int(raw_id)
		var actor := player_actors[player_id] as PlayerActor3D
		if actor == null:
			continue
		var cue: Resource = active.get(player_id) as Resource
		if cue == null:
			actor.hide_cognition_cue()
			continue
		actor.show_cognition_cue(cue, simulation_time)
		_apply_cognition_look(actor, cue)


## A cue that names something on the court also turns the head toward it.
##
## Through the actor's existing `look_toward`, so the cognition layer never
## learns how a neck works -- and only when the cue actually names a place. With
## no attention cue the existing ball tracking is left alone, which is what the
## handoff asks for and is also the honest default: a player with nothing
## particular in mind is watching the ball.
func _apply_cognition_look(actor: PlayerActor3D, cue: Resource) -> void:
	var target := Vector2.ZERO
	match str(cue.attention_kind):
		"hitter", "setter", "teammate":
			var other := int(cue.attention_player_id)
			if not live_positions.has(other):
				return
			target = Vector2(live_positions[other])
		"position":
			target = Vector2(cue.attention_position)
		_:
			return
	var from: Vector2 = live_positions.get(int(cue.player_id), Vector2(0.5, 0.5))
	var delta := tactical_to_world(target.x, target.y) \
		- tactical_to_world(from.x, from.y)
	if delta.length() < 0.05:
		return
	actor.look_toward(atan2(delta.x, delta.z))


func clear_cognition() -> void:
	for raw_id in player_actors:
		var actor := player_actors[raw_id] as PlayerActor3D
		if actor != null:
			actor.hide_cognition_cue()
			actor.clear_look()
