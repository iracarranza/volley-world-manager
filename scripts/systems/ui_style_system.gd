class_name VolleyballUIStyleSystem
extends RefCounted

const UIPalette := preload("res://scripts/data/ui_palette.gd")
const UIHalftone := preload("res://scripts/data/ui_halftone.gd")
const UIInkOutline := preload("res://scenes/components/ink_outline.gd")
const UIPaperWindowScript := preload("res://scenes/components/paper_window.gd")
const UIPaperTabsScript := preload("res://scenes/components/paper_tabs.gd")

## Which surfaces get a drawn edge.
##
## Every panel tier, and the completeness is the point. This started as three of
## the four on the theory that the largest surface wanted the quietest edge --
## which was a guess, and wrong in the direction that matters: with the cards
## drawn by hand and the frame around them cut by machine, the *mixture* is what
## the eye catches. One instrument drew the page or it did not.
##
## `FrontmostPanel` is the exception and cannot be otherwise: it dresses
## `PopupPanel`, which derives from `Window`, has no `CanvasItem` to draw
## through, and keeps its stylebox border for that reason.
const INKED_TIERS: Array[StringName] = [
	&"CardPanel", &"DashboardCard", &"InsetPanel", &"RaisedPanel",
	&"PrimaryAction", &"SecondaryAction", &"QuietAction", &"DangerAction",
	&"NavAction", &"ChoiceChip",
]

## Which of those get sewn rather than drawn.
##
## The surfaces, and not the controls -- which is a split with a claim behind it
## rather than a compromise between two treatments. **The page is sewn and the
## controls are written on it.** A card is a piece of worked cloth; a button is
## something somebody marked on it, and the two being made differently is what
## says which is which.
##
## It also settles where each treatment is weakest. A running stitch on a small
## control is a dashed border, which conventionally means *disabled*, and the
## smallest elements are the most numerous ones. A broad nib around a large
## panel is a heavy frame competing with its own contents. Sorting by size sorts
## both problems at once, and surface-versus-control is what size means here.
##
## `DashboardCard` is a `Button` and still belongs with the surfaces: it is a
## card that happens to be pressable, and it is the size of a card.
##
## The controls keep the nib, and gain a highlighter that is not there at rest.
## Hovering *is* the act of marking, so the wash sweeps on under the pointer and
## off again -- which puts the hover affordance in the page's own vocabulary
## instead of the instant colour swap it replaces.
const STITCHED_TIERS: Array[StringName] = [
	&"CardPanel", &"DashboardCard", &"InsetPanel", &"RaisedPanel",
]

## How far apart two patches can be in tone. Small: the surfaces should read as
## cut from related cloth, not as a colour-coded key.
const PATCH_TINT_SPREAD: float = 0.045

## The page is not a patch. `RaisedPanel` is the thing the patches are sewn
## *onto*, so tinting it shifts the whole sheet rather than one scrap -- and a
## whole-page colour shift reads as a theme bug, not as cloth.
##
## `DashboardCard` is here for a related reason found on the finished page. The
## six section cards do not sit on the sheet the way separate scraps do -- they
## are a *block* inside one card, six panes of the same cut, and giving each its
## own tone made the group read as six unrelated things that happen to be in a
## grid. Cut from one piece, they carry one colour and the stitching is what
## separates them, which is what a set of panels on a single patch looks like.
## Their stylebox takes the containing card's own fill for the same reason.
const UNTINTED_TIERS: Array[StringName] = [&"RaisedPanel", &"DashboardCard"]

const PRIMARY_ACTIONS := [
	"NewCareerButton", "NextButton", "CreateCareerButton", "AdvanceWeekButton",
	"PlayMatchButton", "CallPlayButton", "SavePlayButton", "ApplyTrainingButton",
	"SignButton", "LoadSelectedButton",
]
const QUIET_ACTIONS := [
	"CancelButton", "PreviousButton", "CloseButton", "TitleButton", "SaveButton",
	"CloseAttributeWheelButton", "ClosePlayerDossierButton", "ReplayButton",
]
const DANGER_ACTIONS := ["DeleteButton", "ExitButton"]


