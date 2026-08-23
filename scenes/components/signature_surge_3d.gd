class_name SignatureSurge3D
extends Node3D

## Presentation-only signature VFX.
##
## Draft direction: signatures should read as a change in the air around the
## voli -- radiance, pressure and short-lived energy flow -- rather than as
## rings, cages, wires or other tangible props. Simulation still owns move,
## charge, success and phase. This node never changes rally state.

const MOVE_COLOURS := {
	"block_crush": Color(1.00, 0.20, 0.045, 1.0),
	"high_hands": Color(0.15, 0.88, 1.00, 1.0),
	"foresight": Color(0.52, 0.36, 1.00, 1.0),
	"heroics": Color(1.00, 0.76, 0.10, 1.0),
	"monster_block": Color(0.72, 0.12, 1.00, 1.0),
}

@onready var core: MeshInstance3D = $Core
@onready var burst: MeshInstance3D = $Burst
@onready var shells: Array[MeshInstance3D] = [
	$Rings/Ring0, $Rings/Ring1, $Rings/Ring2,
]
@onready var tendrils: Array[MeshInstance3D] = [
	$Streams/Stream0, $Streams/Stream1, $Streams/Stream2,
	$Streams/Stream3, $Streams/Stream4, $Streams/Stream5,
]

var _move: String = ""
var _charge: float = 0.0
var _succeeded: bool = false

## Presentation anchor in metres above the voli's feet. PlayerActor3D updates
## this from realised pose/contact geometry. It is not gameplay authority.
var contact_anchor_meters: float = 1.2


func _ready() -> void:
	for visual in [core, burst] + shells + tendrils:
		var material := visual.get_active_material(0) as StandardMaterial3D
		if material != null:
			visual.material_override = material.duplicate() as StandardMaterial3D
	visible = false


static func profile_for(move: String) -> Dictionary:
	var key := move.to_lower().replace(" ", "_")
	return {
		"move": key,
		"colour": Color(MOVE_COLOURS.get(key, Color(1.0, 0.84, 0.20, 1.0))),
		## Kept for compatibility with existing callers/tests. Composition below
		## deliberately does not collapse signatures into these old two buckets.
		"precision": key in ["high_hands", "foresight"],
		"impact": key in ["block_crush", "heroics", "monster_block"],
		"action_family": {
			"block_crush": "attack",
			"high_hands": "attack",
			"foresight": "dig",
			"heroics": "dig",
			"monster_block": "block",
		}.get(key, "generic"),
		"gesture": {
			"block_crush": "compress_rupture",
			"high_hands": "shear_peel",
			"foresight": "anticipate_commit",
			"heroics": "ignite_rescue",
			"monster_block": "converge_deny",
		}.get(key, "pulse"),
		"shape": {
			"block_crush": "rupture",
			"high_hands": "peel",
			"foresight": "anticipation",
			"heroics": "rescue",
			"monster_block": "pressure",
		}.get(key, "pulse"),
	}


func set_cue(move: String, charge: float, succeeded: bool, phase: float) -> void:
	_move = move.to_lower().replace(" ", "_")
	_charge = clampf(charge, 0.0, 1.0)
	_succeeded = succeeded
	if _move.is_empty() or _charge <= 0.001:
		clear()
		return

	visible = phase >= -0.94 and phase <= 1.0
	if not visible:
		return

	var profile := profile_for(_move)
	var colour := Color(profile.colour)
	var accent := colour.lerp(Color.WHITE, 0.30)
	var gather := smoothstep(-0.90, -0.18, phase)
	var release := smoothstep(-0.16, 0.16, phase)
	var release_peak := release * (1.0 - smoothstep(0.34, 0.78, phase))
	var fade := 1.0 - smoothstep(0.38, 1.0, phase)
	var strength := lerpf(0.42, 1.0, _charge)

	## Heroics can visibly begin to form and then be denied before the emergency
	## action exists. Do not let a failed cue play a fake rescue burst.
	var denial := 1.0
	if _move == "heroics" and not _succeeded:
		denial = 1.0 - smoothstep(-0.18, 0.06, phase)

	_draw_shells(gather, release_peak, fade * denial, strength, colour, phase)
	_draw_core(gather, release_peak, fade * denial, strength, colour, phase)
	_draw_tendrils(gather, release_peak, fade * denial, strength, colour, accent, phase)
	_draw_release(release, release_peak, fade * denial, strength, colour, accent, phase)


