class_name SignatureSurge3D
extends Node3D

## Code-native signature-move VFX.
##
## Simulation supplies move/charge/result/phase. This node only visualises those
## facts. Charge travels through the body; the release then resolves into one of
## two readable contact languages instead of every signature being the same
## coloured bubble:
## - precision: converging/crossed rings + disciplined rays;
## - impact: expanding shock rings + radial fragments.

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
## this from the realised pose/contact geometry. No gameplay state reads it.
var contact_anchor_meters: float = 1.2


func _ready() -> void:
	## Each authored piece owns alpha; sharing one material makes unrelated stages
	## of the effect fade together.
	for visual in [core, burst] + rings + streams:
		var material := visual.get_active_material(0) as StandardMaterial3D
		if material != null:
			material = material.duplicate() as StandardMaterial3D
			visual.material_override = material
			_materials.append(material)
	for stream in streams:
		_stream_base.append(stream.position)
	_contact_rings = [_make_contact_ring("ContactRingA"), _make_contact_ring("ContactRingB")]
	visible = false


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
	visible = phase >= -0.92 and phase <= 1.0
	if not visible:
		return

	var profile := profile_for(_move)
	var colour := Color(profile.colour)
	var precision := bool(profile.precision)
	var impact := bool(profile.impact)
	var gather := smoothstep(-0.88, -0.08, phase)
	var release := smoothstep(-0.04, 0.18, phase)
	var release_peak := release * (1.0 - smoothstep(0.34, 0.82, phase))
	var fade := 1.0 - smoothstep(0.30, 1.0, phase)
	var strength := lerpf(0.38, 1.0, _charge)
	var accent := colour.lerp(Color.WHITE, 0.42 if precision else 0.22)

	## Three travelling rings make the charge climb toward the physical contact.
	## Precision tightens as it rises; impact carries more radius into release.
	for index in rings.size():
		var ring := rings[index]
		var travel := fposmod((phase + 0.90) * 1.42 + float(index) / 3.0, 1.0)
		ring.position.y = lerpf(0.12, contact_anchor_meters, travel)
		var start_radius := 0.70 if precision else 0.78
		var end_radius := 0.30 if precision else 0.48
		var ring_scale := lerpf(start_radius, end_radius, travel) * lerpf(0.82, 1.05, strength)
		ring.scale = Vector3.ONE * ring_scale
		_set_alpha(ring, colour, gather * fade * (1.0 - travel * 0.58) * 0.62)

	## Charge remains inside the body silhouette: ellipsoid, not aura bubble.
	var core_pulse := (0.72 + 0.28 * sin((phase + 1.0) * TAU * 3.0)) * gather
	core.position.y = contact_anchor_meters * 0.46
	var core_width := lerpf(0.28, 0.43, core_pulse * strength)
	var core_height := lerpf(0.34, 0.58, core_pulse * strength)
	core.scale = Vector3(core_width, core_height, core_width)
	_set_alpha(core, colour, core_pulse * fade * (0.24 if precision else 0.31))

	## During gather, short fragments climb the body. At release those exact
	## fragments converge on the contact and become rays, so the effect has one
	## continuous cause rather than a second unrelated explosion appearing there.
	for index in streams.size():
		var stream := streams[index]
		var flicker := 0.70 + 0.30 * sin((phase + 1.0) * 19.0 + float(index) * 1.7)
		var stream_travel := fposmod(
			(phase + 0.90) * 1.72 + float(index) / float(streams.size()), 1.0
		)
		var base := _stream_base[index]
		var gather_position := Vector3(
			base.x,
			lerpf(0.18, contact_anchor_meters * 0.98, stream_travel),
			base.z,
		)
		var angle := TAU * float(index) / float(streams.size())
		var vertical := (0.12 + float(index % 3) * 0.20) if impact else (0.04 + float(index % 2) * 0.12)
		var ray_direction := Vector3(cos(angle), vertical, sin(angle)).normalized()
		if precision:
			## Two paired axes form a deliberate contact cross rather than a blast.
			var axis := -1.0 if index % 2 == 0 else 1.0
			var lane := float(index / 2) - 1.0
			ray_direction = Vector3(axis, lane * 0.16, -0.20 + absf(lane) * 0.16).normalized()
		var ray_extent := lerpf(0.34, 0.78 if impact else 0.54, strength)
		var ray_position := Vector3(0.0, contact_anchor_meters, 0.0) + ray_direction * ray_extent * 0.52
		var morph := release_peak
		stream.position = gather_position.lerp(ray_position, morph)
		stream.rotation = Quaternion(Vector3.UP, ray_direction).get_euler() if morph > 0.04 else Vector3(0.0, angle + phase * 0.28, 0.0)
		stream.scale.y = lerpf(
			lerpf(0.22, 0.48, strength) * flicker,
			lerpf(0.48, 1.12 if impact else 0.78, strength),
			morph,
		)
		var gather_alpha := gather * fade * flicker * (1.0 - stream_travel * 0.52) * 0.58
		var ray_alpha := release_peak * fade * strength * (0.92 if _succeeded else 0.70)
		_set_alpha(stream, accent if morph > 0.35 else colour, maxf(gather_alpha * (1.0 - morph), ray_alpha))

	## The authored burst is the primary contact ring. A second pair gives the
	## release depth: orthogonal crossed rings for precision, expanding shock
	## fronts for impact. Their silhouette now communicates move family even in
	## grayscale or when several players share the same venue lighting.
	var burst_weight := release * (1.0 - smoothstep(0.18, 0.66, phase))
	if _succeeded:
		burst_weight = maxf(burst_weight, release * fade)
	burst.position.y = contact_anchor_meters
	burst.rotation = Vector3(PI * 0.5, 0.0, PI * 0.25) if precision else Vector3.ZERO
	var burst_scale := lerpf(0.26, 0.92 if precision else 1.18, release)
	burst.scale = Vector3.ONE * burst_scale
	_set_alpha(burst, accent, burst_weight * strength * 0.90)

	_update_contact_rings(precision, impact, colour, accent, release, release_peak, fade, strength)


