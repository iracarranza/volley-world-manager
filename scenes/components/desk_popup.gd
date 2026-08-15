class_name DeskPopup
extends Control

## What a card opens into.
##
## An overlay rather than a `PopupPanel`, which is what the journal's attribute
## lab uses. A `PopupPanel` is a `Window`: it has no `modulate` to fade, it sizes
## itself in screen space rather than against the page it belongs to, and off the
## main window it is a second surface the style walk and the halftone screen have
## to be told about separately. What is wanted here is a panel on the same sheet
## of paper, so it is a `Control` on the same sheet of paper.
##
## It has to be the **last child of a non-Container root**. Later siblings draw
## over earlier ones, which is why it covers the page; and a `Control` under a
## `Container` has its rect recomputed every layout pass, which is why the root
## it hangs from must be a plain `Control`.
const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal closed

## **These are the frame's size, and until now they were its minimum.**
##
## The frame was a `PanelContainer` with `custom_minimum_size` inside a
## zero-margin `MarginContainer` -- and a `MarginContainer` fits its children to
## its own rect minus the margins, ignoring size flags entirely. A minimum cannot
## cap anything, so at any window bigger than 620x470 the "window on top of the
## desk" was the whole screen, and had been since the file was written. Both
## constants were unreachable, which is §0 in its usual dress.
##
## It mattered most on the scouting board, whose entire argument is that partial
## reports are compared *against each other* -- and opening one covered every
## other one. A profile is a card lifted off the board, so the board has to still
## be there behind it.
const FRAME_WIDTH: float = 620.0
const FRAME_HEIGHT: float = 470.0
## What a panel takes when it is the whole subject rather than a list you dip
## into. A staff member's correspondence is not a lookup -- it is the thing you
## came to read -- so it gets the page rather than a window on top of it.
const FILL_MARGIN: float = 48.0

var body: VBoxContainer = null
## Where controls go, pinned under the scrolling body.
var footer: HBoxContainer = null
var _title: Label = null
var _flavour: Label = null
var _frame: PanelContainer = null
var _filling: bool = false


static func build() -> DeskPopup:
	var popup := DeskPopup.new()
	popup._compose()
	return popup


## Take the page, less a margin, instead of a fixed window.
##
## The scrim still shows at the edges, which is what keeps it reading as a panel
## laid over the desk rather than as a screen the manager navigated to -- the
## difference between opening something and going somewhere.
func fill_page() -> void:
	_filling = true
	_layout_frame()


## Where the frame sits. One function, called on every resize and on every open,
## so the two modes cannot drift apart the way they did when one was a minimum
## size and the other was a set of margins.
func _layout_frame() -> void:
	if _frame == null:
		return
	if _filling:
		_frame.position = Vector2(FILL_MARGIN, FILL_MARGIN)
		_frame.size = size - Vector2(FILL_MARGIN, FILL_MARGIN) * 2.0
		return
	## Capped as well as floored: on a small window the frame gives way rather
	## than running off the edges, which a fixed size would do silently.
	var wanted := Vector2(
		minf(FRAME_WIDTH, size.x - FILL_MARGIN * 2.0),
		minf(FRAME_HEIGHT, size.y - FILL_MARGIN * 2.0)
	)
	_frame.size = wanted
	_frame.position = ((size - wanted) * 0.5).floor()


func _compose() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	## The scrim takes every click that is not on the frame, which is what makes
	## clicking away close it -- and, more importantly, what stops a click
	## landing on the building behind and turning it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_scrim_input)

	var scrim := _Scrim.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	## A plain `Control`, not a `Container`, and that is the fix.
	##
	## Any `Container` lays its children out for you, and every one of them either
	## fits a child to the full rect or shrinks it to its minimum -- neither of
	## which is "this size, centred, unless somebody asks for the page". Under a
	## bare `Control` nothing is recomputed and `_layout_frame` owns the rect.
	var holder := Control.new()
	holder.name = "FrameHolder"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.resized.connect(_layout_frame)

	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(frame)
	_frame = frame
	resized.connect(_layout_frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	frame.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	titles.add_child(_title)
	## The card's own second line, carried through. The panel opens *from* a card
	## and arriving somewhere that has forgotten what you clicked is how a modal
	## stops feeling like the same object.
	_flavour = Label.new()
	_flavour.add_theme_font_size_override("font_size", 12)
	_flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_flavour)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_panel)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	scroll.add_child(body)

	## ## Actions do not scroll
	##
	## The body scrolls because a report is as long as it is. The controls that
	## *change* something must not, and the scouting profile is what proved it: the
	## three marks were the last rows of the body, so on any voli with a full
	## report they sat below the fold -- the only three controls on the screen,
	## invisible by default, under six rows of numbers that change nothing.
	##
	## A footer that is empty when nobody fills it, so a popup with no actions is
	## not a popup with a blank strip at the bottom.
	footer = HBoxContainer.new()
	footer.name = "PopupFooter"
	footer.add_theme_constant_override("separation", 6)
	column.add_child(footer)


func open(title: String, flavour: String) -> void:
	_title.text = title
	_flavour.text = flavour
	## Back to a window unless this open asks for the page. `fill_page` used to
	## mutate the frame permanently, so one screen taking the page left every
	## later popup on that screen taking it too.
	_filling = false
	## Cleared on open rather than by each caller, so a screen that fills the
	## footer once cannot leave its buttons on the next thing opened.
	for child in footer.get_children():
		child.queue_free()
	visible = true
	_layout_frame()
	## Grab the keyboard so Escape reaches `_unhandled_key_input` before whatever
	## had focus on the page underneath.
	grab_focus()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		close_panel()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()


## The dimming, drawn rather than a `ColorRect`, because the amount a page dims
## is a property of the page's own ink and `scrim` is already the token for it.
class _Scrim extends Control:
	func _draw() -> void:
		draw_rect(
			Rect2(Vector2.ZERO, size),
			UIPalette.color(&"scrim", UIPalette.control_is_light(self)),
			true
		)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
			queue_redraw()
