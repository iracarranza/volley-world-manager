class_name BoardTray
extends Control

## The aluminium tray, and the four markers resting in it.
##
## The only piece of the board that is purely an object and says nothing. It is
## here because a whiteboard without a tray is a white rectangle, and because it
## is the legend: everything on this screen is written in one of these four
## pens, and seeing the four of them lying there is what makes a red grade read
## as *somebody picked up the red one* rather than as a status colour.
##
## The label is the board's own caption -- what this board is for and when it was
## written, in the same uppercase letterspaced hand every other field name uses.
const UIPalette := preload("res://scripts/data/ui_palette.gd")
## The board's display face, **through a fallback rather than raw**.
##
## Short Stack draws no macron at all and one caron in eight, and Yatra One is
## little better -- so `Pāwa Hitō`, `Ralī` and `Miloš` came out as hollow boxes
## on every card and tray that preloaded the `.ttf` directly. `body_font.tres`
## has had Cherry Bomb One behind it for exactly this reason; these two are the
## same arrangement for the faces that had been reaching past it.
const BoardHand := preload("res://scenes/themes/board_hand.tres")

const TRAY_HEIGHT: float = 30.0
const PEN_SIZE := Vector2(46.0, 9.0)
const PEN_GAP: float = 12.0
const PEN_INSET: float = 26.0

var light_mode: bool = false
var caption: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, TRAY_HEIGHT)


func _draw() -> void:
	var lip := UIPalette.board_color(&"tray_lip", light_mode)
	draw_rect(Rect2(Vector2.ZERO, size), UIPalette.board_color(&"tray", light_mode), true)
	## The lip catches the light along its bottom edge, which is the whole of
	## what makes a flat fill read as a extruded channel rather than a stripe.
	draw_line(
		Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), lip, 2.0
	)
	## Black, red, blue, green -- in the order the design names them, so the tray
	## is also the key to which pen means what.
	var pens: Array[StringName] = [
		&"ink", &"marker_red", &"marker_blue", &"marker_green"
	]
	var x := PEN_INSET
	for pen in pens:
		var body := Rect2(
			Vector2(x, (size.y - PEN_SIZE.y) * 0.5), PEN_SIZE
		)
		draw_rect(body, UIPalette.board_color(pen, light_mode), true)
		x += PEN_SIZE.x + PEN_GAP
	if caption.is_empty():
		return
	var text_ink := UIPalette.board_color(&"ink", light_mode)
	text_ink.a = 0.55
	var extent := BoardHand.get_string_size(
		caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11
	)
	draw_string(
		BoardHand,
		Vector2(size.x - extent.x - PEN_INSET, size.y * 0.5 + 4.0),
		caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_ink
	)
