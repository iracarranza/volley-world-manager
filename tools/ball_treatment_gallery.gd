extends Node3D

## Draft ball treatments, drawn on a scripted flight. Nothing here is wired to
## the rally simulator or to `BallActor3D` -- it exists to answer "what could
## these look like" before any of them is built for real.
##
##     xvfb-run -a godot --path . --rendering-method gl_compatibility \
##         res://tools/ball_treatment_gallery.tscn -- out=/abs/dir shot=spike
##
## One canonical shot: a set arrives from the left, is contacted at x = -2.5,
## and leaves as a spike. The contact is the point of the whole exercise -- the
## deformation, the stamp and the spin ramp all happen there, and a trail is only
## comparable against another trail on the same flight.
##
## Colour is deliberately the *same* on every treatment. The real trail carries
## quality on hue, and letting it vary here would make two treatments differ for
## a reason that has nothing to do with what is being compared.

const OUT_SIZE := Vector2i(1280, 720)
## Simulated step. Output is written at 60 fps, so everything renders at half
## speed -- a 0.55 s spike is 1.1 s on screen, which is the difference between
## reading a treatment and watching it flicker past.
const DT: float = 1.0 / 120.0
const CONTACT := Vector3(-2.5, 3.3, 0.0)
const INCOMING_FROM := Vector3(-6.5, 1.7, 0.0)
const INCOMING_SECONDS: float = 0.8
const HOLD_SECONDS: float = 0.35
const GRAVITY: float = 9.8
const BALL_RADIUS: float = 0.105
## How long the ball is followed after it first reaches the floor.
const BOUNCE_SECONDS: float = 1.9
const MAX_BOUNCES: int = 4
## A volleyball is light and soft; it does not come off a gym floor like a
## basketball. Half the vertical speed back, and a little horizontal lost.
const RESTITUTION: float = 0.50
const FLOOR_KEEP: float = 0.86
const ROLL_DRAG: float = 0.55
## What topspin buys at the floor, in metres per second of forward speed.
const TOPSPIN_FLOOR_KICK: float = 1.9
const SPIN_LOSS_PER_BOUNCE: float = 0.62
## The change in velocity a hard swing makes, in metres per second. Every impact
## treatment is scaled against this one number, so a set moves nothing and a
## driven spike moves everything.
const IMPULSE_REFERENCE: float = 20.0
const MAX_SQUASH: float = 0.30
## How fast the ball recovers its shape, and how much it rings on the way. The
## first version used 9 Hz decaying over 0.085 s, which rings four or five times
## across a quarter second -- a water balloon. A volleyball is inflated and
## stiff: it compresses hard, overshoots once by a fraction of that, and stops.
const SQUASH_HZ: float = 19.0
const SQUASH_DECAY: float = 0.030
const SQUASH_SECONDS: float = 0.17
## The rebound is not as big as the compression. Symmetric ringing is most of
## what reads as gelatinous.
const SQUASH_REBOUND: float = 0.40
## Speed lines are emitted rather than attached: each strand records where the
## ball actually was, so it cannot reach back before the contact and its length
## is the distance covered in this window rather than a number.
const STRAND_COUNT: int = 8
const STRAND_SECONDS: float = 0.085
## How far the contact patch smears along the surface, per unit of compression.
const SHEAR_GAIN: float = 0.55
const SHELL_SECONDS: float = 0.16
## Flattened along the impulse. A round shell reads as a bubble.
const SHELL_FLATTEN: float = 0.30
## The band of the shell that is actually drawn, in latitude about the impulse.
const SHELL_BAND_MIN: float = 0.26 * PI
const SHELL_BAND_MAX: float = 0.74 * PI

## Speed and launch elevation per shot. The set and the bump exist for one
## argument only: if every ball gets the same treatment at the same strength,
## nothing reads as hard, so the soft contacts have to be in the comparison.
const SHOTS := {
	"spike": {"speed": 16.0, "elevation": -12.0, "spin_rps": 16.0},
	"set": {"speed": 8.0, "elevation": 45.0, "spin_rps": 3.0},
	"bump": {"speed": 7.0, "elevation": 55.0, "spin_rps": 1.5},
}

const TREATMENTS: Array[String] = [
	"blank", "history", "speed_lines", "wake", "ribbon", "skew", "leading",
	"spin", "stretch", "squash", "stamp", "air", "acquire", "combined",
]

const CAPTIONS := {
	"blank": "BLANK - no trail at all. The floor everything else reads against.",
	"history": "HISTORY - ghosts along the path already travelled. Today's trail.",
	"speed_lines": "SPEED LINES - strands emitted into the court and left behind.",
	"wake": "WAKE - displaced air behind the ball. Costs no colour.",
	"ribbon": "RIBBON - a band twisting at the spin rate. Rotation, depicted.",
	"skew": "SKEW - the trail peeled to one side. Sidespin, before it kicks.",
	"leading": "LEADING - drawn ahead of the ball, not behind it.",
	"spin": "TRUE SPIN - rotation about a real axis at a real rate.",
	"stretch": "STRETCH - elongated along velocity. Physically false, reads fast.",
	"squash": "SQUASH - flattened at the hit, overshooting back. Impact.",
	"stamp": "SHELL - air thrown outward by the blow, flattened along it.",
	"air": "AIR - the shell and the wake as one system: displaced air.",
	"acquire": "ACQUIRE - the ball takes its spin over ~0.15 s, not instantly.",
	"combined": "COMBINED - speed lines + air + spin + stretch + squash.",
}

