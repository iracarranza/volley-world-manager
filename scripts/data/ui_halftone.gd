class_name UIHalftone
extends RefCounted

## Which surfaces get screened, and how heavily.
##
## The tiers are the panel variations the style system already assigns, so this
## adds a second reading of an existing decision rather than a second decision.
## A panel that is a card in the theme is a card here, and there is no way for
## the two to disagree about what something is.
##
## Elevation is carried by *density*, and it runs the opposite way to intuition:
## the recessed surface is screened most. That is how ink works -- a well is
## darker because more of it is covered -- and it is why this can replace a drop
## shadow without introducing a light source.

const UIPalette := preload("res://scripts/data/ui_palette.gd")
const SHADER := preload("res://scenes/themes/halftone_surface.gdshader")

## period, radius, strength -- per elevation tier.
##
## The raised tier is deliberately close to nothing. A panel that sits nearest
## the reader should read as the cleanest surface on screen, and screening it as
## hard as a well is what makes a halftone treatment look like a texture someone
## applied to everything rather than a system.
##
## The strengths look high for a treatment meant to be subtle, and they are not.
## The dark theme screens a surface back toward its own canvas and those two
## colours are close, so a tenth of the way between them is invisible on a
## screen -- which is exactly what the first pass shipped. Read these as "how
## far toward the canvas", not as opacity.
const TIERS := {
	&"InsetPanel": {"period": 5.0, "radius": 0.34, "strength": 0.42},
	&"CardPanel": {"period": 6.0, "radius": 0.29, "strength": 0.30},
	&"DashboardCard": {"period": 6.0, "radius": 0.27, "strength": 0.26},
	&"RaisedPanel": {"period": 7.5, "radius": 0.24, "strength": 0.17},
	## Buttons screen finer and lighter than the surfaces they sit on.
	##
	## A control is nearer the reader than the card holding it, and dot density
	## is this interface's only depth cue -- a button screened at a card's weight
	## reads as a hole in the card rather than as something resting on it. The
	## primary action is screened lightest of all, because it is the nearest
	## thing on the page and the one the eye is meant to land on first.
	&"SecondaryAction": {"period": 4.5, "radius": 0.24, "strength": 0.20},
	&"QuietAction": {"period": 4.5, "radius": 0.24, "strength": 0.16},
	&"NavAction": {"period": 4.5, "radius": 0.24, "strength": 0.16},
	&"ChoiceChip": {"period": 4.5, "radius": 0.23, "strength": 0.18},
	&"DangerAction": {"period": 4.5, "radius": 0.25, "strength": 0.22},
	&"PrimaryAction": {"period": 4.0, "radius": 0.22, "strength": 0.13},
}

## `FrontmostPanel` is absent on purpose. It is the variation given to
## `PopupPanel`, which derives from `Window` rather than `CanvasItem` and
## therefore has no material to draw itself through at all. Listing it here
## would be a tier that silently never applies.

## The angle is shared by every tier, and that is the point: one screen laid over
## the whole interface, not a per-panel effect. Two panels at different angles
## read as two printings.
const SCREEN_ANGLE_DEGREES: float = 15.0

## The strengths above are the dark theme's, and the light theme cannot use them.
##
## `strength` is "how far toward the tint", so what it *looks* like depends on
## how far away the tint already is. Dark screens `surface` (#10283a) toward
## `canvas` (#08131f) -- a luminance gap of about 0.07. Light screens `surface`
## (#fffaf0) toward `ink_muted` (#4e6b64), a gap of about 0.83, twelve times
## wider. The same number therefore prints a whisper on one theme and a weave on
## the other, which is what the first render showed.
##
## Not solved to equal effective delta, because that lands at 0.025 and is
## invisible -- perceived texture is not linear in luminance and a dark surface
## hides a screen better than a pale one reveals it. Set by eye against both
## renders instead, and recorded as such rather than dressed up as derived.
const LIGHT_SCALE: float = 0.55

## Built once per tier and theme and handed out by reference.
##
## A `ShaderMaterial` per panel would recompile nothing but would multiply the
## draw-call state changes by the number of cards on screen, and the dashboard
## puts a dozen up at once. Keyed by tier *and* theme because the tint differs.
static var _cache: Dictionary = {}

## The window height the screen was sized against.
##
## 720, because that is what every render used while the tiers were being tuned.
## The dot period is in pixels, so without this the print gets proportionally
## finer as the window grows and vanishes at fullscreen -- reported from the app,
## and the sort of thing a fixed-size preview harness can never show.
const REFERENCE_VIEWPORT_HEIGHT: float = 720.0

## Applied to every cached material, and remembered so materials built later in
## the session start at the right size rather than at 1.0.
static var _viewport_scale: float = 1.0


## Resize the screen for a window of this height.
static func set_viewport_height(height: float) -> void:
	var scale := clampf(
		maxf(height, 1.0) / REFERENCE_VIEWPORT_HEIGHT, 0.25, 4.0
	)
	if is_equal_approx(scale, _viewport_scale):
		return
	_viewport_scale = scale
	for material in _cache.values():
		(material as ShaderMaterial).set_shader_parameter("viewport_scale", scale)


## The material this surface should draw itself through, or null if the tier is
## not screened. Callers assign it to `CanvasItem.material`, which applies to the
## node's own drawing only -- children keep their own materials, so a card's
## labels are not screened along with its panel.
static func material_for(tier: StringName, light_mode: bool) -> ShaderMaterial:
	if not TIERS.has(tier):
		return null
	var key := "%s:%s" % [tier, "light" if light_mode else "dark"]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var settings: Dictionary = TIERS[tier]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("period", float(settings.period))
	material.set_shader_parameter("radius", float(settings.radius))
	material.set_shader_parameter(
		"strength",
		float(settings.strength) * (LIGHT_SCALE if light_mode else 1.0),
	)
	material.set_shader_parameter("angle_degrees", SCREEN_ANGLE_DEGREES)
	material.set_shader_parameter("tint", tint(light_mode))
	material.set_shader_parameter("viewport_scale", _viewport_scale)
	_cache[key] = material
	return material


## What the dots are made of.
##
## The dark theme screens with its own canvas colour rather than with black,
## because a surface is *lifted off* the canvas and screening it back toward the
## canvas is what depth means here. The light theme screens with muted ink, which
## on warm paper reads as the grain of the stock rather than as a grey wash --
## and warm-on-warm is the case the light theme has always been at risk of losing
## separation in.
static func tint(light_mode: bool) -> Color:
	## Dark screens *upward*, toward `stroke`, so the dots lift off the surface
	## rather than sinking into it.
	##
	## They used to tint toward `canvas`, on the reasoning that a surface is
	## lifted off the canvas and screening it back toward the canvas is what
	## depth means. That is sound and it is invisible: `surface` #10283a against
	## `canvas` #08131f is a luminance gap of about 0.07, so even at a strength of
	## 0.30 the print could not be seen without being told it was there -- which
	## is exactly how it was reported.
	##
	## Lighter ink on a dark ground is also the more honest reference. A screen
	## print on dark stock is laid *on top* in a lighter colour; nothing about the
	## craft this is imitating involves printing shadow.
	return UIPalette.color(&"ink_muted", true) if light_mode \
		else UIPalette.color(&"stroke", false)


## Dropped whenever the theme changes, because every cached material carries a
## tint for the theme it was built under. Reusing them across a switch is the
## "correct, then clobbered" failure with a longer fuse: the panels would keep
## the previous theme's screen and nothing would look broken enough to notice.
static func clear_cache() -> void:
	_cache.clear()
