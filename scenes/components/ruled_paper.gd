class_name UIRuledPaper
extends Control

## Wide-ruled paper, for the lists that are lists of names.
##
## An `ItemList` on its own is a control: a panel, a highlight bar, rows pitched
## to whatever the font asked for. That is the right object for a file browser
## and the wrong one for this desk, where a transfer list and a scouting list are
## things somebody wrote down -- a column of names, one per line, on paper with
## lines already on it.
##
## Wide ruled and not college ruled, and the difference is the whole look. Wide
## is 8.7 mm between rules; college is 7.1. On a screen that is roughly 34 px
## against 28, and the wider pitch is what reads as a pad rather than as a dense
## table: a name sits *in* its line with air above and below it, rather than
## filling it.
##
## Drawn behind the list rather than by it. `ItemList` cannot be told to rule
## itself, but it can be given a transparent panel, at which point whatever is
## behind it shows through -- so this goes underneath, ruled at the same pitch the
## list is pitched to, and the two line up because one number feeds both.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## The pitch, in pixels, and it is the only number either object gets to have.
##
## `rule` hands it to the list as a row height, so a rule cannot end up between
## two names or two names inside one rule. That was the failure mode
## worth designing out: ruled paper whose lines do not match its writing is not
## paper, it is a background image.
const RULE_PITCH: float = 34.0

## How far in the margin rule sits. Real paper puts it about an inch from the
## left on a 21 cm sheet; this is the same share of a narrower column.
const MARGIN_X: float = 26.0

## The rules are quiet and the margin is not.
##
## On a pad the horizontal rules are printed in a pale blue-grey that the writing
## sits over without contest, and the margin is a single red line. Keeping that
## split matters here for the same reason it matters on paper: one of them is a
## grid and the other is an instruction about where to start.
const RULE_ALPHA: float = 0.30
const MARGIN_ALPHA: float = 0.45

## How far a printed rule wanders. Almost none -- these are *printed*, unlike
## every other line on this desk, and the difference between a printed rule and
## a drawn one is most of what says the writing was added afterwards.
const RULE_WAVE: float = 0.35

var light_mode: bool = true

## Where the first rule sits, so the paper can be lined up with a list whose own
## content starts below its top edge.
var top_inset: float = 0.0:
	set(value):
		top_inset = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Painted by hand end to end, like the board and the sticky note. The style
	## pass would give this a drawn paper edge and a halftone wash, and a pad is
	## smooth stock with print on it.
	set_meta("ui_style_exempt", true)
	theme_changed.connect(_sync_theme)
	_sync_theme()
	resized.connect(queue_redraw)


func _sync_theme() -> void:
	light_mode = UIPalette.control_is_light(self)
	queue_redraw()


## Rule a list, and pitch it to the rules.
##
## Static and taking the list, because the alternative is every caller
## remembering four properties -- and the one that matters, the row height, is
## the one that silently produces a background image when it is forgotten.
## Added as a *child* of the list, drawn behind it, which is how `UIInkOutline`
## already attaches itself to a control. An `ItemList` is not a `Container`, so a
## `Control` child keeps its own anchors instead of being laid out -- and unlike a
## sibling, this works wherever the list happens to live. The first attempt made
## it a sibling and put a third child inside an `HSplitContainer`, which takes
## exactly two.
static func rule(list: ItemList) -> UIRuledPaper:
	var paper := UIRuledPaper.new()
	paper.name = "RuledPaper"
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.show_behind_parent = true
	list.add_child(paper)
	## The list's own panel goes, or it covers the paper it is sitting on.
	list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	list.add_theme_constant_override("v_separation", 0)
	## The pitch is bought with padding on the item stylebox, not with
	## `fixed_item_height`, which was removed from `ItemList` -- it is a theme
	## constant's job now. Half above and half below, so a name sits in the middle
	## of its line rather than on the rule under it.
	for style_name in ["hovered", "selected", "selected_focus", "cursor"]:
		var box: StyleBox = list.get_theme_stylebox(style_name, "ItemList")
		if box == null:
			continue
		var padded: StyleBox = box.duplicate()
		padded.content_margin_top = RULE_PITCH * 0.5 - 9.0
		padded.content_margin_bottom = RULE_PITCH * 0.5 - 9.0
		list.add_theme_stylebox_override(style_name, padded)
	## Names start after the margin rule, the way writing does.
	list.add_theme_constant_override("h_separation", int(MARGIN_X))
	return paper


func _draw() -> void:
	var ink := UIPalette.color(&"ink", light_mode)
	## Blue-grey rather than the page's own ink: printed rules on a pad are not
	## the colour anybody writes in, which is exactly why writing reads as being
	## on top of them.
	var rule_ink := Color(
		lerpf(ink.r, 0.42, 0.55), lerpf(ink.g, 0.52, 0.55),
		lerpf(ink.b, 0.68, 0.55), RULE_ALPHA
	)
	var margin_ink := Color(0.78, 0.32, 0.30, MARGIN_ALPHA)

	var line := top_inset + RULE_PITCH
	var index := 0
	while line < size.y:
		## Two points per rule, nudged. A printed line is straight and a sheet of
		## paper is not quite flat, so the wander belongs to the paper rather than
		## to the hand that would otherwise be drawing it.
		var wave := sin(float(index) * 2.39) * RULE_WAVE
		draw_line(
			Vector2(MARGIN_X * 0.5, line + wave),
			Vector2(size.x - 6.0, line - wave),
			rule_ink, 1.0, true
		)
		line += RULE_PITCH
		index += 1

	draw_line(
		Vector2(MARGIN_X, 2.0), Vector2(MARGIN_X, size.y - 2.0),
		margin_ink, 1.2, true
	)
