class_name UIWhiteboard
extends Control

## The tactic board: a different medium again, and deliberately so.
##
## The journal is cloth and paper somebody sewed. The clipboard is paper somebody
## drew on. This is the third thing on the desk -- **a board somebody wiped and
## drew on again**, which is what a coach actually explains a phase with. The
## match centre's tactical court draws the same information as clean geometry,
## and clean geometry is the one register this interface does not use anywhere
## else; a plan explained in exact 1px lines reads as a diagram produced by a
## machine, not as something a young coach scrawled between sessions.
##
## Three things separate a marker from the pen `UIInkOutline` draws:
##
## 1. **The tip is a chisel, not a nib.** Same structural idea -- width depends on
##    the direction of travel relative to the tip's angle -- but blunt at both
##    ends rather than tapered, because a marker is set down and lifted rather
##    than swept.
## 2. **The ink is translucent.** Where two strokes cross, the crossing is
##    darker. That single property is most of what makes a drawing read as
##    marker rather than as line art, and it comes free from drawing at alpha
##    below one instead of being simulated.
## 3. **The board remembers.** A wipe never takes everything, so the previous
##    layout stays as a faint smear under the new one. This is also where the
##    phase change lives: choosing a phase squeegees the board and redraws, and
##    the ghost is the evidence that something was there before.
##
## Deterministic and seeded, for the same reason the pen is: a wobble redrawn
## differently every frame is a shimmer, and a wobble shared by every stroke is a
## texture rather than a hand.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal phase_changed(phase: String)
signal zone_priority_changed(zone_index: int, priority: int)

## The phases a coach explains one at a time. Ordered the way a rally travels,
## which is the same order the drill ring used and for the same reason.
const PHASES: Array[String] = ["Serve Receive", "Attack", "Block", "Floor"]

## The chisel. `MARKER_ANGLE_DEGREES` is how the tip is held; a stroke travelling
## across it comes out at full width and one travelling along it comes out at
## `MARKER_MIN_RATIO` of that. Wider than the pen's nib because a marker is,
## and because the width ratio needs somewhere to show.
const MARKER_WIDTH: float = 7.0
const MARKER_MIN_RATIO: float = 0.34
const MARKER_ANGLE_DEGREES: float = 31.0
## Translucent, so crossings darken. Below about 0.55 the strokes stop reading as
## a single confident line and start looking like a wash.
const MARKER_ALPHA: float = 0.72
## How far a hand strays over a run, and how long each drawn segment is.
const MARKER_WANDER: float = 1.15
const MARKER_SEGMENT: float = 9.0

## What a wipe leaves behind. Low, and lower than it first read: at 0.085 with
## the alpha bug above in play the previous heading was still legible under the
## new one and the board said "BLOCK RECEIVE".
const GHOST_ALPHA: float = 0.055

## Marker red. Not the palette's `danger`, which is tuned to mean "this is
## wrong" in a UI -- this one means "look here", which is what a coach's second
## pen is for. Warmer and less saturated than an alert red so it can sit next to
## black on a board without shouting.
const MARKER_RED := Color(0.78, 0.20, 0.16)

## The zone-priority bars. Four zones, each 0 to 3, scrolled to change.
const ZONE_COUNT: int = 4
const ZONE_MAX_PRIORITY: int = 3
const ZONE_LABELS: Array[String] = ["Line", "Seam", "Cross", "Tip"]

var phase: String = "Block"
var zone_priorities: Array[int] = [3, 2, 1, 2]
var light_mode: bool = true

## The layout being wiped away, and how far the squeegee has got. Nothing is
## drawn from these except the ghost; the board does not animate two live
## layouts at once, because a coach does not either.
var _ghost_phase: String = ""
var _wipe: float = 1.0
var _wipe_tween: Tween = null
var _hovered_zone: int = -1
var _seed: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	## The board paints itself from the palette, so it has to be told which
	## theme is up. `UIStyleSystem.apply` walks the tree on every switch but only
	## restyles nodes it recognises, and a hand-painted exempt node is not one --
	## so the board reads the theme off its own ancestry instead, the same way
	## `UIBackdrop` does, and refreshes when the tree tells it to.
	theme_changed.connect(_sync_theme)
	_sync_theme()
	## Painted by hand end to end. The style pass would give the board a drawn
	## paper edge and a halftone wash, which is the wrong material -- a board is
	## smooth, and its edge is a tray rather than a torn sheet.
	set_meta("ui_style_exempt", true)
	custom_minimum_size = Vector2(420.0, 300.0)
	_seed = int(String(name).hash() & 0x7FFFFFFF)
	resized.connect(queue_redraw)


