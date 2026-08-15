class_name CallIntrusion
extends Control

## The phone ringing, drawn as a comic panel cutting into the corner.
##
## ## Why not a notification
##
## The journal is asynchronous: *this exists now, deal with it when you like*. A
## phone is not that. A phone is somebody deciding, on their own initiative, that
## your attention is theirs for a minute, and the interface has to carry that or
## the whole feature collapses back into a second inbox with a bell on it.
##
## A toast in the corner reading "New phone call" would be exactly that collapse.
## It is the game politely informing you; what is wanted is the game being
## *interrupted*. So this is drawn as a panel from another page shoved in over the
## top-right corner of whatever you were doing -- a hard black border, a torn
## inner edge, and a sound effect rendered as lettering, because that is the
## comic-book grammar for "something has broken into this scene".
##
## ## The rule that matters more than any of that
##
## **It never takes focus and it never fires during a held pointer.**
##
## The concrete failure: the phone rings while you are dragging a nozzle across
## the block, or a voli across the whiteboard. A modal that grabs focus eats the
## button-up, and the drag either never ends or ends somewhere you did not put it
## -- and it happens at random, days apart, in whichever screen the player happened
## to be using. That is a bug nobody ever reproduces.
##
## So: this is a `MOUSE_FILTER_PASS` decoration that happens to be clickable in
## its own rect. There is no scrim, nothing underneath it is disabled, and
## `ring()` refuses while a mouse button is down -- the call waits for the hand to
## come up, which costs the design nothing because a caller waiting three more
## seconds is a caller waiting three more seconds.
##
## ## Answering is a choice, and so is not answering
##
## There is no dismiss button, because dismissing is not a thing you do to a
## ringing phone -- you let it ring. The panel gives up after `RING_SECONDS` and
## the call goes to the machine, which is a different and lesser thing rather than
## a penalty. `docs/design/THE_DESK_AND_THE_PHONE.md` §7.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## Answered, or let go. Both are emitted; the caller decides what each costs.
signal answered
signal missed

## How long the phone rings before it gives up. Six seconds is about four rings,
## which is long enough to be a decision and short enough that ignoring it is not
## a waiting game.
const RING_SECONDS: float = 6.0

## The panel's size and where it cuts in from.
const PANEL := Vector2(300.0, 150.0)
const MARGIN: float = 18.0

## The border. Comic panels are ruled in one heavy weight and this is that weight
## -- thin enough to be a line, thick enough that it is obviously not the
## interface's own hairline.
const BORDER: float = 4.0
const TEAR_STEPS: int = 9
const TEAR_DEPTH: float = 7.0

## The shake. A ringing phone is drawn moving, and the amount is small on purpose:
## a panel that visibly bounces is a cartoon, and a panel that trembles is a
## telephone.
const SHAKE_PIXELS: float = 2.2
const SHAKE_HZ: float = 9.0

## Ring, pause, ring. A telephone is not a continuous alarm and the gap is what
## makes it read as one rather than as an error state.
const RING_CYCLE: float = 1.4
const RING_LOUD: float = 0.55

var _elapsed: float = 0.0
var _caller: String = ""
var _line: String = ""
var _known: bool = true


static func build() -> CallIntrusion:
	var panel := CallIntrusion.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	## **Pass, not stop.** The screen underneath keeps every click that does not
	## land on the panel itself, which is the whole of the no-modal rule.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.set_meta("ui_style_exempt", true)
	return panel


## Start ringing. Returns false if now is not the moment.
##
## `who` may be empty, which is a caller the club cannot identify -- a real state
## rather than a placeholder, and one that should get more common the further from
## home the call comes from.
func ring(who: String, line: String, known: bool = true) -> bool:
	## The held-pointer guard, and the reason it is here rather than at the call
	## site: every future caller would have to remember it, and the one that
	## forgets produces a bug that surfaces once a week in a different screen.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false
	_caller = who
	_line = line
	_known = known
	_elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()
	return true


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= RING_SECONDS:
		_stop()
		missed.emit()
		return
	queue_redraw()


func _stop() -> void:
	visible = false
	set_process(false)


func _panel_rect() -> Rect2:
	return Rect2(
		Vector2(size.x - PANEL.x - MARGIN, MARGIN), PANEL
	)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if not _panel_rect().has_point((event as InputEventMouseButton).position):
			## Deliberately not accepted. A click anywhere else belongs to the
			## screen underneath, and swallowing it here is how a decoration
			## becomes a modal by accident.
			return
		_stop()
		answered.emit()
		accept_event()


