class_name BlockPainter
extends Control

## The paint program, for a block.
##
## A paint program is the right shape for this and it is worth being explicit
## about why, because "an MS Paint for food" sounds like a joke and is not. A
## paint program has exactly the four parts this decision has:
##
## | paint program | kitchen |
## |---|---|
## | canvas | the block's top face |
## | palette | the pastes you have a supply of |
## | brush size | the nozzle |
## | how much paint is left | how much paste is left |
##
## The last row is the one that makes it a *game* rather than a picker. In every
## paint program the paint is infinite, and here it is the scarce thing: the
## gauge beside each swatch drains while you drag, and when it is empty that
## paste stops coming out of the nozzle mid-stroke. Nobody has to be told they are
## short of Xérvyan.
##
## And the ratio is a **readout**, not a control. It updates live under the block
## because it is a measurement of the picture, which is the inversion the whole
## feature exists for -- see `PastePaint`.
##
## ## The chef's ceiling is a locked palette
##
## §1's two-to-four is enforced in `PastePaint.paint` so that nothing can walk
## past it, and shown here as swatches that will not pick up: a fifth paste with
## a good chef is not a message about a limit, it is a swatch that does nothing
## when you click it and says why underneath.

const Larder := preload("res://scripts/data/region_larder.gd")
const FoodBlockData := preload("res://scripts/data/food_block.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal changed

## Tall enough for three lines that do not touch: the name, what is left, and the
## gauge. It was 46, laid out by eye against the name alone, and the note and the
## gauge overlapped by four pixels on every swatch -- which reads as a rendering
## fault rather than as a tight row.
const SWATCH_HEIGHT: float = 60.0
const SWATCH_WIDTH: float = 210.0
const GAUGE_HEIGHT: float = 6.0
const BLOCK_MIN := Vector2(360.0, 300.0)

var _paint: PastePaint = null
var _block_name: String = FoodBlockData.DEFAULT_BLOCK
var _delivered: Dictionary = {}
var _ceiling: int = 2
var _selected: String = ""
var _nozzle: String = PastePaint.DEFAULT_NOZZLE

var _block: TofuBlock = null
var _swatches: VBoxContainer = null
var _readout: Label = null
var _caption: Label = null
var _nozzle_row: HBoxContainer = null


static func build() -> BlockPainter:
	var painter := BlockPainter.new()
	painter._compose()
	return painter


func _compose() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var stage := VBoxContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 6)
	row.add_child(stage)

	_block = TofuBlock.new()
	_block.name = "PaintedBlock"
	_block.interactive = true
	_block.custom_minimum_size = BLOCK_MIN
	_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_block.pressed_at.connect(_lay)
	_block.dragged_to.connect(_lay)
	stage.add_child(_block)

	## The ratio, under the block, where a readout belongs. Above it, it would be
	## the first thing read and it is the *consequence* of the picture.
	_readout = Label.new()
	_readout.name = "MixValue"
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(_readout)
	_caption = Label.new()
	_caption.name = "MixContext"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(_caption)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(SWATCH_WIDTH + 12.0, 0.0)
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)

	_nozzle_row = HBoxContainer.new()
	_nozzle_row.name = "Nozzles"
	_nozzle_row.add_theme_constant_override("separation", 4)
	side.add_child(_nozzle_row)
	for nozzle in PastePaint.NOZZLE_ORDER:
		var button := Button.new()
		button.name = "Nozzle%sButton" % str(nozzle).capitalize()
		button.text = str(nozzle)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := str(nozzle)
		button.pressed.connect(func() -> void:
			_nozzle = value
			_block.nozzle_cells = PastePaint.nozzle_radius(value)
			_refresh_nozzles()
			_block.queue_redraw()
		)
		_nozzle_row.add_child(button)

	var scrape := Button.new()
	scrape.name = "ScrapeButton"
	scrape.text = "scrape it back"
	scrape.pressed.connect(func() -> void:
		_selected = ""
		_refresh_swatches()
	)
	side.add_child(scrape)

	_swatches = VBoxContainer.new()
	_swatches.name = "Palette"
	_swatches.add_theme_constant_override("separation", 4)
	side.add_child(_swatches)


