class_name SignatureSurge3D
extends Node3D

## A lightweight, code-native signature charge around a voli. The old effect
## was an authored sphere, three complete rings and six vertical rails; at court
## distance that read as armour or a cage. This version builds short, thin,
## staggered fragments at runtime so the charge reads as unstable power. Contact
## impact belongs to BallActor3D, not to this player-attached node.

const MOVE_COLOURS := {
	"block_crush": Color(1.00, 0.20, 0.045, 1.0),
	"high_hands": Color(0.15, 0.88, 1.00, 1.0),
	"foresight": Color(0.52, 0.36, 1.00, 1.0),
	"heroics": Color(1.00, 0.76, 0.10, 1.0),
	"monster_block": Color(0.72, 0.12, 1.00, 1.0),
}

const SPARK_COUNT: int = 18
const FLARE_COUNT: int = 5

var _move: String = ""
var _charge: float = 0.0
var _succeeded: bool = false
var _sparks: Array[MeshInstance3D] = []
var _flares: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_fragments()
	visible = false


## Stable presentation vocabulary. Future signatures can use this component
## without teaching match playback another set of colours or timing rules.
static func profile_for(move: String) -> Dictionary:
	var key := move.to_lower().replace(" ", "_")
	return {
		"move": key,
		"colour": Color(MOVE_COLOURS.get(key, Color(1.0, 0.84, 0.20, 1.0))),
		"precision": key in ["high_hands", "foresight"],
		"impact": key in ["block_crush", "heroics", "monster_block"],
	}


func _build_fragments() -> void:
	if not _sparks.is_empty():
		return
	var spark_mesh := CylinderMesh.new()
	spark_mesh.top_radius = 0.004
	spark_mesh.bottom_radius = 0.010
	spark_mesh.height = 1.0
	spark_mesh.radial_segments = 4
	for index in range(SPARK_COUNT):
		var spark := MeshInstance3D.new()
		spark.name = "Spark%02d" % index
		spark.mesh = spark_mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.material_override = _new_energy_material()
		add_child(spark)
		_sparks.append(spark)

	var flare_mesh := SphereMesh.new()
	flare_mesh.radius = 0.025
	flare_mesh.height = 0.05
	flare_mesh.radial_segments = 6
	flare_mesh.rings = 4
	for index in range(FLARE_COUNT):
		var flare := MeshInstance3D.new()
		flare.name = "Flare%02d" % index
		flare.mesh = flare_mesh
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flare.material_override = _new_energy_material()
		add_child(flare)
		_flares.append(flare)


func _new_energy_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_receive_shadows = true
	return material


func set_cue(move: String, charge: float, succeeded: bool, phase: float) -> void:
	_move = move.to_lower().replace(" ", "_")
	_charge = clampf(charge, 0.0, 1.0)
	_succeeded = succeeded
	if _move.is_empty() or _charge <= 0.001:
		visible = false
		return
	## The player carries charge into contact, then gets out of the ball flare's
	## way. Failed signatures leave only a brief sputter rather than an impact.
	visible = phase >= -0.92 and phase <= 0.26
	if not visible:
		return
	var profile := profile_for(_move)
	var colour := Color(profile.colour)
	var gather := smoothstep(-0.90, -0.12, phase)
	var contact_fade := 1.0 - smoothstep(-0.04, 0.24, phase)
	var strength := lerpf(0.34, 1.0, _charge) * gather * contact_fade

	for index in range(_sparks.size()):
		var spark := _sparks[index]
		var strand := float(index % 6)
		var tier := float(index / 6)
		var travel := fposmod(
			(phase + 0.94) * (1.35 + tier * 0.16) + strand / 6.0, 1.0
		)
		var angle := strand / 6.0 * TAU + phase * (0.42 + tier * 0.08)
		var radius := 0.24 + 0.09 * sin(float(index) * 2.17 + phase * 11.0)
		var length := lerpf(0.08, 0.25, _charge) \
			* (0.72 + 0.28 * sin(phase * 23.0 + float(index) * 1.91))
		var tangent := Vector3(-sin(angle), 0.62 + tier * 0.16, cos(angle)).normalized()
		var center := Vector3(
			cos(angle) * radius,
			lerpf(0.12, 2.15, travel),
			sin(angle) * radius,
		)
		spark.position = center
		spark.quaternion = Quaternion(Vector3.UP, tangent)
		spark.scale = Vector3(1.0, maxf(length, 0.02), 1.0)
		_set_alpha(
			spark, colour,
			strength * (1.0 - travel * 0.42)
				* (0.38 + 0.42 * absf(sin(phase * 29.0 + float(index)))),
		)

	for index in range(_flares.size()):
		var flare := _flares[index]
		var travel := fposmod(
			(phase + 0.92) * 1.62 + float(index) / float(_flares.size()), 1.0
		)
		var angle := float(index) / float(_flares.size()) * TAU - phase * 0.7
		flare.position = Vector3(
			cos(angle) * lerpf(0.18, 0.40, travel),
			lerpf(0.16, 2.10, travel),
			sin(angle) * lerpf(0.18, 0.40, travel),
		)
		var pulse := 0.55 + 0.45 * sin(phase * 31.0 + float(index) * 2.3)
		flare.scale = Vector3.ONE * lerpf(0.35, 1.15, maxf(pulse, 0.0))
		_set_alpha(flare, colour, strength * maxf(pulse, 0.0) * 0.72)


func clear() -> void:
	_move = ""
	_charge = 0.0
	_succeeded = false
	visible = false


func _set_alpha(visual: MeshInstance3D, colour: Color, alpha: float) -> void:
	var material := visual.material_override as StandardMaterial3D
	if material == null:
		return
	var shown := colour
	shown.a = clampf(alpha, 0.0, 1.0)
	material.albedo_color = shown
	material.emission_enabled = true
	material.emission = Color(colour.r, colour.g, colour.b, 1.0) * lerpf(
		0.75, 2.8, clampf(alpha, 0.0, 1.0)
	)
