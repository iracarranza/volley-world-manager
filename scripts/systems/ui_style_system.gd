class_name VolleyballUIStyleSystem
extends RefCounted

const UIPalette := preload("res://scripts/data/ui_palette.gd")
const UIHalftone := preload("res://scripts/data/ui_halftone.gd")
const UICardStock := preload("res://scripts/data/ui_card_stock.gd")
const UIInkOutline := preload("res://scenes/components/ink_outline.gd")
const UICreasedEdge := preload("res://scenes/components/creased_edge.gd")
const UIPaperWindowScript := preload("res://scenes/components/paper_window.gd")
const UIPaperTabsScript := preload("res://scenes/components/paper_tabs.gd")
const UIPlasticTabsScript := preload("res://scenes/components/plastic_tabs.gd")
const UIPrintedRuleScript := preload("res://scenes/components/printed_rule.gd")

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
## A printed form: no screen, flat stock, hairline rules, and a hand only where
## somebody added one. See `UIPrintedRule` for why this is a medium rather than
## another border -- "drawn" turned out to be the journal with a different edge,
## which is why the clipboard read as the journal.
const MEDIUM_FORM := &"form"
## Melamine: a wall-mounted board that was written on minutes ago. It shares
## exactly one property with a printed form -- no halftone screen -- and every
## other property is its own, which is why it is a fourth medium rather than a
## fourth branch inside `MEDIUM_FORM`. `docs/design/THE_TACTICAL_WHITEBOARD.md`
## says so explicitly, and building it off the form is the named way to
## reproduce the defect that made the clipboard read as the journal.
const MEDIUM_BOARD := &"board"
## Manila card: the scouting folders. `TITLE_SCREEN.md` has said "the folders are
## card" since the medium rule was first written down, and until now there was no
## `card` -- so the folders fell through to `drawn` and the scouting screen was
## the planner with different words on it.
##
## It is the only medium whose surface texture is the **material** rather than
## something done to the material: the journal's halftone is a reproduction, the
## form and the board are manufactured featureless, and manila is unbleached pulp
## with the fibre still in it. Its edges are a fold and three cut sides rather
## than a border of any kind, and the one instrument allowed on it is a pencil.
## `UICreasedEdge` and `UICardStock` carry those two claims respectively.
const MEDIUM_CARD := &"card"


static func apply(
	root: Node, light_mode: bool, medium: StringName = MEDIUM_DRAWN
) -> void:
	var subtree_medium := medium
	if root.has_meta(MEDIUM_META):
		subtree_medium = StringName(root.get_meta(MEDIUM_META))
	_style_node(root, light_mode, subtree_medium)
	for child in root.get_children():
		apply(child, light_mode, subtree_medium)


## Where a revealed screen comes to rest, and the tween carrying it there.
##
## Both remembered on the screen itself, because `reveal` is static and a screen
## can be revealed again before the last one has finished.
const REVEAL_HOME := &"ui_reveal_home"
const REVEAL_TWEEN := &"ui_reveal_tween"
const REVEAL_RISE: float = 10.0
const REVEAL_FADE_SECONDS: float = 0.20
const REVEAL_TRAVEL_SECONDS: float = 0.26


