class_name SignatureSurge3D
extends Node3D

## Code-native signature-move VFX.
##
## Simulation supplies move/charge/result/phase. This node only visualises those
## facts. The common gather says "signature action is charging"; release geometry
## then says *which action* without relying on colour alone:
## - block_crush: downward compression/claw;
## - high_hands: upward deflection fan;
## - foresight: compact focus reticle;
## - heroics: low rescue/sweep ripple;
## - monster_block: broad vertical wall.

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
var _stream_base: Array[Vector3] = []
var _contact_rings: Array[MeshInstance3D] = []

## Presentation anchor in metres above the voli's feet. PlayerActor3D may update
## this from realised pose/contact geometry. No gameplay state reads it.
var contact_anchor_meters: float = 1.2


func _ready() -> void:
	for visual in [core, burst] + rings + streams:
		var material := visual.get_active_material(0) as StandardMaterial3D
		if material != null:
			material = material.duplicate() as StandardMaterial3D
			visual.material_override = material
			_materials.append(material)
	for stream in streams:
		_stream_base.append(stream.position)
	_contact_rings = [
		_make_contact_ring("ContactRingA"),
		_make_contact_ring("ContactRingB"),
		_make_contact_ring("ContactRingC"),
	]
	visible = false


static func profile_for(move: String) -> Dictionary:
	var key := move.to_lower().replace(" ", "_")
	return {
		"move": key,
		"colour": Color(MOVE_COLOURS.get(key, Color(1.0, 0.84, 0.20, 1.0))),
		"precision": key in ["high_hands", "foresight"],
		"impact": key in ["block_crush", "heroics", "monster_block"],
		"shape": {
			"block_crush": "compression",
			"high_hands": "deflection",
			"foresight": "focus",
			"heroics": "sweep",
			"monster_block": "wall",
		}.get(key, "pulse"),
	}


func set_cue(move: String, charge: float, succeeded: bool, phase: float) -> void:
	_move = move.to_lower().replace(" ", "_")
	_charge = clampf(charge, 0.0, 1.0)
	_succeeded = succeeded
	if _move.is_empty() or _charge <= 0.001:
		visible = false
		return
	visible = phase >= -0.92 and phase <= 1.0
	if not visible:
		return

	var profile := profile_for(_move)
	var colour := Color(profile.colour)
	var precision := bool(profile.precision)
	var gather := smoothstep(-0.88, -0.08, phase)
	var release := smoothstep(-0.04, 0.18, phase)
	var release_peak := release * (1.0 - smoothstep(0.34, 0.82, phase))
	var fade := 1.0 - smoothstep(0.30, 1.0, phase)
	var strength := lerpf(0.38, 1.0, _charge)
	var accent := colour.lerp(Color.WHITE, 0.42 if precision else 0.20)

	_draw_gather_rings(gather, fade, strength, colour, precision, phase)
	_draw_core(gather, fade, strength, colour, precision, phase)
	_draw_streams(gather, release_peak, fade, strength, colour, accent, phase)
	_draw_burst(release, release_peak, fade, strength, colour, accent)
	_draw_contact_shape(release, release_peak, fade, strength, colour, accent)


func _draw_gather_rings(
	gather: float, fade: float, strength: float, colour: Color,
	precision: bool, phase: float,
) -> void:
	for index in rings.size():
		var ring := rings[index]
		var travel := fposmod((phase + 0.90) * 1.42 + float(index) / 3.0, 1.0)
		ring.position = Vector3(0.0, lerpf(0.12, contact_anchor_meters, travel), 0.0)
		ring.rotation = Vector3.ZERO
		var start_radius := 0.66 if precision else 0.73
		var end_radius := 0.29 if precision else 0.43
		var ring_scale := lerpf(start_radius, end_radius, travel) * lerpf(0.82, 1.04, strength)
		ring.scale = Vector3.ONE * ring_scale
		_set_alpha(ring, colour, gather * fade * (1.0 - travel * 0.62) * 0.52)


func _draw_core(
	gather: float, fade: float, strength: float, colour: Color,
	precision: bool, phase: float,
) -> void:
	var pulse := (0.72 + 0.28 * sin((phase + 1.0) * TAU * 3.0)) * gather
	core.position.y = contact_anchor_meters * 0.46
	var width := lerpf(0.25, 0.39, pulse * strength)
	var height := lerpf(0.31, 0.53, pulse * strength)
	core.scale = Vector3(width, height, width)
	_set_alpha(core, colour, pulse * fade * (0.20 if precision else 0.27))


