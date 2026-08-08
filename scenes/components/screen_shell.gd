class_name VolleyballScreenShell
extends RefCounted

## The anatomy every full-screen page in this game shares.
##
## The journal established it in `.tscn` form and the three screens
## added since -- training, the daily schedule, scouting -- were each built in
## code from a bare `MarginContainer`, so each one drew its title as a loose
## label on the raw page and floated its controls with nothing under them. They
## read as a different application: no ribbon along the top, no card holding the
## body, and in Molten no background at all, because the backdrop node is part of
## the anatomy too and none of them had one.
##
## Rather than copy the journal's node tree into three scripts, this builds it
## once. A screen calls `build` and gets back the content box to fill; the
## ribbon, the card and the page under both are the shell's business.
##
## The names matter and are not decorative. `UIStyleSystem` repaints a `ColorRect`
## only when it is called "Background", so the backdrop is named for the styler
## rather than for the reader.

const UIBackdrop := preload("res://scenes/components/ui_backdrop.gd")
const UICorkBoardScript := preload("res://scenes/components/cork_board.gd")

## What the card is lying on. `"paper"` is the default -- the page is the page.
## `"cork"` makes the card a sheet clipped to a clipboard, which is what the
## training screen is: the one object on the desk you carry to a session.
const BACKING_PAPER: StringName = &"paper"
const BACKING_CORK: StringName = &"cork"

## Matched to `journal_screen.tscn` rather than chosen. Two pages an inch apart
## in their margins read as a bug in the one the player sees second.
const PAGE_MARGIN_X: int = 18
## Extra page margin when a cork board has to show round the card.
const CORK_MARGIN: int = 12
const PAGE_MARGIN_Y: int = 14
const ROOT_SEPARATION: int = 10
const RIBBON_SEPARATION: int = 12
const CARD_MARGIN_X: int = 16
const CARD_MARGIN_Y: int = 12
const TITLE_FONT_SIZE: int = 24


## What a built screen hands back to its caller.
##
## `content` is the box to fill. `ribbon` is exposed so a screen can hang its own
## actions -- the training page wants a Daily Schedule button beside Back -- and
## `title` so a screen whose heading changes can rewrite it without re-reading
## the tree.
class Shell extends RefCounted:
	var content: VBoxContainer
	var ribbon: HBoxContainer
	var title: Label


## Lay the page, the ribbon and the card onto `screen`, and return the parts a
## screen is expected to fill.
##
## `actions` are added to the ribbon in order, after the title and before Back.
static func build(
	screen: Control,
	heading: String,
	actions: Array[Button] = [],
	backing: StringName = BACKING_PAPER,
) -> Shell:
	var backdrop := UIBackdrop.new()
	backdrop.name = "Background"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var extra := CORK_MARGIN if backing == BACKING_CORK else 0
	margin.add_theme_constant_override("margin_left", PAGE_MARGIN_X + extra)
	margin.add_theme_constant_override("margin_right", PAGE_MARGIN_X + extra)
	margin.add_theme_constant_override("margin_top", PAGE_MARGIN_Y)
	margin.add_theme_constant_override("margin_bottom", PAGE_MARGIN_Y + extra)
	screen.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", ROOT_SEPARATION)
	margin.add_child(root)

	## The ribbon. Title on the left taking the slack, actions on the right, in
	## the journal's own order and at its own type size.
	var ribbon := HBoxContainer.new()
	ribbon.add_theme_constant_override("separation", RIBBON_SEPARATION)
	root.add_child(ribbon)
	var title := Label.new()
	title.text = heading
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	ribbon.add_child(title)
	for action in actions:
		ribbon.add_child(action)

	## The card. Everything a screen has to say lives inside this one panel, which
	## is what makes a page feel like a page rather than controls on a desk.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(card)
	if backing == BACKING_CORK:
		## Added as a child of the card and drawn behind it, so the board tracks
		## the card's rect through every layout pass without anything having to
		## keep two rects in step.
		var cork := UICorkBoardScript.new()
		cork.name = "CorkBoard"
		cork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(cork)
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", CARD_MARGIN_X)
	card_margin.add_theme_constant_override("margin_right", CARD_MARGIN_X)
	card_margin.add_theme_constant_override("margin_top", CARD_MARGIN_Y)
	card_margin.add_theme_constant_override("margin_bottom", CARD_MARGIN_Y)
	card.add_child(card_margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", ROOT_SEPARATION)
	card_margin.add_child(content)

	var shell := Shell.new()
	shell.content = content
	shell.ribbon = ribbon
	shell.title = title
	return shell


## A ribbon action, built the way the journal's ribbon buttons are.
static func action(text: String, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	return button