## Hand the painter everything it needs to be right about.
##
## `delivered` is `PasteStore.delivered` and nothing here recomputes it -- the
## palette and the kitchen have to agree about how much paste exists, and the way
## to guarantee that is for one of them not to know how to work it out.
func open_with(
	paint: PastePaint, block: String, delivered_now: Dictionary, ceiling: int
) -> void:
	_paint = paint
	_block_name = block
	_delivered = delivered_now
	_ceiling = ceiling
	if _selected.is_empty():
		_selected = _first_stocked()
	_block.nozzle_cells = PastePaint.nozzle_radius(_nozzle)
	_block.set_paint(paint)
	refresh()


func refresh() -> void:
	_refresh_swatches()
	_refresh_nozzles()
	_refresh_readout()


func _first_stocked() -> String:
	for paste in _delivered:
		return str(paste)
	return ""


## ## Laying paste down
##
## The store is checked *before* the stroke and the stroke is clipped to it, so a
## nozzle drawn across a nearly-empty paste puts down what is left and then stops
## rather than overdrawing and being corrected afterwards. Correcting afterwards
## is what would make the gauge flicker below zero and back.
func _lay(cell: Vector2) -> void:
	if _paint == null:
		return
	if _selected.is_empty():
		var freed := _paint.scrape(cell, PastePaint.nozzle_radius(_nozzle))
		if freed.is_empty():
			return
		_after_stroke()
		return
	var radius := PastePaint.nozzle_radius(_nozzle)
	var left := float(_remaining().get(_selected, 0.0))
	if left <= 0.0:
		return
	## How much block this paste can still cover, in cells. A thirsty block turns
	## a healthy store into a small amount of area -- which is `takes_paste` doing
	## the job it was written for.
	var affordable := PasteStore.spreadable(left, _block_name) \
		* float(PastePaint.CELLS)
	if affordable < 1.0:
		return
	## Shrink the nozzle rather than refusing the stroke. A cook with a spoonful
	## left does not stop being able to spread it; they spread a smaller patch.
	var capped := minf(radius, sqrt(affordable / PI))
	if _paint.paint(cell, capped, _selected, _ceiling) <= 0:
		return
	_after_stroke()


func _after_stroke() -> void:
	_block.refresh_paint()
	_refresh_swatches()
	_refresh_readout()
	changed.emit()


func _remaining() -> Dictionary:
	if _paint == null:
		return {}
	return PasteStore.remaining(
		_delivered, PasteStore.spent_on(_paint), _block_name
	)


func _refresh_nozzles() -> void:
	for child in _nozzle_row.get_children():
		var button := child as Button
		if button != null:
			button.button_pressed = button.text == _nozzle


func _refresh_swatches() -> void:
	for child in _swatches.get_children():
		child.queue_free()
	var left := _remaining()
	var on_block: Dictionary = _paint.counts() if _paint != null else {}
	## Full slots are what makes a swatch unpickable, not the delivery list: a
	## paste you have plenty of is still refused once the chef is holding as many
	## as they can hold, and the swatch has to say which of the two it is.
	var full := on_block.size() >= _ceiling
	for paste in _delivered:
		var name := str(paste)
		var swatch := _Swatch.new()
		swatch.name = "Swatch%s" % name.replace(" ", "")
		swatch.custom_minimum_size = Vector2(SWATCH_WIDTH, SWATCH_HEIGHT)
		swatch.paste = name
		swatch.colour = Larder.paste_colour(PastePaint._region_of(name))
		swatch.share = float(left.get(name, 0.0)) \
			/ maxf(float(_delivered.get(name, 1.0)), 0.001)
		swatch.spent = float(_delivered.get(name, 0.0)) - float(left.get(name, 0.0))
		swatch.stock = float(left.get(name, 0.0))
		swatch.selected = name == _selected
		swatch.locked = full and not on_block.has(name)
		swatch.pressed_paste.connect(func(picked: String) -> void:
			_selected = picked
			_refresh_swatches()
		)
		_swatches.add_child(swatch)

	var note := Label.new()
	note.name = "PaletteContext"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "The chef holds %d at once. %d on the block." % [
		_ceiling, on_block.size()
	]
	_swatches.add_child(note)