## Which medium a subtree is made of.
##
## The whole application used to be one: every screen got the sewn treatment,
## because the journal was the whole interface and the treatment *was* the
## interface. It is not any more. The desk has several objects on it and they are
## made of different things -- a journal is cloth and thread, a clipboard and a
## scouting folder are paper somebody drew on -- and giving all of them the same
## stitched edge says they are the same object seen twice.
##
## A screen declares its medium by setting `MEDIUM_META` on its root. The walk
## carries the nearest declaration downward, so a screen states it once.
##
## **Drawn is the default and sewn is the exception**, which is the way round
## that matters: a screen added later is plain until somebody decides it is part
## of the journal, rather than silently inheriting the journal's identity.
const MEDIUM_META := &"ui_medium"
## Cloth: a running stitch around every surface, no highlighter.
const MEDIUM_SEWN := &"sewn"
## Paper: a broad-nib pen edge, and controls that take a highlighter.
const MEDIUM_DRAWN := &"drawn"


static func apply(
	root: Node, light_mode: bool, medium: StringName = MEDIUM_DRAWN
) -> void:
	var subtree_medium := medium
	if root.has_meta(MEDIUM_META):
		subtree_medium = StringName(root.get_meta(MEDIUM_META))
	_style_node(root, light_mode, subtree_medium)
	for child in root.get_children():
		apply(child, light_mode, subtree_medium)


static func reveal(screen: Control) -> void:
	var resting_position := screen.position
	screen.modulate.a = 0.0
	screen.position = resting_position + Vector2(0.0, 10.0)
	var tween := screen.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(screen, "modulate:a", 1.0, 0.20)
	tween.tween_property(screen, "position", resting_position, 0.26)


static func _style_node(node: Node, light_mode: bool, medium: StringName) -> void:
	if node is PopupPanel:
		(node as PopupPanel).theme_type_variation = &"FrontmostPanel"
		## Not screened, and it cannot be: `PopupPanel` derives from `Window`, so
		## it is not a `CanvasItem` and has no material to draw itself through.
		## Its contents are ordinary panels and get the treatment on their own.
		return
	if node is ColorRect:
		_style_color_rect(node as ColorRect, light_mode)
	if not node is Control:
		return
	var control := node as Control
	## Opted out, and the escape hatch is deliberate.
	##
	## This pass strips *every* colour override in the tree on the theory that a
	## hand-set colour is legacy presentation the theme should own. That is right
	## for a label someone tinted once and forgot, and wrong for a colour that
	## carries meaning -- a grade band, a severity, a per-datum state. Those have
	## to be overrides, because a theme variation is per widget *kind* and the
	## whole point is that two identical widgets differ by their data.
	##
	## The roster's attribute band was the case that found this. Every value
	## carried its grade colour and every one was wiped and repainted the same
	## teal, because the labels are named "Value" and this file gives anything
	## containing "Value" the StatLabel variation. The numbers looked styled and
	## said nothing.
	##
	## The guard has to sit **above the strip**, not between the strip and the
	## variation. Placed below it, an exempt label still had its colours wiped
	## and merely avoided being repainted teal -- so whether the grade colours
	## survived came down to whether the roster happened to refill after the
	## styling pass ran, which is not a thing to leave to ordering.
	if control.has_meta("ui_style_exempt"):
		return
	_clear_legacy_presentation_overrides(control)
	if control is Button:
		_style_button(control as Button)
		_screen_surface(control, light_mode, medium)
	elif control is Label:
		_style_label(control as Label)
	elif control is PanelContainer:
		_style_panel(control as PanelContainer, medium)
		_screen_surface(control, light_mode, medium)
	elif control is RichTextLabel:
		control.theme_type_variation = &"BodyCopy"
		_paper_window(control)
	elif control is ItemList:
		control.theme_type_variation = &"DataList"
		_paper_window(control)
	elif control is ScrollContainer:
		## Deliberately bare.
		##
		## `_paper_window` threads a backing slip and a cut overlay onto a region
		## on the assumption that the region paints its own content -- true of an
		## `ItemList` or a `RichTextLabel`, whose text is drawn by the control
		## itself before its children draw. A `ScrollContainer`'s content *is*
		## child nodes, so the overlay is their sibling and draws straight over
		## them.
		##
		## That blanked the tactical planner: the whole editor column -- mode
		## switch, block strategy, floor system, serve targeting, every control
		## the planner exists for -- rendered underneath an opaque slip, leaving a
		## dark panel with a scrollbar. The training screen hit the same thing and
		## was patched locally with `ui_style_exempt`; this is the general fix, and
		## those local exemptions are now redundant rather than load-bearing.
		##
		## A scrolling region still reads as one: it sits inside a panel that is
		## already sewn, which is where the paper was coming from anyway.
		pass
	elif control is TabContainer:
		_paper_tabs(control as TabContainer)