const TRAIL_COLOR := Color(1.0, 0.94, 0.82)
const MAX_GHOSTS: int = 14
const GHOST_SPACING: float = 0.16

var _camera: Camera3D
var _ball_root: Node3D
var _deform: Node3D
var _spinner: Node3D
var _ball_mesh: MeshInstance3D
var _ghosts: Array[MeshInstance3D] = []
var _strokes: MeshInstance3D
var _stroke_mesh: ImmediateMesh
var _stroke_material: StandardMaterial3D
var _label: Label
var _caption: Label

var _history: Array[Vector3] = []
var _strands: Array = []
var _spin_angle: float = 0.0
var _power: float = 0.0
var _travelled: float = 0.0
var _anchor_time: float = -1.0
var _camera_focus: Vector3 = Vector3.ZERO
## A close, fixed camera on the contact point. The travelling shot is right for a
## trail and useless for a deformation: at 4.9 m the ball is 25 px and a squash
## is invisible, which is the whole reason this mode exists.
var _hold_on_contact: bool = false
var _focus: String = ""
var _zoom: float = 1.0
var _first_second: float = 0.0
var _last_second: float = -1.0
var _out_dir: String = ""
var _shot: String = "spike"
var _launch: Vector3 = Vector3.ZERO
var _flight_seconds: float = 0.0
var _first_impact: Vector3 = Vector3.ZERO


func _ready() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	_out_dir = str(args.get("out", "/tmp/ball-treatments"))
	_shot = str(args.get("shot", "spike"))
	if not SHOTS.has(_shot):
		push_error("unknown shot '%s'" % _shot)
		get_tree().quit(2)
		return
	_focus = str(args.get("focus", ""))
	_hold_on_contact = _focus in ["contact", "floor"]
	_zoom = float(args.get("zoom", "1.0"))
	_first_second = float(args.get("start", "0.0"))
	_last_second = float(args.get("end", "-1.0"))
	get_window().size = OUT_SIZE
	_solve_flight()
	_build_world()
	await get_tree().process_frame
	var only := str(args.get("only", "")).split(",", false)
	for treatment in TREATMENTS:
		if not only.is_empty() and not only.has(treatment):
			continue
		await _render_treatment(treatment)
	get_tree().quit()


## Where the ball goes after the hit, and for how long. Solved rather than
## authored so a shot's landing follows from its speed and angle instead of
## being placed by hand at a number that then disagrees with the arc.
func _solve_flight() -> void:
	var shot: Dictionary = SHOTS[_shot]
	var elevation := deg_to_rad(float(shot.elevation))
	var speed := float(shot.speed)
	_launch = Vector3(cos(elevation) * speed, sin(elevation) * speed, 0.0)
	var vy := _launch.y
	_flight_seconds = (vy + sqrt(
		vy * vy + 2.0 * GRAVITY * (CONTACT.y - BALL_RADIUS)
	)) / GRAVITY
	_first_impact = CONTACT + _launch * _flight_seconds \
		- Vector3.UP * 0.5 * GRAVITY * _flight_seconds * _flight_seconds
	_first_impact.y = BALL_RADIUS


func _total_seconds() -> float:
	return INCOMING_SECONDS + _flight_seconds + BOUNCE_SECONDS + HOLD_SECONDS


