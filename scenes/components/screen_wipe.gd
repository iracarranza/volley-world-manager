class_name ScreenWipe
extends Control

## A sheet of paper pulled across the screen between one place and the next.
##
## Every screen change in this game was instantaneous -- `_show_only` toggled
## `visible` on four Controls and the new one simply existed. That is not a bug,
## but it is the one place a management game can say "you have gone somewhere"
## without spending a word on it, and it was empty.
##
## The wipe is a sheet rather than a fade because the whole interface is a
## journal: pages get laid over each other, they do not dissolve. It travels with
## a slight lead edge and a shadow so it reads as something with a thickness
## being moved, and the swap happens under cover at the moment the sheet is
## across, so the outgoing screen is never seen mid-teardown.

## How long the sheet takes to cover, and to leave again.
##
## Covering is quicker than uncovering: arriving somewhere should feel decisive
## and the reveal is what the player actually wants to look at, so the second
## half lingers slightly.
const COVER_SECONDS: float = 0.20
const REVEAL_SECONDS: float = 0.28

## How long the sheet sits still, fully across, before it leaves.
##
## Without this the swap was visible under the sheet, and the cause was not the
## timing but the geometry: the sheet was exactly one screen wide, so it covered
## the screen for a single instant and the reveal began on the very next frame.
## The incoming screen got one frame to lay itself out, and a Godot container
## does not finish laying out in one frame -- so the trailing edge uncovered a
## page that was still settling.
##
## A hold is the cheaper half of the fix. Roughly seven frames at 60Hz, which is
## enough for the incoming screen's containers to resolve and short enough that
## it reads as the sheet being set down rather than as a pause.
const HOLD_SECONDS: float = 0.12

## How much wider than the screen the sheet is drawn.
##
## The other half of the fix. At exactly 1.0 there is no position where the sheet
## covers with any margin, so a single frame of drift at either end shows the
## page behind it. A quarter of a screen of slack means "covered" is a range
## rather than a point.
const SHEET_SCALE: float = 1.25

## How far past the edge the sheet starts and ends, as a share of width. A sheet
## that starts exactly at the edge shows its corner on the first frame.
const OVERSHOOT: float = 0.08

## Where the sheet's left edge sits, in screen widths, at each stage.
##
## Fully clear to the left, centred over the screen with the slack split evenly
## either side, then fully clear to the right.
const START_POSITION: float = -SHEET_SCALE - OVERSHOOT
const COVERED_POSITION: float = -(SHEET_SCALE - 1.0) * 0.5
const END_POSITION: float = 1.0 + OVERSHOOT

signal covered

var _sheet_position: float = START_POSITION
var _tween: Tween = null
var _sheet_color: Color = Color(0.09, 0.10, 0.13, 1.0)
var _edge_color: Color = Color(0.02, 0.02, 0.03, 1.0)


func _ready() -> void:
	## The wipe covers everything and is never a click target -- a screen change
	## already consumed the input that started it.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 4096


## Paint the sheet in the current theme rather than a fixed colour, so a wipe in
## the light theme is a sheet of paper and not a hole in the screen.
func set_palette(sheet: Color, edge: Color) -> void:
	_sheet_color = sheet
	_edge_color = edge
	queue_redraw()


## Cover, run `midpoint`, then reveal. The caller does not have to know the
## timing -- handing over the swap is the whole interface.
func play(midpoint: Callable) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	_sheet_position = START_POSITION
	queue_redraw()
	_tween = create_tween()
	_tween.tween_method(
		_set_sheet_position, START_POSITION, COVERED_POSITION, COVER_SECONDS
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	## The swap happens at the *start* of the hold rather than at the instant of
	## coverage, so the incoming screen has the whole hold to lay itself out
	## before anything of it is uncovered.
	_tween.tween_callback(func() -> void:
		if midpoint.is_valid():
			midpoint.call()
		covered.emit()
	)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_method(
		_set_sheet_position, COVERED_POSITION, END_POSITION, REVEAL_SECONDS
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: visible = false)


func _set_sheet_position(value: float) -> void:
	_sheet_position = value
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var offset := _sheet_position * size.x
	var sheet_width := size.x * SHEET_SCALE
	draw_rect(Rect2(Vector2(offset, 0.0), Vector2(sheet_width, size.y)), _sheet_color)
	## The lead edge. Two lines rather than a gradient: the interface is drawn
	## with a pen everywhere else, and a soft edge here would be the only airbrush
	## in the game.
	var edge_x := offset + sheet_width
	draw_line(
		Vector2(edge_x, 0.0), Vector2(edge_x, size.y), _edge_color, 3.0
	)
	draw_line(
		Vector2(edge_x + 5.0, 0.0), Vector2(edge_x + 5.0, size.y),
		Color(_edge_color, 0.35), 1.0
	)