## The incoming screen lifting into place.
##
## **The screen must end up visible even if this animation never runs.** What was
## here set `modulate.a = 0.0` outright and relied on a tween to bring it back, so
## any way the tween could fail to finish -- killed by a second reveal, the node
## leaving the tree mid-flight -- left a screen that is present, laid out and
## fully clickable while being completely transparent. That does not look like a
## bug in an animation. It looks like the game has frozen: the page is there, the
## mouse works, and nothing on screen ever responds.
##
## So the fade is expressed as `.from(0.0)` rather than as an assignment. The
## property's *final* value is the tween's business and is 1.0 by construction;
## the starting value is only applied once the tween actually begins. A reveal
## that never runs now degrades to a screen that simply appears, which is the
## right failure.
##
## The resting position gets the same treatment for a different reason. It used
## to be read off `screen.position` at call time -- but a screen revealed twice in
## quick succession is sampled mid-flight, so "home" became home plus whatever the
## last animation had not finished travelling, and the page crept down the window
## a few pixels per visit. It is recorded once and reused.
static func reveal(screen: Control) -> void:
	## Guarded with `has_meta` rather than `get_meta(key, default)`, which pushes an
	## error for a missing key even when handed a default -- and an error per screen
	## change is exactly the kind of noise that hides a real one.
	if screen.has_meta(REVEAL_TWEEN):
		var running: Variant = screen.get_meta(REVEAL_TWEEN)
		if running is Tween and (running as Tween).is_valid():
			(running as Tween).kill()
	var home := screen.position
	if screen.has_meta(REVEAL_HOME):
		home = Vector2(screen.get_meta(REVEAL_HOME))
	screen.set_meta(REVEAL_HOME, home)
	## Killing a tween leaves the property wherever it stopped, so the previous
	## reveal is finished by hand before the next one starts from a known place.
	screen.modulate.a = 1.0
	screen.position = home
	var tween := screen.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		screen, "modulate:a", 1.0, REVEAL_FADE_SECONDS
	).from(0.0)
	tween.tween_property(
		screen, "position", home, REVEAL_TRAVEL_SECONDS
	).from(home + Vector2(0.0, REVEAL_RISE))
	screen.set_meta(REVEAL_TWEEN, tween)


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
	## A printed form is not screened. The halftone is the journal's own
	## substrate -- a scrapbook of screened reproductions -- and carrying it onto
	## the clipboard was most of why the two objects looked identical. Office
	## paper is flat; what varies across it is the print, not the stock.
	## Neither a form nor a board is screened, and they get there for different
	## reasons: office stock is flat because it is bleached pulp, and melamine is
	## flat because it is plastic. Written as two names rather than one condition
	## so that a change to one does not silently move the other.
	## Card is neither screened nor bare: it has a texture and the texture is not a
	## print. Handled as its own branch rather than as a third name in
	## `unscreened`, because "not screened" is a statement about ink and this is a
	## statement about pulp -- the two happen to agree that the halftone is wrong
	## here and agree about nothing else.
	var unscreened := medium == MEDIUM_FORM or medium == MEDIUM_BOARD
	if medium == MEDIUM_CARD:
		control.material = UICardStock.material_for(
			control.theme_type_variation, light_mode
		)
	else:
		control.material = null if unscreened \
			else UIHalftone.material_for(control.theme_type_variation, light_mode)
	_ink_surface(control, medium)
	_vary_patch_colour(control, medium)
	_stock_colour(control, medium)


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
## What the sheet is made of.
##
## The journal's page is warm cream that has been sitting in a book. Office
## stock is bleached, cooler and a little brighter, and the difference between
## the two is legible the moment they are not on the same screen -- which is
## the test the clipboard was failing.
##
## Applied through `self_modulate` so it multiplies the theme's own surface
## rather than replacing it, which keeps both themes working from one number:
## Molten's cream cools toward white, Mikasa's slate cools toward blue-grey, and
## neither needs a second palette.
const FORM_STOCK_LIGHT := Color(1.045, 1.045, 1.055)
const FORM_STOCK_DARK := Color(0.93, 0.96, 1.02)

## Melamine, which is neither paper nor cloth.
##
## Cooler than office stock and very slightly green, because a whiteboard is a
## plastic surface under room light rather than a bleached one -- the green is
## small enough that nobody names it and large enough that the board does not
## read as a sheet of paper. Slightly darker than the form in the light theme
## too: paper is the brightest thing on a desk and a board on a wall is not.
const BOARD_STOCK_LIGHT := Color(0.985, 1.005, 1.0)
const BOARD_STOCK_DARK := Color(0.90, 0.95, 0.965)