## Position and velocity at a moment, for the whole shot including the leg
## before the contact and the bounces after it. One function so a trail that
## samples the past and a trail that samples the future read the same flight.
##
## The ball used to stop dead at the landing point, which is what playback does
## today: `display_trajectory` runs contact-to-contact and there is no leg after
## the last one, so a ball reaching the floor neither bounces nor carries on.
## Drawn here because a squash and a spin have their most obvious moment at a
## floor impact and there was nothing for them to respond to.
func _state_at(t: float) -> Dictionary:
	if t < INCOMING_SECONDS:
		## The incoming set, solved backwards so it *arrives* at the contact.
		var span := INCOMING_SECONDS
		var v0 := (CONTACT - INCOMING_FROM) / span + Vector3.UP * 0.5 * GRAVITY * span
		return {
			"position": INCOMING_FROM + v0 * t - Vector3.UP * 0.5 * GRAVITY * t * t,
			"velocity": v0 - Vector3.UP * GRAVITY * t,
			"phase": "incoming", "bounces": 0, "last_impact": -1.0,
			## The ball acquired this velocity when it was launched, so that is
			## as far back as anything drawing its recent past may reach.
			"anchor": INCOMING_FROM, "anchor_time": 0.0,
			"impulse": Vector3.ZERO, "arriving": Vector3.ZERO,
		}
	var remaining := t - INCOMING_SECONDS
	var position := CONTACT
	var velocity := _launch
	var bounces := 0
	var last_impact := -1.0
	var anchor := CONTACT
	var anchor_time := INCOMING_SECONDS
	## The swing, as a change of velocity rather than as a new one. Newton's
	## third law is the whole content of the impact treatments: the axis the ball
	## deforms along and the size of the deformation are the direction and the
	## magnitude of this one vector.
	var impulse := _launch - _incoming_velocity()
	var arriving := _incoming_velocity()
	while true:
		## Time from here to the floor. Always positive: the ball is above it.
		## The floor for the ball's *centre* is one radius up, so the squash
		## fires when the surface touches rather than when the centre does.
		var fall := (velocity.y + sqrt(
			velocity.y * velocity.y
				+ 2.0 * GRAVITY * maxf(position.y - BALL_RADIUS, 0.0)
		)) / GRAVITY
		if bounces >= MAX_BOUNCES or fall <= 0.0001:
			## Rolling. Friction only, and it stays on the floor.
			position += Vector3(velocity.x, 0.0, velocity.z) * remaining
			velocity = Vector3(velocity.x, 0.0, velocity.z) \
				* maxf(1.0 - ROLL_DRAG * remaining, 0.0)
			position.y = BALL_RADIUS
			break
		if remaining < fall:
			position += velocity * remaining \
				- Vector3.UP * 0.5 * GRAVITY * remaining * remaining
			velocity -= Vector3.UP * GRAVITY * remaining
			break
		position += velocity * fall - Vector3.UP * 0.5 * GRAVITY * fall * fall
		velocity -= Vector3.UP * GRAVITY * fall
		remaining -= fall
		bounces += 1
		last_impact = t - remaining
		position.y = BALL_RADIUS
		## Every velocity discontinuity re-anchors: a bounce is an impact like
		## any other, so the trail starts again from here too.
		anchor = position
		anchor_time = last_impact
		arriving = velocity
		var before := velocity
		## A topspin ball grabs the floor and kicks forward off it: the spin is
		## spent buying horizontal speed, which is why a hard-driven ball skids
		## away low rather than sitting up.
		var topspin_kick := TOPSPIN_FLOOR_KICK \
			* float(SHOTS[_shot].spin_rps) / 16.0 \
			* pow(SPIN_LOSS_PER_BOUNCE, float(bounces - 1))
		velocity.y = -velocity.y * RESTITUTION
		velocity.x = velocity.x * FLOOR_KEEP + topspin_kick
		velocity.z = velocity.z * FLOOR_KEEP
		impulse = velocity - before
	return {
		"position": Vector3(position.x, maxf(position.y, BALL_RADIUS), position.z),
		"velocity": velocity,
		"phase": "outgoing" if bounces == 0 else "bouncing",
		"bounces": bounces, "last_impact": last_impact,
		"anchor": anchor, "anchor_time": anchor_time,
		"impulse": impulse, "arriving": arriving,
	}


## The ball's velocity as it reaches the hitter, which the swing's impulse is
## measured against. A swing is not "the outgoing velocity" -- a dig sends a ball
## back the way it came and the two differ by more than either of them.
func _incoming_velocity() -> Vector3:
	return (CONTACT - INCOMING_FROM) / INCOMING_SECONDS \
		- Vector3.UP * 0.5 * GRAVITY * INCOMING_SECONDS


# --- the scene -------------------------------------------------------------

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.051, 0.078, 0.125)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.48, 0.60)
	environment.ambient_light_energy = 0.85

	_camera = Camera3D.new()
	_camera.fov = 40.0
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	add_child(_camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	key.light_energy = 1.15
	add_child(key)

	_add_floor()
	_add_net()
	_add_ball()
	_add_trail_nodes()
	_add_overlay()


func _add_floor() -> void:
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(40.0, 24.0)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.14, 0.19)
	material.roughness = 0.95
	plane.material_override = material
	add_child(plane)
	## The camera holds the ball near the centre of frame, so the floor is the
	## only thing left that can say how fast it is going. Lines every two metres,
	## dim enough not to compete with a trail.
	for step in range(-9, 10):
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.01, 14.0)
		line.mesh = box
		line.position = Vector3(float(step) * 2.0, 0.006, 0.0)
		var line_material := StandardMaterial3D.new()
		line_material.albedo_color = Color(0.24, 0.31, 0.39)
		line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.material_override = line_material
		add_child(line)


func _add_net() -> void:
	var band := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 1.0, 2.4)
	band.mesh = box
	band.position = Vector3(0.0, 1.93, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.56, 0.66, 0.08)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band.material_override = material
	add_child(band)
	var tape := MeshInstance3D.new()
	var tape_box := BoxMesh.new()
	tape_box.size = Vector3(0.05, 0.07, 2.4)
	tape.mesh = tape_box
	tape.position = Vector3(0.0, 2.43, 0.0)
	var tape_material := StandardMaterial3D.new()
	tape_material.albedo_color = Color(0.52, 0.58, 0.66)
	tape_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tape.material_override = tape_material
	add_child(tape)


## The ball is three nested nodes on purpose. Deformation happens in the frame of
## the *flight* and rotation happens in the frame of the *ball*; nesting them
## keeps a squash from being spun around by the spin.
func _add_ball() -> void:
	_ball_root = Node3D.new()
	_deform = Node3D.new()
	_spinner = Node3D.new()
	_ball_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_ball_mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_texture = _panel_texture()
	material.roughness = 0.55
	_ball_mesh.material_override = material
	_spinner.add_child(_ball_mesh)
	_deform.add_child(_spinner)
	_ball_root.add_child(_deform)
	add_child(_ball_root)


