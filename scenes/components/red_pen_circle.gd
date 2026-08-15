class_name UIRedPenCircle
extends Control

## The clipboard's hover indicator: something circled in red, badly, in a hurry.
##
## The journal highlights what the cursor is over, because a highlighter is what
## you reach for when you are reading your own notes back. The clipboard is a
## different act -- it is marked up *while something is happening*, and what you
## do to a clipboard in a hurry is circle the thing you mean and move on. So the
## same job gets a different instrument, which is the same argument that gives the
## journal cloth and the tactic board a marker.
##
## Two properties do most of the work:
##
## - **It overshoots.** A circle drawn fast closes past where it started, and the
##   little crossing where the stroke laps itself is the entire tell. A closed
##   ellipse reads as a shape; an overshot one reads as a gesture.
## - **It is drawn, not revealed.** The stroke sweeps on over ~0.16 s, so the
##   hand is visible doing it. Fading a finished circle in would be a circle
##   appearing, which is not a thing a pen does.
##
## Seeded from the control it belongs to, so a given row is always circled the
## same way and no two rows are circled identically -- the same rule the pen and
## the marker follow.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## How long the hand takes to get round.
const DRAW_SECONDS: float = 0.16
const RELEASE_SECONDS: float = 0.12

## How far past its own start the stroke carries. A tenth of a turn is enough to
## read as a lap without looking like a second circle.
const OVERSHOOT_TURNS: float = 0.14

const SEGMENTS: int = 22
const STROKE_WIDTH: float = 2.6
const WANDER: float = 2.4
## How much wider than the thing it circles. A circle drawn tight around a label
## looks like a border; the point is that it was thrown around it.
const MARGIN: Vector2 = Vector2(9.0, 5.0)
## Ballpoint red, which is a colder red than a marker's -- different pen, and the
## two should not be the same colour when both are on screen.
const PEN_RED := Color(0.72, 0.14, 0.19)

var progress: float = 0.0
var _seed: int = 0
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parent := get_parent() as Control
	if parent != null:
		_seed = int(String(parent.name).hash() & 0x7FFFFFFF)
		parent.mouse_entered.connect(_circle)
		parent.mouse_exited.connect(_release)
		parent.resized.connect(queue_redraw)
	visible = false


func _circle() -> void:
	visible = true
	_start_tween(1.0, DRAW_SECONDS)


func _release() -> void:
	_start_tween(0.0, RELEASE_SECONDS)


func _start_tween(to: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_progress, progress, to, seconds)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)


func _set_progress(value: float) -> void:
	progress = value
	if is_zero_approx(progress):
		visible = false
	queue_redraw()


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _draw() -> void:
	if progress <= 0.001 or size.x < 12.0:
		return
	var centre := size * 0.5
	var radii := size * 0.5 + MARGIN
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var start := rng.randf_range(0.0, TAU)
	var sweep := (TAU + TAU * OVERSHOOT_TURNS) * clampf(progress, 0.0, 1.0)
	var drawn := maxi(int(SEGMENTS * clampf(progress, 0.0, 1.0)), 1)
	var previous := _at(centre, radii, start, rng, 0)
	for index in range(1, drawn + 1):
		var angle := start + sweep * float(index) / float(drawn)
		var point := _at(centre, radii, angle, rng, index)
		## Thinner as the hand accelerates round the run and heavier where it
		## started, which is where the nib was set down.
		var weight := STROKE_WIDTH * lerpf(1.25, 0.80, float(index) / float(SEGMENTS))
		draw_line(previous, point, Color(PEN_RED, 0.90), weight, true)
		previous = point


func _at(
	centre: Vector2, radii: Vector2, angle: float,
	rng: RandomNumberGenerator, index: int
) -> Vector2:
	## Deterministic per index rather than per call, so re-drawing the same
	## partial circle every frame does not reshuffle the wobble underneath it.
	var local := RandomNumberGenerator.new()
	local.seed = _seed + index * 2749
	var stray := Vector2(
		local.randf_range(-WANDER, WANDER), local.randf_range(-WANDER, WANDER)
	)
	return centre + Vector2(cos(angle), sin(angle)) * radii + stray