static func _clear_legacy_presentation_overrides(control: Control) -> void:
	for property in control.get_property_list():
		var property_name := str(property.name)
		if property_name.begins_with("theme_override_colors/"):
			control.remove_theme_color_override(
				StringName(property_name.trim_prefix("theme_override_colors/"))
			)
		elif property_name.begins_with("theme_override_styles/"):
			control.remove_theme_stylebox_override(
				StringName(property_name.trim_prefix("theme_override_styles/"))
			)


## Lay the halftone screen over a surface, reading the tier the lines above just
## assigned to it.
##
## Deliberately after the variation rather than beside it, so there is exactly
## one place that decides what a panel *is* and this only asks. A tier with no
## entry in `UIHalftone.TIERS` clears the material instead of leaving whatever
## was there, because the style pass runs again on every theme switch and a
## surface that stops being screened has to actually stop.
static func _screen_surface(
	control: Control, light_mode: bool, medium: StringName
) -> void:
	control.material = UIHalftone.material_for(
		control.theme_type_variation, light_mode
	)
	_ink_surface(control, medium)
	_vary_patch_colour(control)


## No two patches are cut from the same scrap.
##
## A sewn panel is a piece of cloth somebody had, not a swatch from a system, so
## a row of six identical rectangles is the one thing that gives the whole
## metaphor away. The shift is small -- a few percent of hue and value -- because
## the point is that the surfaces are *not quite* the same rather than that they
## are different colours.
##
## `self_modulate` rather than a stylebox override, for two reasons: overrides
## are stripped by this same pass on the next run, and `modulate` would tint the
## card's contents along with the card.
static func _vary_patch_colour(control: Control) -> void:
	if not control.theme_type_variation in STITCHED_TIERS \
			or control.theme_type_variation in UNTINTED_TIERS:
		control.self_modulate = Color.WHITE
		return
	var seed_value := int(String(control.name).hash() & 0x7FFFFFFF)
	## Two independent draws from the same seed: one warms or cools the patch,
	## the other lightens or darkens it. Multiplied through `self_modulate`, so
	## they are shifts in the cloth rather than replacement colours.
	var warmth := (float(seed_value % 1000) / 1000.0 - 0.5) * PATCH_TINT_SPREAD
	var shade := (float((seed_value / 1000) % 1000) / 1000.0 - 0.5) \
		* PATCH_TINT_SPREAD * 0.5
	control.self_modulate = Color(
		1.0 + warmth - shade,
		1.0 - shade,
		1.0 - warmth - shade,
	)


## Give this surface a drawn edge, once.
##
## Added as a child rather than painted by the panel itself, because a
## `PanelContainer` draws its stylebox *under* its contents and an edge drawn
## there would be covered by whatever the card holds. The outline is marked
## exempt so the next style pass walks straight past it, and reused rather than
## recreated so repeated passes -- a theme switch, a resize -- do not stack
## twenty of them on one card.
static func _ink_surface(control: Control, medium: StringName) -> void:
	var wanted := control.theme_type_variation in INKED_TIERS
	var existing := control.get_node_or_null("InkOutline") as UIInkOutline
	if not wanted:
		if existing != null:
			existing.queue_free()
		return
	## Sewn only where the tier asks for it *and* the screen is made of cloth.
	## On a drawn page the same surface takes the pen edge instead, which is the
	## one alternative the ink system already has -- so the clipboard and the
	## folders read as paper without inventing a third treatment nobody has
	## finished designing.
	var sewn := medium == MEDIUM_SEWN \
		and control.theme_type_variation in STITCHED_TIERS
	var wanted_style := UIInkOutline.Stroke.STITCH if sewn \
		else UIInkOutline.Stroke.INK
	if existing != null:
		## Reassigned on every pass, not only at creation. The outline is reused
		## across theme switches and resizes, so a tier that changed treatment
		## would otherwise keep whichever one it was born with.
		existing.stroke_style = wanted_style
		existing.hover_highlight = not sewn
		existing.queue_redraw()
		return
	var outline := UIInkOutline.new()
	outline.name = "InkOutline"
	outline.stroke_style = wanted_style
	## Controls are written at rest and marked when pointed at: the nib draws the
	## word, and hovering is the act of going over it. Surfaces are sewn and get
	## neither.
	outline.hover_highlight = not sewn
	## Seeded from the panel's own name, so a card's edge is stable across runs
	## and two cards side by side never draw the same imperfection.
	outline.ink_seed = int(String(control.name).hash() & 0x7FFFFFFF)
	control.add_child(outline)