func _draw_streams(
	gather: float, release_peak: float, fade: float, strength: float,
	colour: Color, accent: Color, phase: float,
) -> void:
	for index in streams.size():
		var stream := streams[index]
		var flicker := 0.76 + 0.24 * sin((phase + 1.0) * 19.0 + float(index) * 1.7)
		var travel := fposmod(
			(phase + 0.90) * 1.72 + float(index) / float(streams.size()), 1.0
		)
		var base := _stream_base[index]
		var gather_position := Vector3(
			base.x,
			lerpf(0.18, contact_anchor_meters * 0.98, travel),
			base.z,
		)
		var spec := _release_spec(index, strength)
		var target_position: Vector3 = spec.position
		var direction: Vector3 = spec.direction
		var target_length := float(spec.length)
		var morph := release_peak
		stream.position = gather_position.lerp(target_position, morph)
		if morph > 0.04:
			stream.rotation = Quaternion(Vector3.UP, direction).get_euler()
		else:
			stream.rotation = Vector3(0.0, float(index) / float(streams.size()) * TAU + phase * 0.22, 0.0)
		stream.scale = Vector3(
			lerpf(1.0, float(spec.width), morph),
			lerpf(lerpf(0.20, 0.42, strength) * flicker, target_length, morph),
			lerpf(1.0, float(spec.width), morph),
		)
		var gather_alpha := gather * fade * flicker * (1.0 - travel * 0.56) * 0.50
		var release_alpha := release_peak * fade * strength * (0.90 if _succeeded else 0.68)
		_set_alpha(
			stream,
			accent if morph > 0.32 else colour,
			maxf(gather_alpha * (1.0 - morph), release_alpha),
		)


func _release_spec(index: int, strength: float) -> Dictionary:
	var lane := float(index) - 2.5
	var angle := TAU * float(index) / float(streams.size())
	var anchor := Vector3(0.0, contact_anchor_meters, 0.0)
	match _move:
		"block_crush":
			var direction := Vector3(lane * 0.18, -0.92 + absf(lane) * 0.035, -0.10).normalized()
			return {
				"position": anchor + direction * 0.43 + Vector3(0.0, 0.10, 0.0),
				"direction": direction,
				"length": lerpf(0.64, 0.96, strength),
				"width": 1.10,
			}
		"high_hands":
			var direction := Vector3(lane * 0.20, 0.78 - absf(lane) * 0.035, -0.12).normalized()
			return {
				"position": anchor + direction * 0.36,
				"direction": direction,
				"length": lerpf(0.46, 0.72, strength),
				"width": 0.82,
			}
		"foresight":
			var direction := Vector3(cos(angle), 0.06, sin(angle) * 0.42).normalized()
			return {
				"position": anchor + direction * 0.24,
				"direction": direction,
				"length": lerpf(0.24, 0.38, strength),
				"width": 0.72,
			}
		"heroics":
			var side := -1.0 if index % 2 == 0 else 1.0
			var direction := Vector3(-0.82 + float(index / 2) * 0.13, 0.02, side * 0.34).normalized()
			return {
				"position": Vector3(0.0, maxf(0.24, contact_anchor_meters * 0.50), 0.0) + direction * 0.42,
				"direction": direction,
				"length": lerpf(0.46, 0.76, strength),
				"width": 0.82,
			}
		"monster_block":
			var x := lane * 0.19
			var y := contact_anchor_meters - 0.13 + float(index % 2) * 0.22
			return {
				"position": Vector3(x, y, -0.03),
				"direction": Vector3.UP,
				"length": lerpf(0.62, 1.02, strength),
				"width": 0.78,
			}
		_:
			var direction := Vector3(cos(angle), 0.14, sin(angle)).normalized()
			return {
				"position": anchor + direction * 0.35,
				"direction": direction,
				"length": 0.60,
				"width": 1.0,
			}


