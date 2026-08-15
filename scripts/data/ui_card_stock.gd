class_name UICardStock
extends RefCounted

## What a folder is made of.
##
## `UIHalftone`'s twin, and deliberately a separate file rather than a fifth
## branch inside it. The halftone answers *how heavily is this surface screened*,
## which is a question about print. This answers *what stock was this cut from*,
## which is a question about material. Folding them together would have made
## "screened" and "flecked" two settings of one thing, and they are not: the
## journal is a reproduction and a folder is a raw sheet.
##
## The tiers are the same panel variations the style system already assigns, for
## the same reason they are there -- so a card in the theme is a card here and
## there is no second opinion about what something is.

const UIPalette := preload("res://scripts/data/ui_palette.gd")
const SHADER := preload("res://scenes/themes/card_fibre.gdshader")

## grain, density, strength -- per elevation tier.
##
## Elevation runs the same way it does in the halftone and for a different
## reason. There it is dot density standing in for depth. Here a recessed surface
## is a folder seen *through* the ones in front of it, so more of its fleck is in
## shadow and more of it reads -- which lands on the same ordering by a different
## route, and is worth stating so that nobody "unifies" the two later.
##
## **The grain is one pixel, and it started at two.**
##
## The first render put a six-by-two dash on the stock every few pixels, which is
## the §0 failure in its usual dress: a texture measured at the wrong scale does
## not read as a subtler version of itself, it reads as a different thing. Fibre
## you can pick out individually is confetti.
const TIERS := {
	&"InsetPanel": {"grain": 1.0, "density": 0.18, "strength": 0.30},
	&"CardPanel": {"grain": 1.0, "density": 0.15, "strength": 0.24},
	&"DashboardCard": {"grain": 1.0, "density": 0.15, "strength": 0.22},
	&"RaisedPanel": {"grain": 1.1, "density": 0.13, "strength": 0.16},
	## A control on a folder is a *tab* -- a smaller piece of the same card,
	## folded over. It is the same stock at the same grain, which is the whole
	## point: on the journal a button is written on the page and is therefore a
	## different material from it, and on a folder it is not.
	&"SecondaryAction": {"grain": 1.0, "density": 0.14, "strength": 0.20},
	&"QuietAction": {"grain": 1.0, "density": 0.14, "strength": 0.17},
	&"NavAction": {"grain": 1.0, "density": 0.14, "strength": 0.17},
	&"ChoiceChip": {"grain": 1.0, "density": 0.14, "strength": 0.18},
	&"DangerAction": {"grain": 1.0, "density": 0.15, "strength": 0.21},
	&"PrimaryAction": {"grain": 1.0, "density": 0.13, "strength": 0.15},
}

## Same asymmetry the halftone documents, arrived at the same way. `strength` is
## "how far toward the speck colour", and on the light theme the speck is a long
## way from warm buff while on the dark theme it is not. One number cannot print
## the same on both, so the light theme is scaled and the scale is set by eye
## against both renders rather than solved to an equal luminance delta -- which
## lands at a value too small to see, for the reasons `UIHalftone.LIGHT_SCALE`
## sets out at length.
const LIGHT_SCALE: float = 0.62

## And the dark theme is scaled *down* from the tier numbers, which are written
## for paper-bright stock.
##
## Mikasa's card is a dark warm brown, and the pale speck is the one that hurts
## there: a light fleck on a dark ground is the highest-contrast thing on the
## page, so the first dark render read as a woven mat rather than as card. Both
## specks come down and the pale one comes down further.
const DARK_SCALE: float = 0.45
const DARK_PALE_SCALE: float = 0.3

## Card stock is warm in both themes, because a folder in a dim room is still
## buff -- it is not a grey object.
##
## **Both themes' specks are darker than the stock, which is the opposite of the
## halftone's rule.** A halftone dot on a dark ground has to be lighter, because
## screen ink is laid *on top* of the stock and nothing about printing involves
## laying down shadow. A fibre is not laid on anything: it is a piece of bark
## inside the sheet, and a piece of bark is dark under any light in the room. So
## the dark theme keeps a dark speck and only the pale flecks lift.
const SPECK_LIGHT := Color(0.34, 0.27, 0.17)
const SPECK_DARK := Color(0.20, 0.16, 0.10)
const PALE_LIGHT := Color(0.99, 0.97, 0.90)
const PALE_DARK := Color(0.62, 0.57, 0.44)

const MOTTLE_PERIOD: float = 110.0
const MOTTLE_STRENGTH: float = 0.05

static var _cache: Dictionary = {}
static var _viewport_scale: float = 1.0

const REFERENCE_VIEWPORT_HEIGHT: float = 720.0


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
## not stocked.
static func material_for(tier: StringName, light_mode: bool) -> ShaderMaterial:
	if not TIERS.has(tier):
		return null
	var key := "%s:%s" % [tier, "light" if light_mode else "dark"]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var settings: Dictionary = TIERS[tier]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("grain", float(settings.grain))
	material.set_shader_parameter("density", float(settings.density))
	material.set_shader_parameter(
		"strength",
		float(settings.strength) * (LIGHT_SCALE if light_mode else DARK_SCALE),
	)
	material.set_shader_parameter("pale_scale", 1.0 if light_mode else DARK_PALE_SCALE)
	material.set_shader_parameter("speck", SPECK_LIGHT if light_mode else SPECK_DARK)
	material.set_shader_parameter("pale", PALE_LIGHT if light_mode else PALE_DARK)
	material.set_shader_parameter("mottle_period", MOTTLE_PERIOD)
	material.set_shader_parameter("mottle_strength", MOTTLE_STRENGTH)
	material.set_shader_parameter("viewport_scale", _viewport_scale)
	_cache[key] = material
	return material


## Dropped on a theme switch, for the reason the halftone's is: every cached
## material carries the speck colours of the theme it was built under, and
## reusing them across a switch leaves the folders flecked in the old theme's
## pulp without looking broken enough for anybody to notice.
static func clear_cache() -> void:
	_cache.clear()