func _refresh_readout() -> void:
	if _paint == null:
		return
	var shares := _paint.shares()
	if shares.is_empty():
		_readout.text = "bare block"
		_caption.text = "Nothing on it yet. Pick a paste and spread some."
		return
	var names: Array = shares.keys()
	names.sort_custom(func(a, b) -> bool:
		return float(shares[a]) > float(shares[b])
	)
	var parts: Array[String] = []
	for paste in names:
		parts.append("%d%% %s" % [
			roundi(float(shares[paste]) * 100.0),
			str(paste).trim_suffix(" paste"),
		])
	_readout.text = " · ".join(parts)
	## Coverage is a separate fact from the mix and is stated as one. A block that
	## is 100% Xérvyan across a third of its surface is a thin meal that tastes
	## entirely of one thing, and a mix printed on its own cannot say that.
	_caption.text = "%d%% of the block is covered." % roundi(_paint.coverage() * 100.0)


## One paste on the palette: the colour, what it is called, and how much is left.
##
## A `Button` would give this the theme's lettering and its own edge, both of
## which fight a colour swatch -- the swatch *is* the affordance, and a box drawn
## round a box of colour reads as a picture of a button rather than as paint. So
## it draws itself and handles its own click.
class _Swatch extends Control:
	signal pressed_paste(paste: String)

	var paste: String = ""
	var colour := Color.WHITE
	var share: float = 1.0
	var spent: float = 0.0
	var stock: float = 0.0
	var selected: bool = false
	var locked: bool = false

	const SWATCH_SIZE: float = 26.0
	const PAD: float = 6.0

	func _ready() -> void:
		set_meta("ui_style_exempt", true)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = ""

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			if not locked:
				pressed_paste.emit(paste)
			accept_event()

	func _draw() -> void:
		var light := UIPalette.control_is_light(self)
		var ink := UIPalette.color(&"ink", light)
		var faint := UIPalette.color(&"ink_faint", light)
		## An empty pot is drawn empty rather than greyed. A swatch at 12% opacity
		## says "unavailable"; a swatch of full-strength colour with nothing under
		## it says "you have run out of this", which is the true statement.
		var pot := Rect2(PAD, (size.y - SWATCH_SIZE) * 0.5, SWATCH_SIZE, SWATCH_SIZE)
		draw_rect(pot, Color(colour, 0.22), true)
		var filled := pot
		filled.size.y = pot.size.y * clampf(share, 0.0, 1.0)
		filled.position.y = pot.position.y + pot.size.y - filled.size.y
		draw_rect(filled, colour, true)
		draw_rect(pot, Color(ink, 0.45 if selected else 0.2), false, 1.4)

		var text_x := pot.position.x + pot.size.x + PAD * 1.5
		var font := get_theme_default_font()
		var label_size := get_theme_default_font_size()
		draw_string(
			font, Vector2(text_x, PAD + float(label_size)),
			paste.trim_suffix(" paste"),
			HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x - PAD, label_size,
			Color(ink, 0.45 if locked else 1.0)
		)
		draw_string(
			font, Vector2(text_x, PAD + float(label_size) * 2.0 + 2.0),
			_note(), HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x - PAD,
			maxi(label_size - 3, 8), faint
		)
		var gauge := Rect2(
			text_x, size.y - PAD - GAUGE_HEIGHT,
			size.x - text_x - PAD, GAUGE_HEIGHT
		)
		draw_rect(gauge, Color(faint, 0.25), true)
		var run := gauge
		run.size.x = gauge.size.x * clampf(share, 0.0, 1.0)
		draw_rect(run, Color(colour, 0.95), true)
		if selected:
			## The picked paste is the one with a line under the whole row, in its
			## own colour. Not a highlight box: a cook knows which pot they have
			## the spoon in because the spoon is in it.
			draw_line(
				Vector2(PAD, size.y - 1.0), Vector2(size.x - PAD, size.y - 1.0),
				colour, 2.0
			)

	func _note() -> String:
		if locked:
			return "the chef is already holding as many as they can"
		if stock <= 0.001:
			return "none left this week"
		return "%.2f left · %.2f spread" % [stock, spent]

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			queue_redraw()
