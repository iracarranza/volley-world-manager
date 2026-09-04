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
	"spin", "stretch", "squash", "stamp", "acquire", "combined",
]

const CAPTIONS := {
	"blank": "BLANK - no trail at all. The floor everything else reads against.",
	"history": "HISTORY - ghosts along the path already travelled. Today's trail.",
	"speed_lines": "SPEED LINES - strokes along velocity. No path memory.",
	"wake": "WAKE - displaced air behind the ball. Costs no colour.",
	"ribbon": "RIBBON - a band twisting at the spin rate. Rotation, depicted.",
	"skew": "SKEW - the trail peeled to one side. Sidespin, before it kicks.",
	"leading": "LEADING - drawn ahead of the ball, not behind it.",
	"spin": "TRUE SPIN - rotation about a real axis at a real rate.",
	"stretch": "STRETCH - elongated along velocity. Physically false, reads fast.",
	"squash": "SQUASH - flattened at the hit, overshooting back. Impact.",
	"stamp": "STAMP - a ring thrown off the contact. Punctuation, not a trail.",
	"acquire": "ACQUIRE - the ball takes its spin over ~0.15 s, not instantly.",
	"combined": "COMBINED - speed lines + spin + stretch + squash + stamp.",
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
var _spin_angle: float = 0.0
var _camera_focus: Vector3 = Vector3.ZERO
var _out_dir: String = ""
var _shot: String = "spike"
var _launch: Vector3 = Vector3.ZERO
var _flight_seconds: float = 0.0


func _ready() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	_out_dir = str(args.get("out", "/tmp/ball-treatments"))
	_shot = str(args.get("shot", "spike"))
	if not SHOTS.has(_shot):
		push_error("unknown shot '%s'" % _shot)
		get_tree().quit(2)
		return
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
	_flight_seconds = (vy + sqrt(vy * vy + 2.0 * GRAVITY * CONTACT.y)) / GRAVITY


func _total_seconds() -> float:
	return INCOMING_SECONDS + _flight_seconds + HOLD_SECONDS


## Position and velocity at a moment, for the whole shot including the leg
## before the contact. One function so a trail that samples the past and a trail
## that samples the future are reading the same flight.
func _state_at(t: float) -> Dictionary:
	if t < INCOMING_SECONDS:
		## The incoming set, solved backwards so it *arrives* at the contact.
		var span := INCOMING_SECONDS
		var v0 := (CONTACT - INCOMING_FROM) / span + Vector3.UP * 0.5 * GRAVITY * span
		return {
			"position": INCOMING_FROM + v0 * t - Vector3.UP * 0.5 * GRAVITY * t * t,
			"velocity": v0 - Vector3.UP * GRAVITY * t,
			"phase": "incoming",
		}
	var f := minf(t - INCOMING_SECONDS, _flight_seconds)
	var landed := (t - INCOMING_SECONDS) > _flight_seconds
	return {
		"position": CONTACT + _launch * f - Vector3.UP * 0.5 * GRAVITY * f * f,
		"velocity": Vector3.ZERO if landed else _launch - Vector3.UP * GRAVITY * f,
		"phase": "landed" if landed else "outgoing",
	}


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
	_camera_focus = Vector3(_state_at(0.0).position)
	_track_camera()
	for ghost in _ghosts:
		ghost.visible = false
	_stroke_mesh.clear_surfaces()
	_label.text = "%s  /  %s" % [treatment.to_upper(), _shot]
	_caption.text = str(CAPTIONS.get(treatment, ""))
	var directory := "%s/%s/%s" % [_out_dir, _shot, treatment]
	DirAccess.make_dir_recursive_absolute(directory)
	var frames := int(ceil(_total_seconds() / DT))
	for frame in range(frames):
		_apply(treatment, float(frame) * DT)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/f_%04d.png" % [directory, frame])
	print("rendered %s/%s %d frames" % [_shot, treatment, frames])


func _apply(treatment: String, t: float) -> void:
	var state := _state_at(t)
	var position: Vector3 = state.position
	var velocity: Vector3 = state.velocity
	var speed := velocity.length()
	var since_contact := t - INCOMING_SECONDS
	_ball_root.position = position
	## Lagged rather than locked. A camera welded to the ball would hold it dead
	## centre and hide the one thing a speed treatment is trying to show.
	_camera_focus = _camera_focus.lerp(position, 0.10)
	_track_camera()

	_push_history(position)
	_spin_angle += _spin_rate(treatment, since_contact) * TAU * DT
	_apply_spin(treatment, velocity)
	_apply_deform(treatment, velocity, since_contact)

	for ghost in _ghosts:
		ghost.visible = false
	_stroke_mesh.clear_surfaces()
	match treatment:
		"history", "spin", "stretch", "squash", "stamp", "acquire":
			if treatment == "history":
				_draw_history(speed, 0.0)
		"skew":
			_draw_history(speed, 1.0)
		"leading":
			_draw_leading(t, speed)
		"speed_lines", "combined":
			_draw_speed_lines(position, velocity)
		"wake":
			_draw_wake(position, velocity)
		"ribbon":
			_draw_ribbon(t)
	if treatment in ["stamp", "combined"]:
		_draw_stamp(since_contact)


func _push_history(position: Vector3) -> void:
	if _history.is_empty() \
			or _history[-1].distance_to(position) > GHOST_SPACING:
		_history.append(position)
	while _history.size() > MAX_GHOSTS + 1:
		_history.pop_front()


## Faithful to `BallActor3D`: count and head width come from speed, the taper is
## the ghost's own place in the tail. `skew` is the same trail with a lateral
## offset that grows with age, which is what a curving ball leaves behind.
func _draw_history(speed: float, skew: float) -> void:
	var power := clampf(inverse_lerp(4.0, 20.0, speed), 0.0, 1.0)
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
func _draw_leading(t: float, speed: float) -> void:
	var power := clampf(inverse_lerp(4.0, 20.0, speed), 0.0, 1.0)
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


func _draw_speed_lines(position: Vector3, velocity: Vector3) -> void:
	var speed := velocity.length()
	if speed < 0.5:
		return
	var direction := velocity.normalized()
	var power := clampf(inverse_lerp(4.0, 20.0, speed), 0.0, 1.0)
	var length := lerpf(0.18, 1.55, power)
	var side := direction.cross(_to_camera(position)).normalized()
	var up := side.cross(direction).normalized()
	_stroke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	## Nine strokes on a fixed ring, so the pattern is stable frame to frame
	## rather than sparkling -- a randomised offset per frame reads as noise.
	for index in range(9):
		var angle := TAU * float(index) / 9.0
		var radial := (side * cos(angle) + up * sin(angle)) \
			* lerpf(0.02, 0.15, fmod(float(index) * 0.37, 1.0))
		var gap := lerpf(0.05, 0.18, fmod(float(index) * 0.61, 1.0))
		var tail_length := length * lerpf(0.55, 1.0, fmod(float(index) * 0.29, 1.0))
		var head := position + radial - direction * gap
		var tail := head - direction * tail_length
		_add_stroke(
			head, tail, lerpf(0.010, 0.024, power),
			Color(TRAIL_COLOR, 0.72 * power + 0.12), Color(TRAIL_COLOR, 0.0)
		)
	_stroke_mesh.surface_end()


## Air, not light. Wide, dim and colourless, so it can sit under a trail that is
## already carrying quality on hue without competing for the same channel.
func _draw_wake(position: Vector3, velocity: Vector3) -> void:
	var speed := velocity.length()
	if speed < 0.5:
		return
	var direction := velocity.normalized()
	var power := clampf(inverse_lerp(4.0, 20.0, speed), 0.0, 1.0)
	var length := lerpf(0.3, 2.6, power)
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
	var span := 0.16
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
		var wa := (side * cos(phase_a) + up * sin(phase_a)) * 0.16
		var wb := (side * cos(phase_b) + up * sin(phase_b)) * 0.16
		var fade_a := 1.0 - float(index) / float(samples)
		var fade_b := 1.0 - float(index + 1) / float(samples)
		var band := 0.45 + 0.55 * absf(cos(phase_a))
		var ca := Color(TRAIL_COLOR, 0.55 * fade_a * fade_a * band)
		var cb := Color(TRAIL_COLOR, 0.55 * fade_b * fade_b * band)
		_add_quad(a + wa, a - wa, b - wb, b + wb, ca, ca, cb, cb)
	_stroke_mesh.surface_end()


## A ring thrown off the hit, in the plane the hand struck through. It lives for
## a fifth of a second and is gone -- punctuation, not a trail.
func _draw_stamp(since_contact: float) -> void:
	if since_contact < 0.0 or since_contact > 0.24:
		return
	var age := since_contact / 0.24
	var radius := lerpf(0.12, 1.15, sqrt(age))
	var alpha := (1.0 - age) * (1.0 - age) * 0.85
	## Billboarded rather than held in the plane the hand struck through. The
	## physical ring is perpendicular to the swing, and from a side-on camera
	## that is edge-on -- a shockwave drawn as a vertical line.
	var facing := _to_camera(CONTACT)
	var side := facing.cross(Vector3.UP).normalized()
	var up := side.cross(facing).normalized()
	_stroke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 40
	var thickness := lerpf(0.10, 0.02, age)
	for segment in range(segments):
		var a := TAU * float(segment) / float(segments)
		var b := TAU * float(segment + 1) / float(segments)
		var ra := side * cos(a) + up * sin(a)
		var rb := side * cos(b) + up * sin(b)
		var colour := Color(1.0, 0.93, 0.78, alpha)
		var fade := Color(1.0, 0.93, 0.78, 0.0)
		_add_quad(
			CONTACT + ra * (radius - thickness), CONTACT + ra * (radius + thickness),
			CONTACT + rb * (radius + thickness), CONTACT + rb * (radius - thickness),
			fade, colour, colour, fade
		)
	_stroke_mesh.surface_end()


func _spin_rate(treatment: String, since_contact: float) -> float:
	var shot: Dictionary = SHOTS[_shot]
	var outgoing := float(shot.spin_rps)
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
		## Topspin turns about the horizontal axis across the flight, which is
		## the axis a viewer can actually see turning from side on.
		var axis := direction.cross(Vector3.UP).normalized()
		_spinner.transform.basis = Basis(axis, _spin_angle)
		return
	## Everything else keeps the ball's current stand-in: a fixed local axis.
	_spinner.transform.basis = Basis(Vector3.RIGHT, _spin_angle)


func _apply_deform(treatment: String, velocity: Vector3, since_contact: float) -> void:
	var long_scale := 1.0
	var perp_scale := 1.0
	if treatment in ["stretch", "combined"]:
		var power := clampf(inverse_lerp(4.0, 20.0, velocity.length()), 0.0, 1.0)
		long_scale *= lerpf(1.0, 1.55, power)
		perp_scale *= lerpf(1.0, 0.82, power)
	if treatment in ["squash", "combined"] and since_contact >= 0.0:
		## Damped and *oscillating*: the overshoot is what makes it read as a
		## material with a skin on it rather than as a scale glitch.
		var amplitude := 0.42 * exp(-since_contact / 0.085) \
			* cos(TAU * 9.0 * since_contact)
		long_scale *= 1.0 - amplitude
		perp_scale *= 1.0 + amplitude * 0.5
	if is_equal_approx(long_scale, 1.0) and is_equal_approx(perp_scale, 1.0):
		_deform.transform.basis = Basis.IDENTITY
		return
	var direction := velocity.normalized() if velocity.length() > 0.01 \
		else Vector3.RIGHT
	var side := direction.cross(Vector3.UP).normalized()
	var up := side.cross(direction).normalized()
	var frame := Basis(direction, up, side)
	_deform.transform.basis = frame \
		* Basis.from_scale(Vector3(long_scale, perp_scale, perp_scale)) \
		* frame.transposed()


# --- drawing helpers -------------------------------------------------------

func _track_camera() -> void:
	var eye := _camera_focus + Vector3(0.0, 0.75, 4.9)
	_camera.look_at_from_position(eye, _camera_focus, Vector3.UP)


func _to_camera(from: Vector3) -> Vector3:
	return (_camera.global_position - from).normalized()


func _add_stroke(
	head: Vector3, tail: Vector3, half_width: float,
	head_color: Color, tail_color: Color
) -> void:
	var direction := (head - tail)
	if direction.length() < 0.0001:
		return
	var side := direction.normalized().cross(_to_camera(head)).normalized() \
		* half_width
	_add_quad(
		head + side, head - side, tail - side, tail + side,
		head_color, head_color, tail_color, tail_color
	)


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