func _draw_burst(
	release: float, release_peak: float, fade: float, strength: float,
	colour: Color, accent: Color,
) -> void:
	var weight := release_peak
	if _succeeded:
		weight = maxf(weight, release * fade * 0.68)
	burst.position = Vector3(0.0, contact_anchor_meters, 0.0)
	burst.rotation = Vector3.ZERO
	burst.scale = Vector3.ONE
	match _move:
		"block_crush":
			burst.position.y -= 0.04
			burst.scale = Vector3(lerpf(0.26, 1.06, release), 0.72, lerpf(0.26, 0.78, release))
		"high_hands":
			burst.rotation = Vector3(PI * 0.5, 0.0, PI * 0.22)
			burst.scale = Vector3.ONE * lerpf(0.24, 0.78, release)
		"foresight":
			burst.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			burst.scale = Vector3.ONE * lerpf(0.18, 0.56, release)
		"heroics":
			burst.position.y = maxf(0.22, contact_anchor_meters * 0.34)
			burst.scale = Vector3(lerpf(0.32, 1.18, release), 0.58, lerpf(0.22, 0.62, release))
		"monster_block":
			burst.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			burst.scale = Vector3(lerpf(0.28, 1.30, release), lerpf(0.28, 0.92, release), 0.72)
		_:
			burst.scale = Vector3.ONE * lerpf(0.26, 0.92, release)
	_set_alpha(burst, accent, weight * strength * 0.82)


func _draw_contact_shape(
	release: float, release_peak: float, fade: float, strength: float,
	colour: Color, accent: Color,
) -> void:
	for index in _contact_rings.size():
		var ring := _contact_rings[index]
		ring.position = Vector3(0.0, contact_anchor_meters, 0.0)
		ring.rotation = Vector3.ZERO
		ring.scale = Vector3.ONE
		var alpha := release_peak * fade * strength * (0.82 - float(index) * 0.15)
		match _move:
			"block_crush":
				## Three horizontal fronts collapse toward the strike point.
				ring.position.y += 0.20 - float(index) * 0.20
				var s := lerpf(0.28 + float(index) * 0.08, 1.18 - float(index) * 0.18, release)
				ring.scale = Vector3(s, 0.72, s * 0.72)
			"high_hands":
				## Crossed vertical rings and an upper cap read as controlled deflection.
				ring.rotation = Vector3(
					PI * 0.5,
					PI * (0.18 if index == 0 else (-0.18 if index == 1 else 0.0)),
					PI * (0.16 if index == 0 else (-0.16 if index == 1 else 0.0)),
				)
				ring.position.y += 0.05 + float(index) * 0.07
				ring.scale = Vector3.ONE * lerpf(0.20 + float(index) * 0.04, 0.66 + float(index) * 0.09, release)
			"foresight":
				## Compact concentric target rings stay close to the setting hands.
				ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
				ring.position.z = -0.05 + float(index) * 0.045
				var s := lerpf(0.16 + float(index) * 0.05, 0.34 + float(index) * 0.12, release)
				ring.scale = Vector3.ONE * s
				alpha *= 0.92
			"heroics":
				## Rescue energy travels along the floor rather than exploding around
				## the torso: three staggered, flattened ripples behind the dig.
				ring.position = Vector3(-0.18 - float(index) * 0.28, 0.10 + float(index) * 0.025, 0.0)
				var sx := lerpf(0.30, 1.05 + float(index) * 0.22, release)
				var sz := lerpf(0.20, 0.48 + float(index) * 0.10, release)
				ring.scale = Vector3(sx, 0.42, sz)
				alpha *= 0.72
			"monster_block":
				## Vertical overlapping hoops make a wall at the tape instead of the
				## radial blast used by an attacking crush.
				ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
				ring.position.x = (float(index) - 1.0) * 0.30
				var s := lerpf(0.22, 0.72 + float(index % 2) * 0.10, release)
				ring.scale = Vector3(s * 1.28, s, 0.72)
			_:
				ring.scale = Vector3.ONE * lerpf(0.22, 0.72, release)
		_set_alpha(ring, accent if index != 1 else colour, alpha)


func clear() -> void:
	_move = ""
	_charge = 0.0
	_succeeded = false
	visible = false


func _make_contact_ring(name_: String) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = name_
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.22
	mesh.outer_radius = 0.242
	mesh.rings = 24
	mesh.ring_segments = 7
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.albedo_color = Color(1.0, 0.84, 0.20, 0.0)
	material.emission = Color(1.0, 0.84, 0.20, 1.0)
	material.emission_energy_multiplier = 2.0
	ring.material_override = material
	_materials.append(material)
	add_child(ring)
	return ring


func _set_alpha(visual: MeshInstance3D, colour: Color, alpha: float) -> void:
	var material := visual.material_override as StandardMaterial3D
	if material == null:
		return
	var shown := colour
	shown.a = clampf(alpha, 0.0, 1.0)
	material.albedo_color = shown
	material.emission = Color(colour.r, colour.g, colour.b, 1.0)
	material.emission_energy_multiplier = lerpf(0.70, 2.45, clampf(alpha, 0.0, 1.0))