func set_light_mode(value: bool) -> void:
	light_mode = value
	queue_redraw()


func _sync_theme() -> void:
	light_mode = UIPalette.control_is_light(self)
	queue_redraw()


## Choose a phase: squeegee what is there, then draw the new one.
func set_phase(value: String) -> void:
	if value == phase or not value in PHASES:
		return
	_ghost_phase = phase
	phase = value
	phase_changed.emit(phase)
	if _wipe_tween != null and _wipe_tween.is_valid():
		_wipe_tween.kill()
	_wipe = 0.0
	_wipe_tween = create_tween()
	_wipe_tween.tween_method(_set_wipe, 0.0, 1.0, 0.34)
	_wipe_tween.set_ease(Tween.EASE_OUT)
	_wipe_tween.set_trans(Tween.TRANS_CUBIC)


func _set_wipe(value: float) -> void:
	_wipe = value
	queue_redraw()


## Scrolling over a bar changes that zone's priority.
##
## The control the planner had for this was an `OptionButton` reading "P2 ·
## Seam", which is the value written out as text -- three clicks and a menu to
## change a number whose whole meaning is how it compares to the other three.
## Four bars answer that at a glance, and a wheel changes one without leaving it.
func _gui_input(event: InputEvent) -> void:
	if phase != "Block":
		return
	if event is InputEventMouseMotion:
		var was := _hovered_zone
		_hovered_zone = _zone_at((event as InputEventMouseMotion).position)
		if was != _hovered_zone:
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	var index := _zone_at(button.position)
	if index < 0:
		return
	var step := 0
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = 1
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = -1
	if step == 0:
		return
	zone_priorities[index] = clampi(
		zone_priorities[index] + step, 0, ZONE_MAX_PRIORITY
	)
	zone_priority_changed.emit(index, zone_priorities[index])
	accept_event()
	queue_redraw()


func _exit_tree() -> void:
	if _wipe_tween != null and _wipe_tween.is_valid():
		_wipe_tween.kill()


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	## Read at draw time rather than trusted from a signal.
	##
	## `theme_changed` is connected and does fire, but the first draft trusted it
	## alone and the board rendered dark inside Molten -- one lookup that was
	## stale by a frame, on the one node whose entire surface is a colour. A
	## theme colour lookup per redraw is nothing next to a few hundred strokes,
	## and it cannot be out of date.
	light_mode = UIPalette.control_is_light(self)
	var board := _board_color()
	draw_rect(Rect2(Vector2.ZERO, size), board)
	_draw_board_wear(board)

	## The previous layout, still faintly there. Fades as the squeegee passes.
	if not _ghost_phase.is_empty() and _wipe < 1.0:
		_draw_phase(_ghost_phase, GHOST_ALPHA * (1.0 - _wipe) + GHOST_ALPHA)
	elif not _ghost_phase.is_empty():
		_draw_phase(_ghost_phase, GHOST_ALPHA)


	## And the new one, drawn in behind the squeegee rather than appearing whole.
	_draw_phase(phase, 1.0, _wipe)
	if _wipe < 1.0:
		_draw_squeegee(_wipe)
	_draw_tray()