func clear() -> void:
	_move = ""
	_charge = 0.0
	_succeeded = false
	visible = false


func _update_contact_rings(
	precision: bool, impact: bool, colour: Color, accent: Color,
	release: float, release_peak: float, fade: float, strength: float,
) -> void:
	for index in _contact_rings.size():
		var ring := _contact_rings[index]
		ring.position = Vector3(0.0, contact_anchor_meters, 0.0)
		if precision:
			ring.rotation = Vector3(
				PI * 0.5,
				PI * 0.25 * (-1.0 if index == 0 else 1.0),
				PI * 0.18 * (-1.0 if index == 0 else 1.0),
			)
			var scale_precision := lerpf(0.20 + float(index) * 0.05, 0.72 + float(index) * 0.13, release)
			ring.scale = Vector3.ONE * scale_precision
			_set_alpha(ring, accent, release_peak * fade * strength * (0.90 - float(index) * 0.16))
		else:
			ring.rotation = Vector3(0.0, float(index) * PI * 0.25, float(index) * PI * 0.5)
			var end_scale := (1.45 + float(index) * 0.48) if impact else (1.05 + float(index) * 0.32)
			var scale_impact := lerpf(0.24 + float(index) * 0.08, end_scale, release)
			ring.scale = Vector3.ONE * scale_impact
			var shock_alpha := release_peak * fade * strength * (0.76 - float(index) * 0.18)
			_set_alpha(ring, colour if index == 0 else accent, shock_alpha)


func _make_contact_ring(name_: String) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = name_
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.22
	mesh.outer_radius = 0.255
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
	material.emission_energy_multiplier = lerpf(0.75, 2.65, clampf(alpha, 0.0, 1.0))