## Manila, which is the one stock on the desk that is a *colour* rather than an
## absence of one.
##
## The journal's cream, the office sheet and the whiteboard are all near-neutral
## and separate from each other by a percent or two of hue. Card is not: it is
## buff, and it is buff because it was never bleached. So this is the largest
## stock shift of the four by an order of magnitude, and it has to be -- a folder
## that reads as slightly-warm paper is a sheet of paper.
##
## Darker as well as warmer in the light theme, which is the half that is easy to
## miss. Paper is the brightest thing on a desk; card is heavier and duller and
## sits visibly below it, and a manila folder rendered at paper's brightness
## reads as a yellow highlight rather than as a different material.
##
## **The dark multiplier is large and it has to be.** `self_modulate` multiplies,
## and Mikasa's surfaces are blue -- `surface` is `#10283a`, whose blue channel is
## three and a half times its red. A gentle warm nudge of the kind the form and
## the board take leaves a blue panel that is very slightly less blue, which is
## what the first dark render showed: a drawer of slate folders. Getting to
## manila from a blue ground means most of the blue has to go and the red has to
## roughly quadruple. Checked against all three surface tiers rather than one:
## `#10283a` lands at `#3c3322`, `surface_raised` at `#56472c`, `surface_inset`
## at `#1a140f` -- a related family of warm browns, which is what a drawer of
## card in a dim room is.
const CARD_STOCK_LIGHT := Color(1.02, 0.955, 0.845)
const CARD_STOCK_DARK := Color(3.75, 1.275, 0.586)


static func _stock_colour(control: Control, medium: StringName) -> void:
	if medium != MEDIUM_FORM and medium != MEDIUM_BOARD and medium != MEDIUM_CARD:
		return
	var light := UIPalette.control_is_light(control)
	## **Card stocks the controls too, and the other two media do not.**
	##
	## On a form or a board the surface is one material and the controls are
	## something a hand added to it, so only the surfaces take the stock. A folder
	## has no such split: a tab is a piece of the same sheet, folded over. Leaving
	## the buttons out gave the first render a drawer of manila folders with slate
	## tabs on them, which is a thing that does not exist.
	if medium == MEDIUM_CARD:
		if UICardStock.TIERS.has(control.theme_type_variation):
			var stock := CARD_STOCK_LIGHT if light else CARD_STOCK_DARK
			control.self_modulate = stock
			_uncolour_text(control, stock)
		return
	if not control.theme_type_variation in STITCHED_TIERS:
		return
	if medium == MEDIUM_BOARD:
		control.self_modulate = BOARD_STOCK_LIGHT if light else BOARD_STOCK_DARK
		return
	control.self_modulate = FORM_STOCK_LIGHT if light else FORM_STOCK_DARK


## Divide the stock back out of a button's lettering.
##
## `self_modulate` tints everything a control draws *itself*, and a `Button` draws
## its own text. That is harmless for a panel, which draws only a stylebox, and it
## is not harmless here: Mikasa's manila multiplier is `(3.75, 1.275, 0.586)`, so
## the white it was applied to came out `(1.0, 1.0, 0.586)` and every word on the
## scouting screen turned yellow -- tabs, marks and all, which also erased the
## pressed state that says which mark is set.
##
## The fix is arithmetic rather than a second colour system. Each font colour is
## divided by the stock before the stock multiplies it back, so the lettering
## lands exactly where the theme put it while the stock still colours the card.
## Components above one are fine and are the whole mechanism: `1.0 / 0.586` is
## `1.71`, and `1.71 * 0.586` is white again.
##
## Set as overrides, which this same pass strips at the top of every run -- so
## they are recomputed rather than accumulated, and a control that stops being
## card gets its own colours back on the next pass rather than keeping a division
## by a stock it no longer has.
const CARD_TEXT_COLOURS: Array[StringName] = [
	&"font_color", &"font_pressed_color", &"font_hover_color",
	&"font_focus_color", &"font_disabled_color",
]