## Whether the phone is loud this instant. Drives the shake and the lettering's
## weight together, so the panel jumps *on* the ring rather than continuously.
func _loud() -> float:
	var phase := fmod(_elapsed, RING_CYCLE) / RING_CYCLE
	if phase > RING_LOUD:
		return 0.0
	return sin(phase / RING_LOUD * PI)


func _draw() -> void:
	if not visible:
		return
	var light := UIPalette.control_is_light(self)
	var loud := _loud()
	var shake := Vector2(
		sin(_elapsed * TAU * SHAKE_HZ), cos(_elapsed * TAU * SHAKE_HZ * 0.7)
	) * SHAKE_PIXELS * loud
	var rect := _panel_rect()
	rect.position += shake

	## The panel drops a hard shadow onto the screen it is covering, which is what
	## says it is *over* the interface rather than part of it.
	draw_rect(Rect2(rect.position + Vector2(5.0, 6.0), rect.size), Color(0, 0, 0, 0.35), true)

	var ink := Color(0.08, 0.08, 0.09)
	var stock := Color(0.98, 0.95, 0.86) if light else Color(0.90, 0.87, 0.78)
	draw_colored_polygon(_torn(rect), stock)
	draw_polyline(_torn(rect) + PackedVector2Array([_torn(rect)[0]]), ink, BORDER)

	var font := get_theme_default_font()
	if font == null:
		return
	## The sound, as lettering. Bigger on the loud half of the cycle, because in a
	## comic the word *is* the sound and a quiet ring is a smaller word.
	var shout := "RRRING!!" if loud > 0.35 else "rring..."
	draw_string(
		font, rect.position + Vector2(20.0, 46.0), shout,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0,
		int(lerpf(24.0, 34.0, loud)), ink
	)
	_draw_handset(rect.position + Vector2(rect.size.x - 52.0, 34.0), ink, loud)

	## Who it is, when the club knows. An unidentified caller is left unidentified
	## rather than labelled "Unknown" in the same slot -- the absence is the
	## information, and a word there would fill the gap it is supposed to leave.
	var who := _caller if _known and not _caller.is_empty() else "· · ·"
	draw_string(
		font, rect.position + Vector2(20.0, 80.0), who,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0, 16, ink
	)
	if not _line.is_empty():
		draw_string(
			font, rect.position + Vector2(20.0, 102.0), _line,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0, 11, Color(ink, 0.72)
		)
	## How long is left, as the border draining rather than as a countdown. A
	## number would make not answering a timing puzzle.
	var left := 1.0 - clampf(_elapsed / RING_SECONDS, 0.0, 1.0)
	draw_line(
		rect.position + Vector2(BORDER, rect.size.y - BORDER),
		rect.position + Vector2(BORDER + (rect.size.x - BORDER * 2.0) * left, rect.size.y - BORDER),
		Color("d94f42"), BORDER
	)


## The panel's outline: three straight sides and one torn one.
##
## The left edge is torn because that is the edge facing the interface it has cut
## into -- the panel has been ripped out of somewhere else and shoved in here, and
## the tear is on the side where it met the page it interrupted.
func _torn(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
	])
	for step in range(TEAR_STEPS + 1):
		var t := 1.0 - float(step) / float(TEAR_STEPS)
		## Deterministic off the step index, so the tear is the same tear every
		## ring. A tear that re-randomises per frame is a panel dissolving.
		var jag := float((step * 2654435761) % 1000) / 1000.0
		points.append(Vector2(
			rect.position.x - (jag - 0.5) * TEAR_DEPTH,
			rect.position.y + rect.size.y * t
		))
	return points


func _draw_handset(at: Vector2, ink: Color, loud: float) -> void:
	## A handset off the hook, tilted with the ring. Two ear-pieces and the bar
	## between them, which is the whole of what a telephone looks like as a glyph.
	var tilt := deg_to_rad(-18.0 + loud * 10.0)
	draw_set_transform(at, tilt, Vector2.ONE)
	draw_rect(Rect2(Vector2(-16.0, -4.0), Vector2(32.0, 8.0)), ink, true)
	for side in [-1.0, 1.0]:
		draw_rect(
			Rect2(Vector2(side * 16.0 - (7.0 if side > 0.0 else 0.0), -11.0), Vector2(7.0, 22.0)),
			ink, true
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
