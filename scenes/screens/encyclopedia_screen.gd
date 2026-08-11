class_name EncyclopediaScreen
extends Control

## What the world already knows about itself, said out loud.
##
## **It authors nothing.** Every line on this screen is read from
## `VolleyballRegions` -- the taglines, the demonyms, the club names, the
## principle weights, the adjacency, the naming traditions. All of it was
## written, all of it is load-bearing in the simulation, and until now none of it
## was legible anywhere except in the source.
##
## That is the same shape as the lock-in board and it is the reason this is worth
## building early rather than late: the expensive half already exists, and what
## was missing was a place to read it. A manager who has never opened this screen
## learns Xérvu serves hard by losing to it, which is right; a manager who wants
## to know *why* should have somewhere to look that is not a wiki somebody else
## wrote.
##
## ## What it is not
##
## Not a strategy guide. It states what a region is and what it values; it does
## not tell you what to do about that. The distinction is the same one the
## whiteboard draws -- figures and facts, never advice -- and it is why the
## principle weights are printed as weights rather than translated into
## sentences about how to beat them.
##
## ## What comes next
##
## Regions are the first article type because they are the most complete. The
## structure below takes a list of articles, so the ones that follow -- traits,
## the glossary in `docs/textbook/GLOSSARY.md`, food blocks and pastes once
## `ACCOMMODATIONS_AND_CARE.md` is built, the Sixnet's own history once it has
## one -- are new entries rather than a new screen.

const ScreenShell := preload("res://scenes/components/screen_shell.gd")

signal back_requested

## The seven principles, in the order the tactical language names them, so two
## regions read against each other line by line.
const PRINCIPLE_ORDER: Array[String] = [
	"decisiveness", "pin_focus", "tempo_variation", "emotional_expression",
	"serve_aggression", "transition_commitment", "block_commitment",
]

var _entries: ItemList
var _article: RichTextLabel
var _subjects: Array[String] = []


func _ready() -> void:
	_build()


func _build() -> void:
	if _entries != null:
		return
	var back := ScreenShell.action("Back", "Return to the journal.")
	back.pressed.connect(func() -> void: back_requested.emit())
	var shell := ScreenShell.build(
		self, "Encyclopedia", [back] as Array[Button]
	)
	var split := HBoxContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	shell.content.add_child(split)

	_entries = ItemList.new()
	_entries.custom_minimum_size = Vector2(220, 0)
	_entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entries.item_selected.connect(_entry_selected)
	split.add_child(_entries)

	_article = RichTextLabel.new()
	_article.bbcode_enabled = true
	_article.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_article.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_article)
	_populate()


## Majors then minors, in the order `manageable_names` already puts them.
##
## Sorting alphabetically would bury the tier, and the tier is the first thing
## about a region that matters: whether it is in the bracket decides whether its
## volis are being watched by an academy of their own.
func _populate() -> void:
	_entries.clear()
	_subjects.clear()
	for region_name in VolleyballRegions.manageable_names():
		var name := str(region_name)
		_subjects.append(name)
		_entries.add_item("%s%s" % [
			name, "" if VolleyballRegions.is_major(name) else "  ·  minor",
		])
	if _entries.item_count > 0:
		_entries.select(0)
		_show_region(_subjects[0])


func _entry_selected(index: int) -> void:
	if index < 0 or index >= _subjects.size():
		return
	_show_region(_subjects[index])


func _show_region(region_name: String) -> void:
	var definition: Dictionary = VolleyballRegions.definition(region_name)
	var lines: Array[String] = []
	lines.append("[font_size=26][b]%s[/b][/font_size]" % region_name)
	lines.append("[i]%s · %s[/i]" % [
		VolleyballRegions.demonym(region_name),
		"Sixnet region" if VolleyballRegions.is_major(region_name) \
			else "minor region · runs no academy",
	])
	lines.append("")
	lines.append(str(definition.get("tagline", "")))
	lines.append("")
	## The three ratings, printed as the numbers they are. They decide what a
	## voli raised here is built out of, so they are a fact about the place
	## rather than a summary of it.
	lines.append("[b]Tradition[/b]  physical %d · technical %d · mental %d" % [
		int(definition.get("physical", 0)),
		int(definition.get("technical", 0)),
		int(definition.get("mental", 0)),
	])
	var clubs := VolleyballRegions.clubs_in(region_name)
	lines.append("[b]Clubs[/b]  %s" % " · ".join(clubs))
	var neighbours: Array = VolleyballRegions.REGION_ADJACENCY.get(
		VolleyballRegions.canonical_name(region_name), []
	)
	if not neighbours.is_empty():
		lines.append("[b]Borders[/b]  %s" % " · ".join(neighbours))
	var given_names: Array = definition.get("names", [])
	if not given_names.is_empty():
		lines.append("[b]Names given here[/b]  %s" % " · ".join(given_names))
	lines.append("")
	## Weights, not advice. A region that plays at 0.85 tempo variation is a
	## region that plays at 0.85 tempo variation; what a manager does about that
	## is the manager's.
	lines.append("[b]How they play[/b]")
	var principles: Dictionary = VolleyballRegions.REGIONAL_PRINCIPLES.get(
		VolleyballRegions.canonical_name(region_name), {}
	)
	for key in PRINCIPLE_ORDER:
		if not principles.has(key):
			continue
		lines.append("  %-24s %.2f" % [
			str(key).capitalize().replace("_", " "), float(principles[key]),
		])
	_article.text = "\n".join(lines)