## A button that paints nothing and says nothing is not a control -- it is a
## region of the screen that happens to be clickable.
##
## The match centre found this the hard way. `OpenTacticalWorkspaceButton` is a
## flat, textless `Button` stretched over the whole 680x390 tactical preview so
## that clicking the court opens the full board. Classified by widget kind it is
## a `SecondaryAction` like any other, so it was given a nib outline round the
## entire court and a highlighter wash that swept over the court on hover. The
## tactical screen had become a highlighted button.
##
## The lesson is not that the button was too big. It is that "is a `Button`" and
## "is a control the reader is meant to see" are different questions, and this
## file was only ever asking the first. A hit area is transparent by
## construction -- `flat` means it draws no stylebox, and empty `text` with no
## icon means there is nothing written on it -- so there is nothing for a pen to
## outline and nothing for a marker to go over. It gets a tier of its own,
## outside every decorated list, and the pass leaves it alone.
static func _is_hit_area(button: Button) -> bool:
	return button.flat and button.text.is_empty() and button.icon == null


## Thread a scrolling region under the page, once.
##
## Added the same way the drawn edges are -- as an exempt child the next pass
## walks past, reused rather than recreated -- because it answers the same
## question about the same node and putting it anywhere else would mean two
## places deciding what a surface looks like.
static func _paper_window(control: Control) -> void:
	if control.get_node_or_null("PaperWindow") != null:
		return
	## Two nodes on the one parent. The slip is a different sheet from the card
	## it is threaded into, so something has to paint it -- and that something
	## must draw *before* the region's own text while the cuts and their shadows
	## draw *after* it. A `CanvasItem` gets one side of its parent or the other,
	## so this takes both.
	var slip := UIPaperWindowScript.new()
	slip.name = "PaperSlip"
	slip.backing = true
	control.add_child(slip)
	var window := UIPaperWindowScript.new()
	window.name = "PaperWindow"
	control.add_child(window)


## Cut the index tabs into a tab row, once.
##
## Parented to the `TabBar` rather than to the `TabContainer`, because only the
## bar knows where its tabs ended up -- `get_tab_rect` is on the bar, and the
## widths depend on the labels. The bar is a plain `Control`, so a full-rect
## child is not laid out by anything and simply lies on it.
static func _paper_tabs(tabs: TabContainer) -> void:
	var bar := tabs.get_tab_bar()
	if bar == null or bar.get_node_or_null("PaperTabs") != null:
		return
	var cut := UIPaperTabsScript.new()
	cut.name = "PaperTabs"
	bar.add_child(cut)


static func _style_button(button: Button) -> void:
	var node_name := String(button.name)
	if _is_hit_area(button):
		button.theme_type_variation = &"HitArea"
	elif node_name in PRIMARY_ACTIONS:
		button.theme_type_variation = &"PrimaryAction"
	elif node_name in DANGER_ACTIONS:
		button.theme_type_variation = &"DangerAction"
	elif node_name in QUIET_ACTIONS:
		button.theme_type_variation = &"QuietAction"
	elif node_name.ends_with("Nav"):
		## The section buttons live *on the tape*, which is why they get a tier
		## of their own rather than sharing the strip's.
		##
		## Neither control treatment belongs there. A highlighter sweep over a
		## steel rule is nonsense -- nobody goes over a tape measure with a
		## marker -- and a stitched edge is worse, since the whole reason the
		## drawer became a tape is that cloth cannot extend. `TapeAction` sits
		## outside `INKED_TIERS`, so it gets no outline, no wash and no seam: a
		## label printed on the rule.
		##
		## It is also the tier that makes the tape *thinner than its case*. The
		## drawer can never be shorter than these buttons demand, so their
		## content margins are what actually set its height.
		button.theme_type_variation = &"TapeAction"
	elif node_name == "CurrentSectionButton":
		## The menu button is not a button with a tape measure next to it -- it
		## *is* the case the tape comes out of, drawn by `UITapeMeasure` under
		## its own label. So it takes `TapeAction`'s dark-on-yellow lettering and
		## nothing else: no box, no outline, no wash. See `HIT_AREA` below for
		## why a control being large is not a reason to stop treating it as one;
		## this is the other half of that -- a control that is an *object* rather
		## than a written word, and objects are not marked with a highlighter.
		button.theme_type_variation = &"TapeCase"
	elif node_name == "ThemeToggle":
		button.theme_type_variation = &"NavAction"
	elif button.has_method("set_summary") or node_name.ends_with("Card"):
		## Matched on what the button *is*, not on what the scene file called it.
		##
		## This read `node_name == "DashboardCard"`, which is the name of the root
		## node inside `dashboard_card.tscn` -- and an instanced scene takes the
		## name its parent gives it. Every card on the dashboard is called
		## `RosterCard`, `TeamCard`, `ClubCard` and so on, so the condition never
		## fired once and all seven rendered as ordinary secondary buttons. The
		## `DashboardCard` variation is defined in both themes and had never been
		## reachable.
		button.theme_type_variation = &"DashboardCard"
	elif button.toggle_mode:
		button.theme_type_variation = &"ChoiceChip"
	else:
		button.theme_type_variation = &"SecondaryAction"


