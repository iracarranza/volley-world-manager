class_name SignatureSurge3D
extends Node3D

## A code-native signature-move aura: energy gathers at the feet, travels up the
## voli, and releases as a ring at contact.  The simulation supplies the move,
## charge and result; this node only turns those facts into a readable effect.

const MOVE_COLOURS := {
	"block_crush": Color(1.00, 0.20, 0.045, 1.0),
	"high_hands": Color(0.15, 0.88, 1.00, 1.0),
	"foresight": Color(0.52, 0.36, 1.00, 1.0),
	"heroics": Color(1.00, 0.76, 0.10, 1.0),
	"monster_block": Color(0.72, 0.12, 1.00, 1.0),
}

@onready var core: MeshInstance3D = $Core
@onready var burst: MeshInstance3D = $Burst
@onready var rings: Array[MeshInstance3D] = [
	$Rings/Ring0, $Rings/Ring1, $Rings/Ring2,
]
@onready var streams: Array[MeshInstance3D] = [
	$Streams/Stream0, $Streams/Stream1, $Streams/Stream2,
	$Streams/Stream3, $Streams/Stream4, $Streams/Stream5,
]

var _move: String = ""
var _charge: float = 0.0
var _succeeded: bool = false
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	## Each piece owns its alpha. Sharing the authored material would make a ring
	## at the feet fade the contact burst above the hands at the same time.
	for visual in [core, burst] + rings + streams:
		var material := visual.get_active_material(0) as StandardMaterial3D
		if material != null:
			material = material.duplicate() as StandardMaterial3D
			visual.material_override = material
			_materials.append(material)
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


func set_cue(move: String, charge: float, succeeded: bool, phase: float) -> void:
	_move = move.to_lower().replace(" ", "_")
	_charge = clampf(charge, 0.0, 1.0)
	_succeeded = succeeded
	if _move.is_empty() or _charge <= 0.001:
		visible = false
		return
	visible = phase >= -0.92 and phase <= 0.78
	if not visible:
		return
	var profile := profile_for(_move)
	var colour := Color(profile.colour)
	var gather := smoothstep(-0.88, -0.08, phase)
	var release := smoothstep(-0.04, 0.18, phase)
	var fade := 1.0 - smoothstep(0.34, 0.78, phase)
	var strength := lerpf(0.38, 1.0, _charge)

	for index in rings.size():
		var ring := rings[index]
		var travel := fposmod((phase + 0.90) * 1.42 + float(index) / 3.0, 1.0)
		ring.position.y = lerpf(0.12, 2.08, travel)
		var ring_scale := lerpf(1.12, 0.72, travel) * lerpf(0.82, 1.05, strength)
		ring.scale = Vector3.ONE * ring_scale
		_set_alpha(ring, colour, gather * fade * (1.0 - travel * 0.54) * 0.72)

	var core_pulse := (0.72 + 0.28 * sin((phase + 1.0) * TAU * 3.0)) * gather
	core.scale = Vector3.ONE * lerpf(0.68, 1.08, core_pulse * strength)
	_set_alpha(core, colour, core_pulse * fade * 0.28)

	for index in streams.size():
		var stream := streams[index]
		var flicker := 0.70 + 0.30 * sin((phase + 1.0) * 19.0 + float(index) * 1.7)
		## Short, staggered strokes rather than six full-height rails. Full rails
		## around a body read as a cage; fragments moving on different cycles read
		## as energy travelling through it.
		var stream_travel := fposmod(
			(phase + 0.90) * 1.72 + float(index) / float(streams.size()), 1.0
		)
		stream.position.y = lerpf(0.18, 2.04, stream_travel)
		stream.scale.y = lerpf(0.22, 0.52, strength) * flicker
		stream.rotation.y = float(index) / float(streams.size()) * TAU \
			+ phase * 0.28
		_set_alpha(
			stream, colour,
			gather * fade * flicker * (1.0 - stream_travel * 0.52) * 0.72,
		)

	var burst_weight := release * (1.0 - smoothstep(0.18, 0.66, phase))
	if _succeeded:
		burst_weight = maxf(burst_weight, release * fade)
	burst.scale = Vector3.ONE * lerpf(0.45, 2.35, release)
	_set_alpha(burst, colour, burst_weight * strength * 0.92)


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
	material.emission = Color(colour.r, colour.g, colour.b, 1.0) * lerpf(
		0.75, 2.4, clampf(alpha, 0.0, 1.0)
	)