func _draw_shells(
	gather: float, release_peak: float, fade: float, strength: float,
	colour: Color, phase: float,
) -> void:
	for index in shells.size():
		var shell := shells[index]
		var spec := _shell_spec(index, release_peak, strength)
		var breathe := 0.86 + 0.14 * sin((phase + 1.0) * TAU * 2.1 + float(index) * 0.8)
		shell.position = Vector3(spec.position)
		shell.rotation = Vector3.ZERO
		var size := Vector2(spec.size) * breathe
		shell.scale = Vector3(size.x, size.y, 1.0)
		var stagger := 0.82 + float(index) * 0.08
		var alpha := gather * fade * strength * stagger * float(spec.alpha)
		_set_glow(shell, colour, alpha)


func _draw_core(
	gather: float, release_peak: float, fade: float, strength: float,
	colour: Color, phase: float,
) -> void:
	var pulse := 0.78 + 0.22 * sin((phase + 1.0) * TAU * 2.8)
	var center := _body_center()
	core.position = center
	core.rotation = Vector3.ZERO
	var scale_2d := Vector2(0.74, 1.02)
	match _move:
		"block_crush":
			scale_2d = Vector2(0.86, 1.18 - release_peak * 0.20)
		"high_hands":
			scale_2d = Vector2(0.62, 0.92)
		"foresight":
			scale_2d = Vector2(0.82, 0.70)
		"heroics":
			scale_2d = Vector2(1.02 + release_peak * 0.32, 0.68)
		"monster_block":
			scale_2d = Vector2(1.08, 1.30)
	core.scale = Vector3(scale_2d.x, scale_2d.y, 1.0) * pulse * strength
	_set_glow(core, colour, gather * fade * strength * 0.30)


func _draw_tendrils(
	gather: float, release_peak: float, fade: float, strength: float,
	colour: Color, accent: Color, phase: float,
) -> void:
	for index in tendrils.size():
		var tendril := tendrils[index]
		var spec := _tendril_spec(index, release_peak, strength)
		var flicker := 0.72 + 0.28 * sin((phase + 1.0) * 14.0 + float(index) * 1.31)
		var size := Vector2(spec.size)
		tendril.position = Vector3(spec.position)
		tendril.rotation = Vector3(0.0, 0.0, float(spec.rotation))
		tendril.scale = Vector3(size.x, size.y, 1.0)
		var release_gain := 1.0 if _succeeded else 0.46
		if _move == "foresight" and not _succeeded:
			## A wrong read still fully existed before contact; its cost is that
			## the defender committed to the wrong future, not that the cue failed
			## to charge. Preserve the early field and only weaken confirmation.
			release_gain = 0.64
		if _move == "heroics" and not _succeeded:
			release_gain = 0.08
		var ambient := gather * (1.0 - release_peak * 0.55) * 0.16
		var released := release_peak * release_gain * 0.34
		var alpha := maxf(ambient, released) * fade * strength * flicker
		_set_glow(tendril, accent if release_peak > 0.22 else colour, alpha)