## Panels, so rotation is visible at all. A plain sphere spinning is a still
## image -- which is the whole reason a spin treatment cannot be judged from one.
func _panel_texture() -> ImageTexture:
	var image := Image.create(256, 128, false, Image.FORMAT_RGB8)
	var palette := [
		Color(0.95, 0.95, 0.93), Color(0.98, 0.76, 0.16), Color(0.11, 0.36, 0.66)
	]
	for y in range(128):
		for x in range(256):
			var band := int(float(x) / 256.0 * 6.0) + int(float(y) / 128.0 * 4.0)
			image.set_pixel(x, y, palette[band % 3])
	return ImageTexture.create_from_image(image)


func _add_trail_nodes() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.115
	sphere.height = 0.23
	sphere.radial_segments = 12
	sphere.rings = 6
	for _index in range(MAX_GHOSTS):
		var ghost := MeshInstance3D.new()
		ghost.mesh = sphere
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.visible = false
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ghost.material_override = material
		add_child(ghost)
		_ghosts.append(ghost)

	_stroke_mesh = ImmediateMesh.new()
	_strokes = MeshInstance3D.new()
	_strokes.mesh = _stroke_mesh
	_stroke_material = StandardMaterial3D.new()
	_stroke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stroke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stroke_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_stroke_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_stroke_material.vertex_color_use_as_albedo = true
	_strokes.material_override = _stroke_material
	_strokes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_strokes)


func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(34, 26)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	layer.add_child(_label)
	_caption = Label.new()
	_caption.position = Vector2(34, 66)
	_caption.add_theme_font_size_override("font_size", 19)
	_caption.add_theme_color_override("font_color", Color(0.62, 0.71, 0.80))
	layer.add_child(_caption)


# --- rendering -------------------------------------------------------------

func _render_treatment(treatment: String) -> void:
	_history.clear()
	_spin_angle = 0.0
	_power = 0.0
	_travelled = 0.0
	_anchor_time = -1.0
	_reset_strands()
	_camera_focus = _opening_focus()
	_track_camera()
	for ghost in _ghosts:
		ghost.visible = false
	_stroke_mesh.clear_surfaces()
	_label.text = "%s  /  %s" % [treatment.to_upper(), _shot]
	_caption.text = str(CAPTIONS.get(treatment, ""))
	var directory := "%s/%s/%s" % [_out_dir, _shot, treatment]
	DirAccess.make_dir_recursive_absolute(directory)
	var last := _last_second if _last_second > 0.0 else _total_seconds()
	var first_frame := int(floor(_first_second / DT))
	var frames := int(ceil(last / DT))
	## The state is stepped from zero whatever the window is, because a trail is
	## a function of where the ball has already been -- starting the loop late
	## would draw a ball with no history behind it.
	var written := 0
	for frame in range(frames):
		_apply(treatment, float(frame) * DT)
		if frame < first_frame:
			continue
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/f_%04d.png" % [directory, written])
		written += 1
	print("rendered %s/%s %d frames" % [_shot, treatment, written])


func _apply(treatment: String, t: float) -> void:
	var state := _state_at(t)
	var position: Vector3 = state.position
	var velocity: Vector3 = state.velocity
	var speed := velocity.length()
	var since_contact := t - INCOMING_SECONDS
	_ball_root.position = position
	## Lagged rather than locked. A camera welded to the ball would hold it dead
	## centre and hide the one thing a speed treatment is trying to show.
	_camera_focus = _camera_focus.lerp(position, 0.16 if _hold_on_contact else 0.10)
	_track_camera()

	## **A trail may reach back to where the ball acquired this velocity, and no
	## further.** Speed still decides how long a streak wants to be; the anchor
	## decides how much of that it is allowed to have yet. The earlier version
	## capped it against a rolling window instead, which approximated this by
	## accident and needed a memory constant to do it -- the anchor is a physical
	## event and needs nothing. The growth time falls out as length over speed,
	## so a slow ball's trail also grows in slowly, which the window got wrong.
	_power = clampf(inverse_lerp(4.0, 20.0, speed), 0.0, 1.0)
	_travelled = position.distance_to(Vector3(state.anchor))
	## A trail that survives a contact says the ball was redirected. One that
	## dies at the contact and grows again says it was struck, which is the
	## distinction the whole exercise is about.
	if not is_equal_approx(_anchor_time, float(state.anchor_time)):
		_anchor_time = float(state.anchor_time)
		_history.clear()
		_reset_strands()

	_push_history(position)
	_push_strands(position, velocity)
	_spin_angle += _spin_rate(treatment, since_contact, int(state.bounces)) \
		* TAU * DT
	_apply_spin(treatment, velocity)
	## Everything about an impact now comes off one vector. Its direction is the
	## axis the ball deforms along and the shell expands about; its magnitude is
	## how deep the deformation goes and how big the shell gets.
	_apply_deform(treatment, position, state, t - float(state.anchor_time))

	for ghost in _ghosts:
		ghost.visible = false
	_stroke_mesh.clear_surfaces()
	match treatment:
		"history":
			_draw_history(0.0)
		"skew":
			_draw_history(1.0)
		"leading":
			_draw_leading(t)
		"speed_lines", "combined":
			_draw_strands()
		"wake":
			_draw_wake(position, velocity)
		"air":
			_draw_wake(position, velocity)
		"ribbon":
			_draw_ribbon(t)
	if treatment == "combined":
		_draw_wake(position, velocity)
	if treatment in ["stamp", "air", "combined"]:
		_draw_shell(state, t - float(state.anchor_time))


