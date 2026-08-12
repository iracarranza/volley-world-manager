class_name MenuCard
extends Button

## A card on the desk that opens into something.
##
## It replaced an expanding card, and the difference is not cosmetic. A dropdown
## puts the thing you opened *inside the column you opened it from*, so a list of
## twenty-one items either scrolls in a 330px gutter or pushes everything under
## it off the page. Both happened. What these are is a way in, and the thing they
## are a way into deserves the room to be itself.
##
## ## Three labels, and each is a different job
##
## | line | is | example |
## |---|---|---|
## | title | the name of the thing | `Equipment` |
## | flavour | what it is for, in the register of somebody explaining it once | `Fit your volis' rooms with helpful stuff` |
## | reading | what is true right now | `cookbook, in 5 rooms` |
##
## The third is the one that earns the card its space on the page. A card that
## says only its name and its purpose is a menu item; a card that also says
## `Nothing fitted` has answered the question most visits are asking without
## being opened. And the reading is a *reading* -- `Equipment (3)` is a fact
## about the interface, `cookbook, in 5 rooms` is a fact about the club.
const UIPalette := preload("res://scripts/data/ui_palette.gd")

## The height three single lines need. A **minimum**, not the height: a `Button`
## is not a `Container`, so nothing grows it when a flavour line wraps, and the
## first build had the third label of the longest card printing on the page
## below its own border.
const CARD_HEIGHT: float = 74.0
const CARD_PADDING: float = 18.0

var _column: VBoxContainer = null
var _title: Label = null
var _flavour: Label = null
var _reading: Label = null


static func build(title: String, flavour: String) -> MenuCard:
	var card := MenuCard.new()
	card._compose(title, flavour)
	return card


func _compose(title: String, flavour: String) -> void:
	custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## The whole card is the hit area. A card that only opens from a corner is a
	## card the player learns to aim at.
	focus_mode = Control.FOCUS_ALL

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## Everything inside is text the button is hosting, so none of it may eat the
	## click that opens the card.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 1)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_column)

	_title = _line(_column, title, 17)
	_flavour = _line(_column, flavour, 12)
	_reading = _line(_column, "", 12)
	_column.minimum_size_changed.connect(_grow_to_fit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_grow_to_fit")


func _line(into: VBoxContainer, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(label)
	return label


## Rewrite the third line. Called on every refresh, and it touches nothing else,
## because the first two are what the card *is* and only the last is news.
func set_reading(reading: String) -> void:
	if _reading != null:
		_reading.text = reading
	_grow_to_fit()


## Take whatever height three lines of this width actually need.
##
## Deferred because an autowrapped label's minimum height is not known until it
## has been given a width, which happens in the layout pass after the text is
## set.
func _grow_to_fit() -> void:
	if _column == null:
		return
	custom_minimum_size.y = maxf(
		CARD_HEIGHT, _column.get_combined_minimum_size().y + CARD_PADDING
	)