## The board is not a flat fill. Years of markers leave a directional haze and a
## few strokes that never came off at all.
func _draw_board_wear(board: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	## Faint, and much fainter than the first draft. At half opacity these read as
	## horizontal banding -- a rendering artefact rather than a used surface --
	## because a hard-edged full-width rectangle is not what a wipe leaves. What
	## sells wear is that the eye cannot quite resolve it.
	var haze := board.darkened(0.028) if light_mode else board.lightened(0.030)
	for index in range(14):
		var y := size.y * rng.randf()
		var height := size.y * rng.randf_range(0.04, 0.16)
		var inset := size.x * rng.randf_range(0.0, 0.22)
		draw_rect(
			Rect2(inset, y, size.x - inset * rng.randf_range(1.0, 2.0), height),
			Color(haze, 0.55)
		)
	## The corner nobody reaches, permanently a little cleaner.
	draw_rect(
		Rect2(0.0, size.y * 0.80, size.x * 0.12, size.y * 0.14),
		Color(board.lightened(0.06) if light_mode else board.darkened(0.10), 0.4)
	)


## The aluminium lip along the bottom, and the two markers lying in it. This is
## the one part of the board that is an object rather than a surface, and it is
## what stops the panel reading as a blank rectangle when a phase is empty.
func _draw_tray() -> void:
	var tray_height := 13.0
	var top := size.y - tray_height
	var metal := Color(0.62, 0.63, 0.66) if light_mode else Color(0.30, 0.32, 0.36)
	draw_rect(Rect2(0.0, top, size.x, tray_height), metal)
	draw_line(
		Vector2(0.0, top), Vector2(size.x, top), Color(metal.darkened(0.30), 0.9), 1.0
	)
	## Black on the left, red beside it, both a little rolled from where they
	## were dropped.
	var barrel := 46.0
	for entry in [[24.0, _ink()], [24.0 + barrel + 9.0, MARKER_RED]]:
		var x: float = entry[0]
		var color: Color = entry[1]
		draw_rect(Rect2(x, top + 3.0, barrel, 6.0), color)
		draw_rect(Rect2(x + barrel, top + 4.2, 7.0, 3.6), Color(color, 0.55))


## The squeegee itself: a felt bar with a bright leading edge, travelling left to
## right. Everything behind it is board; everything in front is the old layout.
func _draw_squeegee(progress: float) -> void:
	var x := size.x * progress
	var felt := Color(0.24, 0.26, 0.30) if light_mode else Color(0.72, 0.74, 0.78)
	draw_rect(Rect2(x - 9.0, 0.0, 9.0, size.y - 13.0), Color(felt, 0.85))
	draw_line(
		Vector2(x, 0.0), Vector2(x, size.y - 13.0),
		Color(_board_color().lightened(0.35) if light_mode else _board_color().lightened(0.12), 0.9),
		2.0
	)


func _draw_phase(which: String, alpha: float, reveal: float = 1.0) -> void:
	match which:
		"Block":
			_draw_block_phase(alpha, reveal)
		"Serve Receive":
			_draw_receive_phase(alpha, reveal)
		"Attack":
			_draw_attack_phase(alpha, reveal)
		_:
			_draw_floor_phase(alpha, reveal)


## The block phase, drawn the way an illustrator draws blockers at a net: a
## three-quarter view from slightly above, which is roughly the broadcast angle
## lifted a little.
##
## Was a flat elevation, straight on. That is the honest engineering view and it
## is the wrong one here -- straight on, two blockers at different depths sit at
## exactly the same height on the page, so the one thing the picture exists to
## show (who is where along the net, and how the seam between them opens) is the
## one thing it flattens. A slight rotation and a slight lift give the net a
## receding edge, and the moment the net recedes the blockers have positions
## along it.
##
## Projection is deliberately not a camera. `_net_point` is an axonometric map --
## along the net, up, and across it -- with no perspective divide, because a
## marker drawing does not have a focal length and a vanishing point would make
## the board look rendered rather than drawn.
## Screen y grows downward, which is the trap: written as `+ u * skew` the right
## antenna sank instead of rising and the net read as a fence falling over. The
## right-hand end of a net seen from the left and slightly above is *further
## away*, so it sits higher on the page and a little shorter.
const NET_SKEW: float = 0.13
## Where the far side of the net lands relative to the near side: up, and back to
## the left. No perspective divide -- a marker drawing has no focal length, and a
## vanishing point would make the board look rendered rather than drawn.
const NET_DEPTH := Vector2(-30.0, -22.0)


## u runs along the net (0 left antenna, 1 right), v is height (0 floor, 1 tape
## top), w is depth across the net (0 near side, 1 far).
func _net_point(origin: Vector2, span: Vector2, u: float, v: float, w: float) -> Vector2:
	return origin + Vector2(
		u * span.x + w * NET_DEPTH.x,
		-v * span.y - u * span.x * NET_SKEW + w * NET_DEPTH.y
	)


func _draw_block_phase(alpha: float, reveal: float) -> void:
	var ink := _ink()
	var board_bottom := size.y - 13.0
	var origin := Vector2(size.x * 0.11, board_bottom - size.y * 0.10)
	var span := Vector2(size.x * 0.44, size.y * 0.34)

	_marker_text("BLOCK", Vector2(size.x * 0.06, size.y * 0.15), 26, ink, alpha, reveal)

	## The two tapes, top and bottom. Both slant, which is what makes the net
	## recede rather than face the reader.
	var tape_top_left := _net_point(origin, span, 0.0, 1.0, 0.0)
	var tape_top_right := _net_point(origin, span, 1.0, 1.0, 0.0)
	var tape_low_left := _net_point(origin, span, 0.0, 0.46, 0.0)
	var tape_low_right := _net_point(origin, span, 1.0, 0.46, 0.0)
	_marker_line(tape_top_left, tape_top_right, ink, alpha, reveal, 11, MARKER_WIDTH * 1.05)
	_marker_line(tape_low_left, tape_low_right, ink, alpha, reveal, 23, MARKER_WIDTH * 0.75)

	## The mesh. Thin and faint -- what a net is, visually, is two heavy tapes
	## with almost nothing between them -- and the verticals stay vertical in
	## world terms, so they lean with the projection.
	var columns := 11
	for index in range(columns + 1):
		var u := float(index) / float(columns)
		_marker_line(
			_net_point(origin, span, u, 1.0, 0.0),
			_net_point(origin, span, u, 0.46, 0.0),
			Color(ink, 0.26), alpha, reveal, 40 + index, MARKER_WIDTH * 0.22
		)
	for index in range(1, 3):
		var v := lerpf(0.46, 1.0, float(index) / 3.0)
		_marker_line(
			_net_point(origin, span, 0.0, v, 0.0),
			_net_point(origin, span, 1.0, v, 0.0),
			Color(ink, 0.20), alpha, reveal, 60 + index, MARKER_WIDTH * 0.20
		)

	## Antennae, in red, because they are the boundary the phase is about. They
	## stand vertically in the world, so on the page they are the only strictly
	## vertical lines in the drawing -- which is exactly how they read on a court.
	for entry in [[0.0, 71], [1.0, 79]]:
		var u: float = entry[0]
		var salt: int = entry[1]
		_marker_line(
			_net_point(origin, span, u, 1.34, 0.0),
			_net_point(origin, span, u, 0.40, 0.0),
			MARKER_RED, alpha, reveal, salt, MARKER_WIDTH * 0.85
		)

	## Two blockers on the far side, reaching over. Depth is what the projection
	## bought: a blocker at w = 1 sits up and left of one at the same u on the
	## near side, so the wall reads as being beyond the net rather than on it.
	var blockers := [0.30, 0.52]
	for index in range(blockers.size()):
		var u: float = blockers[index]
		var salt := 90 + index * 29
		var head := _net_point(origin, span, u, 1.15, 0.55)
		var radius := 15.0
		## The arms as **one arch**, hand to hand over the head, because that is
		## one gesture and an illustrator draws it without lifting. Two separate
		## arm strokes came out as sticks flying off a figure that was not there.
		var arch := PackedVector2Array()
		var steps := 16
		for step in range(steps + 1):
			var t := float(step) / float(steps)
			var angle := lerpf(PI * 0.92, PI * 0.08, t)
			arch.append(
				head + Vector2(cos(angle), -sin(angle)) * Vector2(radius * 1.85, radius * 1.55)
			)
		_marker_stroke(arch, ink, alpha, reveal, salt + 5, MARKER_WIDTH * 0.85, false)
		## The head sits inside the arch, and the shoulders hang off its foot.
		_marker_circle(head, radius, ink, alpha, reveal, salt)
		_marker_line(
			head + Vector2(0.0, radius * 0.9),
			_net_point(origin, span, u, 0.62, 0.55),
			ink, alpha, reveal, salt + 3, MARKER_WIDTH * 0.75
		)
		_marker_text(
			"%d" % (index + 1), head + Vector2(-6.0, -radius * 1.9),
			16, MARKER_RED, alpha, reveal
		)

	## The seam between them, circled the way somebody circles the thing they
	## want you to look at.
	var seam_u: float = (float(blockers[0]) + float(blockers[1])) * 0.5
	var seam := _net_point(origin, span, seam_u, 1.17, 0.48)
	_marker_ellipse(seam, Vector2(44.0, 38.0), MARKER_RED, alpha * 0.9, reveal, 137)

	_draw_zone_bars(
		Rect2(size.x * 0.68, size.y * 0.40, size.x * 0.27, board_bottom - size.y * 0.54),
		alpha, reveal
	)


## The priority bars. Black for the level, red for the one being pointed at, and
## a hand-ruled baseline under all four.
func _draw_zone_bars(area: Rect2, alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"PRIORITY", area.position + Vector2(0.0, -8.0), 15, ink, alpha, reveal
	)
	var slot := area.size.x / float(ZONE_COUNT)
	var bar_width := slot * 0.66
	var baseline := area.position.y + area.size.y
	for index in range(ZONE_COUNT):
		var centre := area.position.x + slot * (float(index) + 0.5)
		var level := zone_priorities[index]
		var height := area.size.y * (float(level) / float(ZONE_MAX_PRIORITY))
		var color := MARKER_RED if index == _hovered_zone else ink
		## Filled by hatching rather than by a solid rectangle. A marker fills a
		## shape by going back and forth across it, and the overlaps at the turns
		## are visible -- which is exactly what the translucent ink gives for free.
		## Hatched at roughly half the tip's width so the passes overlap. At a 7px
		## pitch with a full-width tip they read as the rungs of a ladder instead
		## of as a filled box -- a marker filling a shape leaves visible turns,
		## not gaps.
		var pitch := 3.4
		var steps := maxi(int(height / pitch), 1)
		for step in range(steps):
			var y := baseline - float(step) * pitch - 2.0
			if y < baseline - height:
				break
			_marker_line(
				Vector2(centre - bar_width * 0.5, y),
				Vector2(centre + bar_width * 0.5, y),
				Color(color, 0.55), alpha, reveal, 200 + index * 17 + step,
				MARKER_WIDTH * 0.62
			)
		## The outline of the box it was filled into, drawn after, so it reads as
		## the shape rather than as the edge of the hatching.
		if level > 0:
			_marker_rect(
				Rect2(
					centre - bar_width * 0.5, baseline - height,
					bar_width, height
				), color, alpha * 0.85, reveal, 300 + index
			)
		_marker_text(
			ZONE_LABELS[index], Vector2(centre - bar_width * 0.5, baseline + 15.0),
			12, color, alpha, reveal
		)
	_marker_line(
		Vector2(area.position.x - 6.0, baseline),
		Vector2(area.position.x + area.size.x + 6.0, baseline),
		ink, alpha, reveal, 399, 13
	)


func _draw_receive_phase(alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"SERVE RECEIVE", Vector2(size.x * 0.08, size.y * 0.16), 26, ink, alpha, reveal
	)
	## A half court in plan, because reception is a floor-shape problem.
	var court := Rect2(size.x * 0.10, size.y * 0.24, size.x * 0.46, size.y * 0.54)
	_marker_rect(court, ink, alpha, reveal, 11)
	_marker_line(
		court.position + Vector2(0.0, court.size.y * 0.34),
		court.position + Vector2(court.size.x, court.size.y * 0.34),
		Color(ink, 0.55), alpha * 0.7, reveal, 27
	)
	for spot in [Vector2(0.22, 0.68), Vector2(0.50, 0.80), Vector2(0.78, 0.66)]:
		_marker_circle(
			court.position + court.size * spot, 10.0, ink, alpha, reveal,
			41 + int(spot.x * 100.0)
		)
	_marker_text(
		"seam", court.position + court.size * Vector2(0.30, 0.44), 13,
		MARKER_RED, alpha, reveal
	)
	_marker_ellipse(
		court.position + court.size * Vector2(0.36, 0.72), Vector2(56.0, 30.0),
		MARKER_RED, alpha * 0.9, reveal, 63
	)


func _draw_attack_phase(alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"ATTACK", Vector2(size.x * 0.08, size.y * 0.16), 26, ink, alpha, reveal
	)
	var net_y := size.y * 0.34
	_marker_line(
		Vector2(size.x * 0.08, net_y), Vector2(size.x * 0.72, net_y), ink, alpha, reveal, 7, 11
	)
	var setter := Vector2(size.x * 0.44, size.y * 0.52)
	_marker_circle(setter, 11.0, ink, alpha, reveal, 19)
	_marker_text("S", setter + Vector2(-5.0, 5.0), 14, ink, alpha, reveal)
	for target in [Vector2(size.x * 0.15, size.y * 0.42), Vector2(size.x * 0.66, size.y * 0.44)]:
		_marker_arrow(setter, target, MARKER_RED, alpha, reveal, 31 + int(target.x))


func _draw_floor_phase(alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"FLOOR", Vector2(size.x * 0.08, size.y * 0.16), 26, ink, alpha, reveal
	)
	var court := Rect2(size.x * 0.10, size.y * 0.26, size.x * 0.52, size.y * 0.50)
	_marker_rect(court, ink, alpha, reveal, 5)
	for spot in [Vector2(0.18, 0.26), Vector2(0.50, 0.20), Vector2(0.82, 0.28),
			Vector2(0.22, 0.76), Vector2(0.78, 0.74)]:
		_marker_circle(
			court.position + court.size * spot, 9.0, ink, alpha, reveal,
			51 + int(spot.x * 90.0 + spot.y * 13.0)
		)
	_marker_text(
		"cover", court.position + court.size * Vector2(0.42, 0.52), 13,
		MARKER_RED, alpha, reveal
	)


# --------------------------------------------------------------------------
# The marker itself
# --------------------------------------------------------------------------

## One stroke, chisel-tipped and translucent.
##
## `reveal` is how much of the board the squeegee has uncovered; a stroke past
## that point has not been drawn yet, and one that straddles it is drawn as far
## as the squeegee has got. That is what makes the new layout appear *behind* the
## wipe rather than all at once when it finishes.
func _marker_line(
	from: Vector2, to: Vector2, color: Color, alpha: float,
	reveal: float, salt: int, width: float = MARKER_WIDTH
) -> void:
	_marker_stroke(
		_wandering_path(from, to, salt), color, alpha, reveal, salt, width, false
	)


## A run the hand did not lift for.
##
## The first draft drew every stroke as a chain of short `draw_line` calls with
## an independent offset per segment. Two things came out of that and both were
## wrong. The joins between segments overlap, and since the ink is translucent
## *every join darkened* -- so a plain straight line was a row of dark ticks, and
## the overlap that is supposed to mean "two strokes crossed here" meant nothing
## because it was everywhere. And an independent offset per segment is white
## noise, which reads as a shaky hand rather than a fast one.
##
## So a stroke is now one polygon: a ribbon built along a centreline, filled in a
## single `draw_colored_polygon`. It cannot overlap itself, so a crossing is the
## only thing that darkens. The centreline wanders on two slow sine components
## rather than per-point noise, which bends the run instead of shaking it, and
## the width drifts slowly along it on a third -- the hand leaning in and easing
## off over a run it never lifted from.
func _wandering_path(from: Vector2, to: Vector2, salt: int) -> PackedVector2Array:
	var path := PackedVector2Array()
	var length := from.distance_to(to)
	if length < 0.001:
		return path
	var normal := (to - from).orthogonal().normalized()
	var steps := clampi(int(length / MARKER_SEGMENT), 3, 48)
	## Two components, seeded: one long bow across the whole run and one shorter
	## correction. A hand drawing a straight line produces exactly this -- it
	## leaves true, notices, and comes back.
	var phase_a := _unit(salt * 31 + 3) * TAU
	var phase_b := _unit(salt * 31 + 9) * TAU
	var amplitude := MARKER_WANDER * (0.55 + _unit(salt * 31 + 17) * 0.75)
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var bow := sin(phase_a + t * PI) * 0.75 + sin(phase_b + t * TAU * 1.7) * 0.25
		## Both ends settle onto true: a hand starts and finishes where it meant
		## to even when the middle of the run drifts.
		path.append(from.lerp(to, t) + normal * bow * amplitude * sin(t * PI))
	return path


## Fill a centreline as one continuous chisel-tipped ribbon.
##
## Emitted as a quad per segment rather than as one polygon down the whole run.
## The single-polygon form works for an open stroke and silently fails for a
## closed one: left-side-forward plus right-side-backward round a circle is a
## *ring*, which is not a simple polygon, and Godot's triangulator drops it --
## which is why a blocker's head vanished while their arms drew fine.
##
## Adjacent quads share an edge exactly, so the run still does not darken against
## itself; where a path genuinely crosses its own tail, the two quads there do
## overlap and it darkens, which is the lap that says a circle was thrown round
## something in a hurry.
func _marker_stroke(
	path: PackedVector2Array, color: Color, alpha: float, reveal: float,
	salt: int, width: float, _closed: bool
) -> void:
	if alpha <= 0.001 or path.size() < 2:
		return
	var limit := size.x * reveal
	var ink := Color(color, color.a * MARKER_ALPHA * alpha)
	var count := path.size()
	var pressure_phase := _unit(salt * 47 + 5) * TAU
	var previous_left := Vector2.ZERO
	var previous_right := Vector2.ZERO
	var have_previous := false
	for index in range(count):
		var point := path[index]
		if point.x > limit:
			break
		var ahead := path[mini(index + 1, count - 1)]
		var behind := path[maxi(index - 1, 0)]
		var direction := ahead - behind
		if direction.length_squared() < 0.000001:
			direction = Vector2.RIGHT
		var normal := direction.orthogonal().normalized()
		## Pressure: a slow drift along the run, never a step. The hand leaning
		## in and easing off over something it never lifted from.
		var t := float(index) / float(count - 1)
		var pressure := 1.0 + sin(pressure_phase + t * TAU * 0.8) * 0.16
		var half := _tip_width(direction, width) * 0.5 * pressure
		var left := point + normal * half
		var right := point - normal * half
		if have_previous:
			draw_colored_polygon(
				PackedVector2Array([previous_left, left, right, previous_right]), ink
			)
		previous_left = left
		previous_right = right
		have_previous = true


## A stable 0-1 from the board's seed and a salt. Hand-mixed rather than an rng
## object, because these are read a few thousand times a frame.
func _unit(step: int) -> float:
	var accumulated := (_seed * 2654435761) ^ (step * 40503)
	accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 13)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 65537) / 65537.0