func _push_history(position: Vector3) -> void:
	if _history.is_empty() \
			or _history[-1].distance_to(position) > GHOST_SPACING:
		_history.append(position)
	while _history.size() > MAX_GHOSTS + 1:
		_history.pop_front()


## Faithful to `BallActor3D`: count and head width come from speed, the taper is
## the ghost's own place in the tail. `skew` is the same trail with a lateral
## offset that grows with age, which is what a curving ball leaves behind.
func _draw_history(skew: float) -> void:
	var power := _power
	var live := int(round(lerpf(2.0, float(MAX_GHOSTS), power)))
	var head_scale := lerpf(0.44, 0.86, power)
	var head_alpha := lerpf(0.26, 0.72, power)
	for index in range(_ghosts.size()):
		if index >= live:
			continue
		var history_index := _history.size() - 2 - index
		if history_index < 0:
			continue
		var ghost := _ghosts[index]
		var along := 1.0 - float(index + 1) / float(live + 1)
		var age := float(index + 1) / float(live + 1)
		ghost.visible = true
		ghost.global_position = _history[history_index] \
			+ Vector3(0.0, 0.0, 1.0) * skew * 0.55 * pow(age, 1.6)
		ghost.scale = Vector3.ONE * head_scale * lerpf(0.30, 1.0, along)
		var material := ghost.material_override as StandardMaterial3D
		material.albedo_color = Color(TRAIL_COLOR, head_alpha * along * along)


## Drawn ahead instead of behind, which is the whole argument about it: it is
## the only treatment that tells a viewer something before it happens.
func _draw_leading(t: float) -> void:
	var power := _power
	var live := int(round(lerpf(2.0, 10.0, power)))
	for index in range(live):
		var ahead := t + float(index + 1) * 0.022
		if ahead > INCOMING_SECONDS + _flight_seconds:
			continue
		var ghost := _ghosts[index]
		var fade := 1.0 - float(index) / float(live)
		ghost.visible = true
		ghost.global_position = Vector3(_state_at(ahead).position)
		ghost.scale = Vector3.ONE * lerpf(0.18, 0.62, fade)
		var material := ghost.material_override as StandardMaterial3D
		material.albedo_color = Color(TRAIL_COLOR, 0.50 * fade * fade)


## Speed lines, emitted into the court rather than parented to the ball.
##
## The first version hung nine strokes off the ball on a fixed ring, so they
## travelled with it and the only thing that ever changed was their length --
## which is why they read as a decoration that stretches rather than as motion.
## Animators do the opposite: a mark is made at a moment and left behind, and the
## object moves on out of it.
##
## Two things stop being authored as a result. The length is now the distance the
## ball covered in `STRAND_SECONDS`, so it scales with speed by itself and needs
## no cap; and because every point is somewhere the ball actually was, a strand
## *cannot* reach back before the contact. The anchor rule stops being a clamp
## and becomes a property of how the marks are made.
func _push_strands(position: Vector3, velocity: Vector3) -> void:
	if _strands.is_empty():
		_reset_strands()
	if velocity.length() < 0.5:
		for strand in _strands:
			strand.clear()
		return
	var direction := velocity.normalized()
	var side := direction.cross(_to_camera(position)).normalized()
	var up := side.cross(direction).normalized()
	var keep := maxi(int(round(STRAND_SECONDS / DT)), 2)
	for index in range(STRAND_COUNT):
		## A fixed angle and radius per strand, so the sheaf holds together frame
		## to frame instead of sparkling.
		var angle := TAU * float(index) / float(STRAND_COUNT) + 0.4
		var radius := lerpf(0.015, 0.115, fmod(float(index) * 0.37, 1.0))
		var strand: Array = _strands[index]
		strand.append(position + (side * cos(angle) + up * sin(angle)) * radius)
		while strand.size() > keep:
			strand.pop_front()


func _reset_strands() -> void:
	_strands.clear()
	for _index in range(STRAND_COUNT):
		_strands.append([])


func _draw_strands() -> void:
	var head_width := lerpf(0.005, 0.014, _power)
	var head_alpha := 0.62 * _power + 0.10
	_stroke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in _strands:
		var points: Array = strand
		if points.size() < 2:
			continue
		for index in range(points.size() - 1):
			var a: Vector3 = points[index]
			var b: Vector3 = points[index + 1]
			## Newest point is the head, so a strand tapers and fades backwards
			## from the ball into the court it was laid down in.
			var fa := float(index) / float(points.size() - 1)
			var fb := float(index + 1) / float(points.size() - 1)
			_add_taper(
				a, b, head_width * fa * fa, head_width * fb * fb,
				Color(TRAIL_COLOR, head_alpha * fa * fa * fa),
				Color(TRAIL_COLOR, head_alpha * fb * fb * fb)
			)
	_stroke_mesh.surface_end()