static func _uncolour_text(control: Control, stock: Color) -> void:
	if not control is Button:
		return
	for key in CARD_TEXT_COLOURS:
		if not control.has_theme_color(key):
			continue
		var colour := control.get_theme_color(key)
		control.add_theme_color_override(key, Color(
			colour.r / maxf(stock.r, 0.001),
			colour.g / maxf(stock.g, 0.001),
			colour.b / maxf(stock.b, 0.001),
			colour.a,
		))


static func _vary_patch_colour(control: Control, medium: StringName) -> void:
	## Every sheet in the pad came off the same press. The per-patch tint is the
	## journal's rule -- "no two patches from the same scrap" -- and it is exactly
	## backwards for a form, where identical is the point.
	## A board is one wiped surface. Tinting each panel differently would say the
	## page was assembled from scraps, which is the journal's fact and not this
	## object's.
	## A box of folders is a box of folders. They vary in how grubby they are, not
	## in what they are cut from, and the journal's per-scrap tint would say a
	## manager assembled their filing out of found card.
	if medium == MEDIUM_FORM or medium == MEDIUM_BOARD or medium == MEDIUM_CARD:
		return
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
	## A printed form takes neither the stitch nor the pen. Its divisions came off
	## a press, so they are hairlines with square corners and no hand in them at
	## all -- which is what leaves the marker, the red pen and the highlighter as
	## the only human marks on the object.
	if medium == MEDIUM_FORM:
		if existing != null:
			existing.queue_free()
		_creased_edge(control, false)
		_printed_rule(control)
		return
	var printed := control.get_node_or_null("PrintedRule")
	if printed != null:
		printed.queue_free()
	## A folder takes neither. It has no border at all: the fold and the three cut
	## sides *are* the edge, and they are geometry rather than a mark. Handled
	## before the stroke choice below because there is no stroke to choose -- a
	## `card` surface that fell through to the `else` would take the pen, which is
	## the exact shape of the mistake that made the clipboard read as the journal.
	if medium == MEDIUM_CARD:
		if existing != null:
			existing.queue_free()
		_creased_edge(control, true)
		return
	_creased_edge(control, false)
	## **A board takes no highlighter.**
	##
	## `hover_highlight` sweeps a translucent highlighter band -- see
	## `UIInkOutline._highlighter_ink` -- which is a piece of paper stationery,
	## and the whiteboard's whole vocabulary is four markers and magnets. Cloth
	## already declines it because you do not highlight a sewn patch; melamine
	## declines it for a different reason and both are stated rather than one
	## being folded into the other.
	var highlighted := medium != MEDIUM_SEWN and medium != MEDIUM_BOARD
	var sewn := medium == MEDIUM_SEWN \
		and control.theme_type_variation in STITCHED_TIERS
	## A board's divisions are drawn in marker, edge to edge. Not a border it was
	## manufactured with -- everything on a whiteboard was put there by hand,
	## minutes ago, which is the whole of what separates it from the printed form
	## it otherwise resembles in being unscreened.
	var wanted_style := UIInkOutline.Stroke.STITCH if sewn \
		else (
			UIInkOutline.Stroke.MARKER if medium == MEDIUM_BOARD
			else UIInkOutline.Stroke.INK
		)
	if existing != null:
		## Reassigned on every pass, not only at creation. The outline is reused
		## across theme switches and resizes, so a tier that changed treatment
		## would otherwise keep whichever one it was born with.
		existing.stroke_style = wanted_style
		existing.hover_highlight = highlighted
		existing.queue_redraw()
		return
	var outline := UIInkOutline.new()
	outline.name = "InkOutline"
	outline.stroke_style = wanted_style
	## Controls are written at rest and marked when pointed at: the nib draws the
	## word, and hovering is the act of going over it. Surfaces are sewn and get
	## neither.
	outline.hover_highlight = highlighted
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
## The press rule for one surface, added once. `gridded` only for the panels big
## enough to be a sheet -- a button is a printed box on the form, not a form.
## The fold and the cut sides, added once, removed the moment the medium changes.
##
## Same shape as `_printed_rule` and `_ink_surface` -- an exempt child, reused
## across passes rather than restacked -- because it answers the same question
## about the same node.
##
## The `wanted` flag is what makes it removable. A screen can be restyled into a
## different medium at runtime (the theme switch reruns this whole pass), and an
## edge component that only ever adds itself would leave a folder's crease drawn
## down the side of a clipboard.
static func _creased_edge(control: Control, wanted: bool) -> void:
	var existing := control.get_node_or_null("CreasedEdge") as UICreasedEdge
	if not wanted:
		if existing != null:
			## Detached before it is freed, not merely queued.
			##
			## `queue_free` runs at the end of the frame, so a node freed that way
			## is still a child -- and still *drawing* -- for the rest of the pass
			## that removed it. Since a theme switch reruns this whole walk
			## synchronously, a surface that changed medium would draw one more
			## frame with both its old edge and its new one. Removing first makes
			## the tree honest the moment the decision is made.
			control.remove_child(existing)
			existing.queue_free()
		return
	## Only the surfaces are folded sheets. A control is a *tab* -- a smaller
	## piece of the same card -- and a tab is not folded on its long side, so it
	## gets the cut edges and the pencil and no crease.
	var surface := control.theme_type_variation in STITCHED_TIERS
	if existing != null:
		existing.fold = UICreasedEdge.Fold.LEFT if surface else UICreasedEdge.Fold.NONE
		existing.pencil_hover = not surface
		existing.queue_redraw()
		return
	var edge := UICreasedEdge.new()
	edge.name = "CreasedEdge"
	edge.fold = UICreasedEdge.Fold.LEFT if surface else UICreasedEdge.Fold.NONE
	edge.pencil_hover = not surface
	edge.pencil_seed = int(String(control.name).hash() & 0x7FFFFFFF)
	control.add_child(edge)


