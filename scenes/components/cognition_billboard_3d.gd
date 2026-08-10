class_name CognitionBillboard3D
extends Node3D

## The 3D half of one cognition cue above a voli's head. Text remains useful
## for shields, swords, faces and arrows, but an eye cannot be a text glyph if
## its pupil needs to look around. The eye is therefore two fixed-size sprites:
## a thin oval and an independently offset pupil, both camera-facing.

const BadgeModel := preload("res://scripts/systems/cognition_badge.gd")

const ICON_GLYPHS := {
	"shield": "⛨",
	"sword": "⚔",
	"none": "",
}
const FACE_GLYPHS := {
	"upset": "✖",
	"sad": "▾",
	"confident": "▴",
	"pleased": "▴",
	"urgent": "!",
}
const TREND_GLYPHS := {1: "↑", -1: "↓"}
const HEIGHT_ABOVE_HEAD_METERS: float = 0.42
const EYE_PIXEL_SIZE: float = 0.00155

var _label: Label3D
var _eye_outline: Sprite3D
var _eye_pupil: Sprite3D


func _init() -> void:
	_build_label()
	_build_eye()
	visible = false


func _build_label() -> void:
	_label = Label3D.new()
	_label.name = "CueText"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0016
	_label.font_size = 24
	_label.outline_size = 8
	_label.outline_modulate = Color(0.02, 0.02, 0.04, 0.85)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func _build_eye() -> void:
	_eye_outline = Sprite3D.new()
	_eye_outline.name = "EyeOval"
	_eye_outline.texture = _svg_texture(
		"<svg xmlns='http://www.w3.org/2000/svg' width='72' height='44' "
		+ "viewBox='0 0 72 44'><ellipse cx='36' cy='22' rx='31' ry='16' "
		+ "fill='none' stroke='white' stroke-width='2'/></svg>"
	)
	_configure_eye_sprite(_eye_outline)
	add_child(_eye_outline)

	_eye_pupil = Sprite3D.new()
	_eye_pupil.name = "EyePupil"
	_eye_pupil.texture = _svg_texture(
		"<svg xmlns='http://www.w3.org/2000/svg' width='12' height='12' "
		+ "viewBox='0 0 12 12'><circle cx='6' cy='6' r='5' fill='white'/></svg>"
	)
	_configure_eye_sprite(_eye_pupil)
	## Draw just in front of the oval so alpha ordering never swallows the pupil.
	_eye_pupil.position.z = 0.002
	add_child(_eye_pupil)


func _configure_eye_sprite(sprite: Sprite3D) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.fixed_size = true
	sprite.pixel_size = EYE_PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _svg_texture(source: String) -> Texture2D:
	var image := Image.new()
	if image.load_svg_from_string(source) != OK:
		return null
	return ImageTexture.create_from_image(image)


## `toward` is the cue's attention direction in court space. Only its direction
## matters; the pupil is bounded inside the oval by certainty in CognitionBadge.
func show_cue(
	cue: Resource, head_height_meters: float, toward: Vector2 = Vector2.ZERO
) -> void:
	if cue == null or not BadgeModel.is_worth_drawing(cue):
		visible = false
		return
	var reading: Dictionary = BadgeModel.describe(cue, toward)
	if reading.is_empty():
		visible = false
		return
	var icon := str(reading.icon)
	var face := str(FACE_GLYPHS.get(str(reading.face), ""))
	var punctuation := str(reading.punctuation)
	var trend := str(TREND_GLYPHS.get(int(reading.trend_direction), ""))
	var colour := Color(reading.color)
	var emphasis := float(reading.emphasis)

	_eye_outline.visible = icon == "eye"
	_eye_pupil.visible = icon == "eye" and float(reading.eye_openness) > 0.2
	if icon == "eye":
		var openness := float(reading.eye_openness)
		## Always an oval, never the old box/lens. Lost sight compresses the oval
		## toward a closed line while retaining enough contour to still read as eye.
		_eye_outline.scale = Vector3(1.0, lerpf(0.16, 1.0, openness), 1.0)
		var pupil := Vector2(reading.pupil)
		_eye_pupil.offset = Vector2(
			clampf(pupil.x * 24.0, -10.0, 10.0),
			clampf(pupil.y * 13.0, -5.0, 5.0) * maxf(openness, 0.2),
		)
		_eye_outline.modulate = colour
		_eye_pupil.modulate = colour
		_eye_outline.pixel_size = EYE_PIXEL_SIZE * lerpf(0.88, 1.16, emphasis)
		_eye_pupil.pixel_size = EYE_PIXEL_SIZE * lerpf(0.88, 1.16, emphasis)
		## Reserve the center for the procedural eye; face and annotations sit to
		## either side without replacing the action icon.
		_label.text = "%s      %s%s" % [face, punctuation, trend]
	else:
		_label.text = "%s%s%s%s" % [
			face, str(ICON_GLYPHS.get(icon, "")), punctuation, trend,
		]
	_label.modulate = colour
	_label.pixel_size = lerpf(0.0013, 0.0021, emphasis)
	position = Vector3(0.0, head_height_meters + HEIGHT_ABOVE_HEAD_METERS, 0.0)
	visible = true


func hide_cue() -> void:
	visible = false