## A segment whose width differs at each end, so a chain of them is a smooth
## taper rather than a row of bars.
func _add_taper(
	a: Vector3, b: Vector3, half_a: float, half_b: float,
	colour_a: Color, colour_b: Color
) -> void:
	var along := b - a
	if along.length() < 0.00001:
		return
	var facing := _to_camera(a)
	var side := along.normalized().cross(facing).normalized()
	_add_quad(
		a + side * half_a, a - side * half_a,
		b - side * half_b, b + side * half_b,
		colour_a, colour_a, colour_b, colour_b
	)


## Air, not light. Wide, dim and colourless, so it can sit under a trail that is
## already carrying quality on hue without competing for the same channel.
func _draw_wake(position: Vector3, velocity: Vector3) -> void:
	var speed := velocity.length()
	if speed < 0.5:
		return
	var direction := velocity.normalized()
	var power := _power
	var length := minf(lerpf(0.3, 2.6, power), _travelled)
	var flare := lerpf(0.06, 0.42, power)
	var side := direction.cross(_to_camera(position)).normalized()
	_stroke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	for step in range(steps):
		var a := float(step) / float(steps)
		var b := float(step + 1) / float(steps)
		var pa := position - direction * (length * a)
		var pb := position - direction * (length * b)
		var wa := side * (BALL_RADIUS + flare * a)
		var wb := side * (BALL_RADIUS + flare * b)
		var ca := Color(0.80, 0.86, 0.94, 0.20 * power * (1.0 - a) * (1.0 - a))
		var cb := Color(0.80, 0.86, 0.94, 0.20 * power * (1.0 - b) * (1.0 - b))
		_add_quad(pa + wa, pa - wa, pb - wb, pb + wb, ca, ca, cb, cb)
	_stroke_mesh.surface_end()


## A band along the path whose half-width rotates about the tangent at the spin
## rate, so the ribbon goes edge-on and back twice a revolution. That flicker is
## the depiction: it is literally how fast the ball is turning.
func _draw_ribbon(t: float) -> void:
	var shot: Dictionary = SHOTS[_shot]
	var rate := float(shot.spin_rps) if t >= INCOMING_SECONDS else 2.0
	var samples := 22
	## Was 0.16 s at 0.16 m half-width -- a band three ball diameters across with
	## a hard edge on both sides, which read as a physical object rather than as
	## a ball turning. Narrower, shorter, and feathered to nothing at its edges.
	## Two passes to land this. At 0.16 m and 0.55 alpha it was an object; at
	## 0.062 and 0.30 the twist stopped being legible at all. The edge feathering
	## below is what actually removed the "structural" read, so the width and the
	## alpha can come most of the way back.
	var span := 0.115
	var half_width := 0.105
	_stroke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(samples - 1):
		var t_a := t - span * float(index) / float(samples)
		var t_b := t - span * float(index + 1) / float(samples)
		if t_b < 0.0:
			break
		var a := Vector3(_state_at(t_a).position)
		var b := Vector3(_state_at(t_b).position)
		var tangent := (a - b)
		if tangent.length() < 0.0001:
			continue
		tangent = tangent.normalized()
		var side := tangent.cross(_to_camera(a)).normalized()
		var up := side.cross(tangent).normalized()
		var phase_a := (t_a) * rate * TAU
		var phase_b := (t_b) * rate * TAU
		var wa := (side * cos(phase_a) + up * sin(phase_a)) * half_width
		var wb := (side * cos(phase_b) + up * sin(phase_b)) * half_width
		var fade_a := 1.0 - float(index) / float(samples)
		var fade_b := 1.0 - float(index + 1) / float(samples)
		var band := 0.55 + 0.45 * absf(cos(phase_a))
		var ca := Color(TRAIL_COLOR, 0.46 * fade_a * fade_a * band)
		var cb := Color(TRAIL_COLOR, 0.46 * fade_b * fade_b * band)
		var clear_a := Color(TRAIL_COLOR, 0.0)
		var clear_b := Color(TRAIL_COLOR, 0.0)
		## Two quads per segment, bright along the centre line and transparent at
		## both edges, so the band has no silhouette to read as an object.
		_add_quad(a - wa, a, b, b - wb, clear_a, ca, cb, clear_b)
		_add_quad(a, a + wa, b + wb, b, ca, clear_a, clear_b, cb)
	_stroke_mesh.surface_end()