static func _printed_rule(control: Control) -> void:
	var existing := control.get_node_or_null("PrintedRule") as UIPrintedRule
	var wants_grid := control.theme_type_variation in [
		&"CardPanel", &"DashboardCard", &"InsetPanel",
	]
	if existing != null:
		existing.gridded = wants_grid
		control.move_child(existing, 0)
		existing.queue_redraw()
		return
	var rule := UIPrintedRuleScript.new()
	rule.name = "PrintedRule"
	rule.gridded = wants_grid
	control.add_child(rule)
	## **Under** the panel's content, not over it.
	##
	## Added last, it drew last, so a card's layout grid was printed *on top of*
	## whatever the card held. Mostly invisible -- until a surface arrived with a
	## grid of its own. The tactic sheet is squared paper at 13 px and the card
	## behind it is ruled at 22, and the two together came out as pairs of lines
	## with irregular gaps: measured at y=300, one series at exactly 13.0 px and a
	## second at exactly 22.0 px interleaved through it. Neither grid was wrong.
	## There were two of them.
	##
	## A press prints the grid on the stock and then things are placed on it, which
	## is what index 0 means here.
	control.move_child(rule, 0)


static func _paper_tabs(tabs: TabContainer) -> void:
	var bar := tabs.get_tab_bar()
	if bar == null:
		return
	## Which material this row's dividers are. Cut paper is the journal's, and
	## the default -- it followed the tab row everywhere by inheritance. A screen
	## that is a different object says so, the same way the medium meta does for
	## surfaces.
	var plastic := StringName(tabs.get_meta(&"ui_tabs", &"paper")) == &"plastic"
	var existing := bar.get_node_or_null("PlasticTabs" if plastic else "PaperTabs")
	if existing != null:
		return
	var stale := bar.get_node_or_null("PaperTabs" if plastic else "PlasticTabs")
	if stale != null:
		stale.queue_free()
	var cut: Control = UIPlasticTabsScript.new() if plastic \
		else UIPaperTabsScript.new()
	cut.name = "PlasticTabs" if plastic else "PaperTabs"
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