static func _style_label(label: Label) -> void:
	var node_name := String(label.name)
	if node_name in ["Title", "RailTitle", "QuestionTitle", "OrganizationLabel"] \
			or node_name.ends_with("ScreenTitle"):
		label.theme_type_variation = &"DisplayHeading"
		label.rotation_degrees = -1.0 if node_name.length() % 2 == 0 else 0.8
	elif node_name.ends_with("Title") or node_name in ["SectionTitle", "CaptionLabel"]:
		label.theme_type_variation = &"SectionHeading"
	elif node_name.contains("Kicker") or node_name.contains("Eyebrow") \
			or node_name in ["Edition", "Mark", "Prompt", "ModeLabel"]:
		label.theme_type_variation = &"EyebrowLabel"
		label.rotation_degrees = -0.7 if node_name.length() % 2 == 0 else 0.7
	elif node_name.contains("Status") or node_name.contains("Score") \
			or node_name.contains("Date") or node_name.contains("Value"):
		label.theme_type_variation = &"StatLabel"
	elif node_name.contains("Hint") or node_name.contains("Summary") \
			or node_name.contains("Detail") or node_name.contains("Context"):
		label.theme_type_variation = &"MutedLabel"


static func _style_panel(panel: PanelContainer, medium: StringName) -> void:
	var node_name := String(panel.name)
	if node_name in ["ContentPanel", "QuestionPanel", "MenuPanel"]:
		panel.theme_type_variation = &"RaisedPanel"
	elif node_name.ends_with("Strip") or node_name.ends_with("Bar") \
			or node_name == "DropdownPanel":
		## A bar is where a control lives, not a surface in its own right.
		##
		## `NavStrip` holds one button and a line of hint text, and drawing an
		## edge around it put a second pen line 12 px outside the button's own --
		## the doubled-line problem again, arriving from the opposite direction
		## this time. The button has to keep its edge, because the edge is what
		## says it can be pressed; so the wrapper gives up its own.
		##
		## Matched on the suffix rather than on the one node that has the problem,
		## because the mistake is structural -- a panel whose only content is a
		## control -- and the next one will be named the same way.
		##
		## `DropdownPanel` joins them for a different reason: it is the section
		## drawer, and the drawer's surface is a tape measure drawn underneath
		## it. A sewn panel over a tape would be two surfaces claiming the same
		## rectangle -- and a stitched thing that extends is the contradiction
		## the tape exists to resolve.
		panel.theme_type_variation = &"BareRegion"
	elif node_name.contains("Preview") or node_name.contains("News") \
			or node_name.contains("Placeholder"):
		panel.theme_type_variation = &"InsetPanel"
	else:
		panel.theme_type_variation = &"CardPanel"


static func _style_color_rect(rect: ColorRect, light_mode: bool) -> void:
	var node_name := String(rect.name)
	if node_name in ["Background", "Backdrop"]:
		rect.color = UIPalette.color(&"canvas", light_mode)
	elif node_name in ["CourtBand"]:
		rect.color = UIPalette.color(&"canvas_alt", light_mode)
	elif node_name in ["AccentBar", "AccentBand"]:
		rect.color = UIPalette.color(&"accent", light_mode)
	elif node_name.contains("Underlay"):
		rect.color = UIPalette.color(&"scrim", light_mode)
	elif node_name.contains("Rule"):
		rect.color = UIPalette.color(&"accent_alt", light_mode)