## The air the contact threw outward, as a shell rather than a ring.
##
## The first version drew a flat ring perpendicular to the swing, which is where
## the physics puts it and which is edge-on from a side camera -- a shockwave
## drawn as a vertical line. Billboarding it fixed the silhouette and broke
## something worse: a disc that always faces the viewer reads as decal on the
## screen instead of as something in the room.
##
## A shell has no orientation to get wrong. It is flattened along the impulse,
## so it still says which way the force went, and because it is drawn additively
## the surface self-brightens where it runs edge-on to the camera -- the rim
## comes free rather than being drawn. It stays where it was made, so the ball
## departing is what makes it read as sweeping backwards.
func _draw_shell(state: Dictionary, since_event: float) -> void:
	var impulse: Vector3 = state.impulse
	if since_event < 0.0 or since_event > SHELL_SECONDS or impulse.length() < 0.5:
		return
	var strength := clampf(impulse.length() / IMPULSE_REFERENCE, 0.0, 1.0)
	var age := since_event / SHELL_SECONDS
	var origin: Vector3 = state.anchor
	var radius := lerpf(0.16, 0.30 + 0.62 * strength, sqrt(age))
	var alpha := (1.0 - age) * (1.0 - age) * 0.075 * (0.35 + 0.65 * strength)
	var axis := impulse.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var other := side.cross(axis).normalized()
	## A band around the equator rather than a closed surface. A full shell is
	## crossed twice by every ray and piles up at its poles, and additively that
	## is a solid grey egg -- the first attempt looked like a boulder. Fading the
	## band to nothing at both edges leaves an expanding ring with no rim to it.
	var rings := 6
	var segments := 24
	_stroke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(rings):
		var f0 := float(ring) / float(rings)
		var f1 := float(ring + 1) / float(rings)
		var v0 := lerpf(SHELL_BAND_MIN, SHELL_BAND_MAX, f0)
		var v1 := lerpf(SHELL_BAND_MIN, SHELL_BAND_MAX, f1)
		var a0 := Color(0.84, 0.90, 0.98, alpha * sin(PI * f0))
		var a1 := Color(0.84, 0.90, 0.98, alpha * sin(PI * f1))
		for segment in range(segments):
			var u0 := TAU * float(segment) / float(segments)
			var u1 := TAU * float(segment + 1) / float(segments)
			_add_quad(
				origin + _shell_point(axis, side, other, u0, v0, radius),
				origin + _shell_point(axis, side, other, u1, v0, radius),
				origin + _shell_point(axis, side, other, u1, v1, radius),
				origin + _shell_point(axis, side, other, u0, v1, radius),
				a0, a0, a1, a1
			)
	_stroke_mesh.surface_end()


## Flattened along the impulse, so the shell is a disc of air pushed out sideways
## from the blow rather than a bubble.
func _shell_point(
	axis: Vector3, side: Vector3, other: Vector3,
	u: float, v: float, radius: float
) -> Vector3:
	return (axis * cos(v) * SHELL_FLATTEN
		+ (side * cos(u) + other * sin(u)) * sin(v)) * radius


func _spin_rate(treatment: String, since_contact: float, bounces: int) -> float:
	var shot: Dictionary = SHOTS[_shot]
	## Each floor contact spends some of the rotation -- part into the forward
	## kick the bounce already takes, the rest into the floor.
	var outgoing := float(shot.spin_rps) \
		* pow(SPIN_LOSS_PER_BOUNCE, float(bounces))
	if treatment == "acquire":
		if since_contact < 0.0:
			return 1.5
		## The ball takes the spin over the contact rather than at it.
		return lerpf(1.5, outgoing, clampf(since_contact / 0.15, 0.0, 1.0))
	if treatment in ["spin", "combined", "ribbon"]:
		return 1.5 if since_contact < 0.0 else outgoing
	## Today's behaviour: a fixed axis at a rate keyed to speed, not to spin.
	return 0.0


func _apply_spin(treatment: String, velocity: Vector3) -> void:
	if treatment in ["spin", "acquire", "combined", "ribbon"]:
		var direction := velocity.normalized() if velocity.length() > 0.01 \
			else Vector3.RIGHT
		## `direction.cross(UP)` carries the *front* of the ball upward, which is
		## backspin. Topspin is the top of the ball moving the way the ball is
		## going, so the axis is the other one.
		var axis := Vector3.UP.cross(direction).normalized()
		_spinner.transform.basis = Basis(axis, _spin_angle)
		return
	## Everything else keeps the ball's current stand-in: a fixed local axis.
	_spinner.transform.basis = Basis(Vector3.RIGHT, _spin_angle)


