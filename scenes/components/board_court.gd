class_name BoardCourt
extends Control

## The six, where they are standing, drawn in the blue pen.
##
## The one thing on the board that is a *picture* rather than a figure, and it
## earns that because rotation is spatial: "4 · 3 · 2 · 5 · 6 · 1" is the same
## information and nobody has ever read it as a shape. A manager checking a
## lineup is asking where their setter is, and that is a question about a court.
##
## Blue, because the board's blue pen is **structure** -- the court, the slot
## numbers, the rules. The marks that are judgements get green and red; the
## marks that are just the shape of the game get blue, and keeping those apart is
## most of what stops a whiteboard becoming a heat map.
const UIPalette := preload("res://scripts/data/ui_palette.gd")
## The board's display face, **through a fallback rather than raw**.
##
## Short Stack draws no macron at all and one caron in eight, and Yatra One is
## little better -- so `Pāwa Hitō`, `Ralī` and `Miloš` came out as hollow boxes
## on every card and tray that preloaded the `.ttf` directly. `body_font.tres`
## has had Cherry Bomb One behind it for exactly this reason; these two are the
## same arrangement for the faces that had been reaching past it.
const BoardFace := preload("res://scenes/themes/board_face.tres")

## Where each rotation slot stands, in unit court coordinates with the net along
## the top. Slots 4, 3 and 2 are the front row left to right; 5, 6 and 1 are the
## back row. This is the arrangement, not a diagram of it -- the numbers go
## anticlockwise from the right-back serving position, which is why 1 sits on the
## right and 4 on the left.
const SLOT_POSITIONS := {
	4: Vector2(0.22, 0.24), 3: Vector2(0.50, 0.20), 2: Vector2(0.78, 0.24),
	5: Vector2(0.22, 0.74), 6: Vector2(0.50, 0.80), 1: Vector2(0.78, 0.74),
}
## Where the attack line sits, as a share of the half-court's depth. Three metres
## of a nine-metre half.
const ATTACK_LINE: float = 0.333
const MARKER_WIDTH: float = 2.0
## The net is the heaviest line on the court and the only one drawn in black:
## everything else here is structure the manager is reading, and the net is the
## one edge that is a fact about the sport.
const NET_WIDTH: float = 4.0
const SLOT_RADIUS: float = 15.0

var light_mode: bool = false
## `{slot_number: {"label": String, "alarm": String}}` -- alarm is "", "warn" or
## "bad", which is the only thing the court says about *quality*. Everything
## else it draws is position.
var slots: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(190.0, 190.0)


func _draw() -> void:
	var blue := UIPalette.board_color(&"marker_blue", light_mode)
	var ink := UIPalette.board_color(&"ink", light_mode)
	var faint := Color(blue.r, blue.g, blue.b, 0.08)
	draw_rect(Rect2(Vector2.ZERO, size), faint, true)
	draw_rect(Rect2(Vector2.ZERO, size), blue, false, MARKER_WIDTH)
	## The attack line, dashed -- it is a line you may cross, unlike the others.
	var y := size.y * ATTACK_LINE
	var step := 9.0
	var x := 0.0
	while x < size.x:
		draw_line(
			Vector2(x, y), Vector2(minf(x + step * 0.6, size.x), y),
			blue, MARKER_WIDTH * 0.75
		)
		x += step
	## And the net, overhanging both sidelines because it does.
	draw_line(Vector2(-6.0, 0.0), Vector2(size.x + 6.0, 0.0), ink, NET_WIDTH)

	var face := BoardFace
	for slot in SLOT_POSITIONS:
		var entry: Dictionary = slots.get(slot, {})
		var centre: Vector2 = Vector2(SLOT_POSITIONS[slot]) * size
		var edge := ink
		match str(entry.get("alarm", "")):
			"warn":
				edge = UIPalette.board_color(&"amber", light_mode)
			"bad":
				edge = UIPalette.board_color(&"marker_red", light_mode)
		draw_circle(centre, SLOT_RADIUS, UIPalette.board_color(&"card", light_mode))
		draw_arc(centre, SLOT_RADIUS, 0.0, TAU, 28, edge, MARKER_WIDTH)
		var text := str(entry.get("label", str(slot)))
		var extent := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(
			face, centre + Vector2(-extent.x * 0.5, 5.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, edge
		)