func _draw_release(
	release: float, release_peak: float, fade: float, strength: float,
	colour: Color, accent: Color, phase: float,
) -> void:
	burst.rotation = Vector3.ZERO
	var alpha := release_peak * fade * strength
	var size := Vector2(0.35, 0.35)
	var position := Vector3(0.0, contact_anchor_meters, 0.12)

	match _move:
		"block_crush":
			## Power route: aura compresses at hand/block height, then tears
			## downward. The soft ellipse is pressure, not a physical claw.
			position = Vector3(0.20, contact_anchor_meters - 0.08 - release * 0.18, 0.12)
			size = Vector2(0.94 + release * 0.18, 0.62 + release * 0.58)
			alpha *= 0.72 if _succeeded else 0.32
		"high_hands":
			## Accuracy route: a smaller flare peels upward/outward rather than
			## detonating through the wall.
			position = Vector3(0.28 + release * 0.18, contact_anchor_meters + 0.10 + release * 0.16, 0.12)
			burst.rotation.z = -0.58
			size = Vector2(0.48, 1.00 + release * 0.22)
			alpha *= 0.62 if _succeeded else 0.28
		"foresight":
			## Foresight's spectacle is early commitment, not a contact buff. The
			## release therefore stays body-local and comparatively quiet.
			var read_side := 1.0 if _succeeded else -1.0
			position = Vector3(read_side * (0.12 + release * 0.18), 0.92, 0.14)
			size = Vector2(0.82 + release * 0.14, 0.52)
			alpha *= 0.36
		"heroics":
			## Heroics is an emergency physical action: broad, low and turbulent.
			## A denied attempt extinguishes before this can become a rescue.
			position = Vector3(-0.12 - release * 0.22, maxf(0.42, contact_anchor_meters * 0.48), 0.14)
			burst.rotation.z = 0.72
			size = Vector2(1.46 + release * 0.36, 0.52)
			alpha *= 0.82 if _succeeded else 0.04
		"monster_block":
			## Timing/denial: a broad, soft pressure bloom at apex. It should read
			## as the air hardening for an instant, never as cage bars.
			position = Vector3(0.0, contact_anchor_meters - 0.05, 0.12)
			size = Vector2(1.62 + release * 0.18, 0.64)
			alpha *= 0.76 if _succeeded else 0.30
		_:
			size = Vector2.ONE * (0.56 + release * 0.30)

	burst.position = position
	burst.scale = Vector3(size.x, size.y, 1.0)
	var pulse := 0.86 + 0.14 * sin((phase + 1.0) * TAU * 3.2)
	_set_glow(burst, accent.lerp(colour, 0.18), alpha * pulse)


func _shell_spec(index: int, release_peak: float, strength: float) -> Dictionary:
	var anchor := contact_anchor_meters
	match _move:
		"block_crush":
			var positions := [
				Vector3(-0.06, anchor * 0.48, 0.10),
				Vector3(0.13, anchor * 0.67, 0.11),
				Vector3(0.24, anchor * 0.86, 0.12),
			]
			var sizes := [
				Vector2(1.10, 1.40),
				Vector2(0.90, 1.12),
				Vector2(0.68, 0.80 - release_peak * 0.12),
			]
			return {"position": positions[index], "size": sizes[index] * strength, "alpha": 0.23}
		"high_hands":
			var positions := [
				Vector3(0.00, anchor * 0.50, 0.10),
				Vector3(0.16, anchor * 0.70, 0.11),
				Vector3(0.28, anchor * 0.91, 0.12),
			]
			var sizes := [Vector2(0.82, 1.08), Vector2(0.68, 0.92), Vector2(0.48, 0.62)]
			return {"position": positions[index], "size": sizes[index] * strength, "alpha": 0.20}
		"foresight":
			var side := 1.0 if _succeeded else -1.0
			var shift := side * release_peak * 0.22
			var positions := [
				Vector3(shift * 0.45, 0.68, 0.11),
				Vector3(shift * 0.72, 0.94, 0.12),
				Vector3(shift, 1.18, 0.13),
			]
			var sizes := [Vector2(1.06, 0.56), Vector2(0.90, 0.62), Vector2(0.68, 0.54)]
			return {"position": positions[index], "size": sizes[index] * strength, "alpha": 0.18}
		"heroics":
			var positions := [
				Vector3(-0.10, 0.48, 0.12),
				Vector3(-0.02, 0.72, 0.13),
				Vector3(0.08, 0.98, 0.12),
			]
			var sizes := [
				Vector2(1.30 + release_peak * 0.36, 0.48),
				Vector2(1.05 + release_peak * 0.28, 0.58),
				Vector2(0.80, 0.66),
			]
			return {"position": positions[index], "size": sizes[index] * strength, "alpha": 0.23}
		"monster_block":
			var positions := [
				Vector3(0.0, anchor * 0.53, 0.10),
				Vector3(0.0, anchor * 0.72, 0.11),
				Vector3(0.0, anchor * 0.90, 0.12),
			]
			var sizes := [Vector2(1.18, 1.24), Vector2(1.30, 1.00), Vector2(1.48, 0.72)]
			return {"position": positions[index], "size": sizes[index] * strength, "alpha": 0.22}
		_:
			return {
				"position": Vector3(0.0, anchor * (0.45 + float(index) * 0.18), 0.10),
				"size": Vector2.ONE * (0.80 - float(index) * 0.10) * strength,
				"alpha": 0.20,
			}