## Deformation, from the impulse and nothing else.
##
## Every earlier version hard-coded an axis: the hit compressed along the
## outgoing velocity, the landing compressed along world up. Both are wrong in
## general and right by luck in the case they were written for -- a dig sends the
## ball back the way it came, so its outgoing velocity points nowhere near the
## direction the ball was actually struck. The axis is the change in velocity,
## which is the impulse, which is the direction the force was applied. One rule,
## and the floor and the hand stop being special cases of each other.
func _apply_deform(
	treatment: String, position: Vector3, state: Dictionary, since_event: float
) -> void:
	_ball_root.scale = Vector3.ONE
	_ball_root.position = position
	var long_scale := 1.0
	var perp_scale := 1.0
	var impulse: Vector3 = state.impulse
	var squashing := treatment in ["squash", "combined"] \
		and since_event >= 0.0 and since_event < SQUASH_SECONDS \
		and impulse.length() > 0.5
	var axis := impulse.normalized() if impulse.length() > 0.001 else Vector3.UP
	var amplitude := 0.0
	if squashing:
		## Damped and *oscillating*: the overshoot is what makes it read as a
		## material with a skin on it rather than as a scale glitch. Depth comes
		## from the same vector as the axis, so a soft touch barely moves.
		var swing := cos(TAU * SQUASH_HZ * since_event)
		## Damped and *oscillating*, but not evenly: the rebound past round is a
		## fraction of the compression into it.
		if swing < 0.0:
			swing *= SQUASH_REBOUND
		amplitude = MAX_SQUASH \
			* clampf(impulse.length() / IMPULSE_REFERENCE, 0.0, 1.0) \
			* exp(-since_event / SQUASH_DECAY) * swing
		long_scale *= 1.0 - amplitude
		perp_scale *= 1.0 + amplitude * 0.5
	if treatment in ["stretch", "combined"]:
		var velocity: Vector3 = state.velocity
		var power := clampf(inverse_lerp(4.0, 20.0, velocity.length()), 0.0, 1.0)
		## Stretch runs along the flight, not along the blow, so it needs its own
		## frame -- it is the only deformation here that is not an impact.
		_apply_stretch(velocity, power)
	if not squashing or is_equal_approx(amplitude, 0.0):
		if not treatment in ["stretch", "combined"]:
			_deform.transform.basis = Basis.IDENTITY
		return
	## **The contact point stays where it is and the centre moves.** Scaling about
	## the centre lifts a flattening ball off the floor it is flattening against,
	## which is most of why it read as a scaled sphere rather than as a ball
	## hitting something.
	_ball_root.position = position - axis * BALL_RADIUS * amplitude
	## The ball is also sliding along the surface while it is being compressed, so
	## the contact patch smears. Pure axial compression is the cartoon version.
	var arriving: Vector3 = state.arriving
	var tangent := arriving - axis * arriving.dot(axis)
	var shear := 0.0
	var tangent_direction := Vector3.ZERO
	if tangent.length() > 0.01:
		tangent_direction = tangent.normalized()
		shear = -SHEAR_GAIN * amplitude \
			* clampf(tangent.length() / IMPULSE_REFERENCE, 0.0, 1.0)
	else:
		tangent_direction = axis.cross(Vector3.RIGHT).normalized() \
			if absf(axis.dot(Vector3.RIGHT)) < 0.99 \
			else axis.cross(Vector3.UP).normalized()
	var third := axis.cross(tangent_direction).normalized()
	var frame := Basis(axis, tangent_direction, third)
	var local := Basis(
		Vector3(long_scale, shear, 0.0),
		Vector3(0.0, perp_scale, 0.0),
		Vector3(0.0, 0.0, perp_scale),
	)
	_deform.transform.basis = frame * local * frame.transposed()


func _apply_stretch(velocity: Vector3, power: float) -> void:
	var long_scale := lerpf(1.0, 1.55, power)
	var perp_scale := lerpf(1.0, 0.82, power)
	var direction := velocity.normalized() if velocity.length() > 0.01 \
		else Vector3.RIGHT
	var side := direction.cross(Vector3.UP).normalized()
	var up := side.cross(direction).normalized()
	var frame := Basis(direction, up, side)
	_deform.transform.basis = frame \
		* Basis.from_scale(Vector3(long_scale, perp_scale, perp_scale)) \
		* frame.transposed()


# --- drawing helpers -------------------------------------------------------

## Where the camera starts. A landing shot has to open on the floor rather than
## on the ball, or the first bounce happens before the camera has caught up.
func _opening_focus() -> Vector3:
	match _focus:
		"contact":
			return CONTACT
		"floor":
			return _first_impact + Vector3.UP * 0.45
		_:
			return Vector3(_state_at(0.0).position)


func _track_camera() -> void:
	var eye := _camera_focus + Vector3(0.0, 0.75, 4.9) * _zoom
	_camera.look_at_from_position(eye, _camera_focus, Vector3.UP)


func _to_camera(from: Vector3) -> Vector3:
	return (_camera.global_position - from).normalized()


## A stroke that comes to a point at both ends, rather than a rectangle.
##
## The first draft drew each speed line as a constant-width quad, which put a
## square cap at full alpha immediately beside the ball -- the corners are what
## made them read as solid bars instead of as motion.
func _add_spindle(
	head: Vector3, tail: Vector3, half_width: float, peak: Color
) -> void:
	var direction := head - tail
	if direction.length() < 0.0001:
		return
	var side := direction.normalized().cross(_to_camera(head)).normalized() \
		* half_width
	## The widest point sits a quarter of the way back, so the stroke is dense
	## near the ball and draws out to nothing behind it.
	var waist := head.lerp(tail, 0.25)
	var clear := Color(peak, 0.0)
	_add_tri(head, waist + side, waist - side, clear, peak, peak)
	_add_tri(tail, waist - side, waist + side, clear, peak, peak)


func _add_tri(
	a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color
) -> void:
	for entry in [[a, ca], [b, cb], [c, cc]]:
		_stroke_mesh.surface_set_color(entry[1])
		_stroke_mesh.surface_add_vertex(entry[0])


func _add_quad(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	ca: Color, cb: Color, cc: Color, cd: Color
) -> void:
	for entry in [[a, ca], [b, cb], [c, cc], [a, ca], [c, cc], [d, cd]]:
		_stroke_mesh.surface_set_color(entry[1])
		_stroke_mesh.surface_add_vertex(entry[0])


func _parse(raw: PackedStringArray) -> Dictionary:
	var parsed := {}
	for entry in raw:
		var pair := str(entry).split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