## The chisel: full width across the tip, `MARKER_MIN_RATIO` of it along.
func _tip_width(direction: Vector2, width: float) -> float:
	if direction.length_squared() < 0.0001:
		return width
	var tip := Vector2.RIGHT.rotated(deg_to_rad(MARKER_ANGLE_DEGREES))
	var across := absf(direction.normalized().cross(tip))
	return width * lerpf(MARKER_MIN_RATIO, 1.0, across)


func _marker_rect(
	rect: Rect2, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	var a := rect.position
	var b := rect.position + Vector2(rect.size.x, 0.0)
	var c := rect.position + rect.size
	var d := rect.position + Vector2(0.0, rect.size.y)
	## Overshot corners. A hand drawing a box does not stop exactly on the
	## corner, and the little crossings at four corners are most of what says
	## somebody drew this quickly.
	_marker_line(a + Vector2(-3.0, 0.0), b + Vector2(4.0, 0.0), color, alpha, reveal, salt)
	_marker_line(b + Vector2(0.0, -3.0), c + Vector2(0.0, 4.0), color, alpha, reveal, salt + 1)
	_marker_line(c + Vector2(3.0, 0.0), d + Vector2(-4.0, 0.0), color, alpha, reveal, salt + 2)
	_marker_line(d + Vector2(0.0, 3.0), a + Vector2(0.0, -4.0), color, alpha, reveal, salt + 3)


func _marker_circle(
	centre: Vector2, radius: float, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	_marker_ellipse(centre, Vector2(radius, radius), color, alpha, reveal, salt)


## One lap of the pen, drawn as a single ribbon.
##
## Was a run of separate chords, which meant fifteen overlapping joins round
## every circle and a ring of dark ticks. The overshoot past its own start is
## kept -- that lap over the beginning is the entire tell of a circle thrown
## round something quickly -- but now it is the one place the shape crosses
## itself, so it is the one place that darkens.
func _marker_ellipse(
	centre: Vector2, radii: Vector2, color: Color, alpha: float,
	reveal: float, salt: int
) -> void:
	var segments := 40
	var start := _unit(salt * 13 + 1) * TAU
	var sweep := TAU + 0.25 + _unit(salt * 13 + 7) * 0.30
	## A hand-thrown circle is never round and never axis-aligned.
	var tilt := (_unit(salt * 13 + 21) - 0.5) * 0.5
	var squash := 0.92 + _unit(salt * 13 + 33) * 0.16
	var path := PackedVector2Array()
	for index in range(segments + 1):
		var angle := start + sweep * float(index) / float(segments)
		var local := Vector2(cos(angle), sin(angle) * squash) * radii
		path.append(centre + local.rotated(tilt))
	_marker_stroke(
		path, color, alpha, reveal, salt, MARKER_WIDTH * 0.80, true
	)


func _marker_arrow(
	from: Vector2, to: Vector2, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	_marker_line(from, to, color, alpha, reveal, salt)
	var back := (from - to).normalized()
	for turn in [0.45, -0.45]:
		_marker_line(
			to, to + back.rotated(turn) * 17.0, color, alpha, reveal,
			salt + int(turn * 100.0), MARKER_WIDTH * 0.85
		)


## Marker writing. The heading face is already a fat rounded display -- which is
## what a chisel tip produces -- so the board writes in it rather than in the
## body face, and tilts it a degree or two off true.
func _marker_text(
	text: String, at: Vector2, font_size: int, color: Color,
	alpha: float, reveal: float
) -> void:
	if alpha <= 0.001 or at.x > size.x * reveal:
		return
	var font := _marker_font()
	if font == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + int(text.hash() & 0xFFFF)
	draw_set_transform(at, rng.randf_range(-0.028, 0.028))
	## Writing takes a boost over stroke work, because a letterform at marker
	## alpha loses its counters and turns to mush -- but only when it is *live*.
	## Boosting a ghost too left the previous phase's heading legible under the
	## new one, so the board read "BLOCK RECEIVE".
	var written := MARKER_ALPHA * alpha
	if alpha > 0.5:
		written = clampf(written + 0.18, 0.0, 1.0)
	draw_string(
		font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, Color(color, color.a * written)
	)
	draw_set_transform(Vector2.ZERO, 0.0)


func _marker_font() -> Font:
	## `DisplayHeading` is the Cherry Bomb face -- fat, rounded, no thin strokes
	## anywhere, which is what a chisel tip physically cannot produce either. It
	## was chosen as a display face and happens to be the closest thing in the
	## project to marker writing, so the board borrows it rather than shipping a
	## font for one screen.
	var theme_font := get_theme_font(&"font", &"DisplayHeading")
	if theme_font != null:
		return theme_font
	return get_theme_default_font()


func _board_color() -> Color:
	## A whiteboard is not the page. In Molten it is a cooler, flatter white than
	## the paper around it -- that difference is the whole point, since two
	## surfaces the same colour are one surface. In Mikasa it is a dark board,
	## because a lit white rectangle would be the brightest thing in the room and
	## the theme is a room at night.
	return Color(0.93, 0.94, 0.95) if light_mode else Color(0.13, 0.15, 0.18)


func _ink() -> Color:
	## The dark marker. Black on a white board; on a dark board the same pen
	## cannot be seen, so the roles swap and the "black" marker is the pale one.
	## Red stays red in both, which is why it carries the emphasis.
	return Color(0.11, 0.12, 0.14) if light_mode else Color(0.88, 0.90, 0.93)


func _zone_at(at: Vector2) -> int:
	var area := Rect2(
		size.x * 0.68, size.y * 0.40, size.x * 0.27, size.y - 13.0 - size.y * 0.54
	)
	if not area.grow(10.0).has_point(at):
		return -1
	var slot := area.size.x / float(ZONE_COUNT)
	return clampi(int((at.x - area.position.x) / slot), 0, ZONE_COUNT - 1)