func _tendril_spec(index: int, release_peak: float, strength: float) -> Dictionary:
	var lane := float(index) - 2.5
	var spread := lane / 2.5
	var anchor := contact_anchor_meters
	match _move:
		"block_crush":
			var y := lerpf(anchor * 0.54, anchor * 0.90, float(index) / 5.0)
			var pull := Vector3(0.10 + spread * 0.18, y, 0.15)
			if release_peak > 0.10:
				pull = Vector3(0.18 + spread * 0.16, anchor - 0.12 - float(index % 3) * 0.20, 0.15)
			return {
				"position": pull,
				"size": Vector2(0.18 + absf(spread) * 0.03, lerpf(0.48, 0.94, strength)),
				"rotation": spread * 0.30,
			}
		"high_hands":
			return {
				"position": Vector3(0.24 + spread * 0.34, anchor - 0.02 + float(index % 3) * 0.16, 0.15),
				"size": Vector2(0.12, lerpf(0.44, 0.78, strength)),
				"rotation": -0.46 + spread * 0.34,
			}
		"foresight":
			var side := 1.0 if _succeeded else (-1.0 if index < 3 else 1.0)
			return {
				"position": Vector3(side * (0.26 + float(index % 3) * 0.20), 0.62 + float(index % 2) * 0.24, 0.15),
				"size": Vector2(0.13, lerpf(0.40, 0.70, strength)),
				"rotation": side * (PI * 0.5 - 0.22 + float(index % 3) * 0.08),
			}
		"heroics":
			var side := -1.0 if index % 2 == 0 else 1.0
			return {
				"position": Vector3(-0.26 + spread * 0.44, 0.44 + float(index % 3) * 0.18, 0.15),
				"size": Vector2(0.16 + float(index % 2) * 0.04, lerpf(0.54, 1.02, strength)),
				"rotation": side * (0.88 + float(index % 3) * 0.12),
			}
		"monster_block":
			return {
				"position": Vector3(spread * 0.54, anchor - 0.20 + float(index % 2) * 0.18, 0.15),
				"size": Vector2(0.15, lerpf(0.52, 0.90, strength)),
				"rotation": spread * 0.18,
			}
		_:
			return {
				"position": Vector3(spread * 0.30, anchor * 0.65, 0.15),
				"size": Vector2(0.15, 0.62),
				"rotation": spread * 0.20,
			}


func _body_center() -> Vector3:
	match _move:
		"block_crush":
			return Vector3(0.04, contact_anchor_meters * 0.56, 0.10)
		"high_hands":
			return Vector3(0.06, contact_anchor_meters * 0.58, 0.10)
		"foresight":
			return Vector3(0.0, 0.86, 0.11)
		"heroics":
			return Vector3(-0.04, 0.67, 0.11)
		"monster_block":
			return Vector3(0.0, contact_anchor_meters * 0.62, 0.10)
		_:
			return Vector3(0.0, contact_anchor_meters * 0.55, 0.10)


func _set_glow(visual: MeshInstance3D, colour: Color, alpha: float) -> void:
	var material := visual.material_override as StandardMaterial3D
	if material == null:
		return
	alpha = clampf(alpha, 0.0, 0.72)
	visual.visible = alpha > 0.003
	material.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	material.emission = Color(colour.r, colour.g, colour.b, 1.0)
	## Let opacity carry most of the energy. Keeping the multiplier moderate is
	## what stops the soft sprites from turning back into hard white objects.
	material.emission_energy_multiplier = lerpf(0.45, 2.15, alpha / 0.72)


func clear() -> void:
	_move = ""
	_charge = 0.0
	_succeeded = false
	visible = false
