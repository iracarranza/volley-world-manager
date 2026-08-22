class_name SurfaceMarkRenderer3D
extends Node

## Paints a voli's identity markings as colour on the existing skin meshes.
##
## `BodyTypeModels` predates this renderer and still describes tabby bars, spots,
## blazes, patches, speckles and scars as tiny cosmetic meshes. That was useful
## for proving the marking vocabulary, but it made pigmentation change silhouette:
## a spot was literally a flattened sphere bolted onto an arm, then the ink pass
## grew another hull around it. At an oblique camera angle those read as bumps,
## plates and scars with thickness.
##
## This component is deliberately downstream of that data. It keeps the existing
## deterministic marking choice and weighting, hides only the legacy mark meshes,
## and redraws the same coat family in a material overlay on Head / arm skin.
## Anatomy (ears, muzzle, beak, crown, tail, lobes, etc.) remains real geometry.
##
## The rig faces -Z. Head marks therefore live on the -Z hemisphere, matching the
## expression system's own `_surface()` convention rather than the old +Z mark
## placement, which had quietly put "face" markings on the back of the skull.

const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")

const PATTERN_NONE: int = 0
const PATTERN_TABBY: int = 1
const PATTERN_SPOTS: int = 2
const PATTERN_BLAZE: int = 3
const PATTERN_PATCH: int = 4
const PATTERN_SPECKLE: int = 5
const PATTERN_SCAR: int = 6

const LEGACY_MARK_PREFIXES: Array[String] = [
	"Tabby", "Spot", "Blaze", "Patch", "Speckle", "Scar",
]

var _signature: String = ""
var _suppressed_for_mask: bool = false
var _shader: Shader = null


func _ready() -> void:
	set_process(true)
	call_deferred("_sync")


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var actor := get_parent()
	if actor == null:
		return
	var silhouette_value: Variant = actor.get("silhouette")
	if not (silhouette_value is Dictionary):
		return
	var silhouette: Dictionary = silhouette_value
	if silhouette.is_empty():
		return

	## Hide the compatibility geometry every frame. This is intentionally cheap:
	## old marks only ever live directly under BodyPivot or either shoulder root,
	## so this walks three short child lists rather than the whole actor tree. It
	## also catches an actor reconfigured to the same player/marking, where the
	## semantic signature is unchanged but `_build_cosmetics()` made new nodes.
	_hide_legacy_mark_geometry(actor)

	var head := actor.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	if head == null:
		return
	if _mask_pass_active(actor, head):
		if not _suppressed_for_mask:
			_clear_overlays(actor)
			_suppressed_for_mask = true
		return
	if _suppressed_for_mask:
		## `VoliSticker` restores the real palette immediately after its black /
		## white arm-mask read. Rebuild on the next frame so the colour bake keeps
		## the markings while the contour mask never sees them.
		_suppressed_for_mask = false
		_signature = ""

	var player_id := int(actor.get("player_id"))
	var body_type := str(actor.get("body_type"))
	var appearance_value: Variant = actor.get("appearance")
	var appearance: Dictionary = {}
	if appearance_value is Dictionary:
		appearance = appearance_value
	var marking := BodyTypeModelsScript.chosen_marking(
		body_type, player_id, appearance
	)
	var skin: Color = silhouette.get("skin", Color("d6a06c"))
	var flat := bool(actor.get("flat_shading"))
	var next_signature := "%d|%s|%s|%s|%s" % [
		player_id, body_type, marking, skin.to_html(true), str(flat),
	]
	if next_signature == _signature:
		return
	_signature = next_signature
	_clear_overlays(actor)
	if marking == "none":
		return

	var pattern := _pattern_id(marking)
	if pattern == PATTERN_NONE:
		return
	var seed_offset := absi(hash("coat:%d" % player_id))
	var mark_side := 1.0 if (seed_offset & 1) == 0 else -1.0
	var scar_arm_side := -1.0 if (seed_offset & 1) == 0 else 1.0
	var ink := skin.darkened(0.34) if skin.get_luminance() > 0.22 \
		else skin.lightened(0.30)
	if marking == "scar":
		ink = skin.lightened(0.55)
	elif marking == "blaze":
		ink = skin.lightened(0.30).lerp(Color("f2e6c8"), 0.35)

	_apply_overlay(
		head, pattern, 0, 0.0, 0, mark_side, scar_arm_side,
		float(seed_offset % 10007), ink, flat,
	)
	## The two-bone arm means a surface pattern follows the elbow for free. The
	## old cosmetic marks were parented to the shoulder even when placed halfway
	## down the full arm, so a bent elbow could leave a "forearm" mark floating
	## beside the forearm. Each segment now carries its own part of the coat.
	for side_info in [
		["BodyPivot/LeftArm", -1.0],
		["BodyPivot/RightArm", 1.0],
	]:
		var arm_root := actor.get_node_or_null(str(side_info[0])) as Node3D
		if arm_root == null:
			continue
		var upper := arm_root.get_node_or_null("Mesh") as MeshInstance3D
		var elbow := arm_root.get_node_or_null("Elbow") as Node3D
		var fore: MeshInstance3D = null
		if elbow != null:
			fore = elbow.get_node_or_null("Mesh") as MeshInstance3D
		if upper != null:
			_apply_overlay(
				upper, pattern, 1, float(side_info[1]), 0,
				mark_side, scar_arm_side, float(seed_offset % 10007), ink, flat,
			)
		if fore != null:
			_apply_overlay(
				fore, pattern, 1, float(side_info[1]), 1,
				mark_side, scar_arm_side, float(seed_offset % 10007), ink, flat,
			)


func _pattern_id(marking: String) -> int:
	match marking:
		"tabby":
			return PATTERN_TABBY
		"spots":
			return PATTERN_SPOTS
		"blaze":
			return PATTERN_BLAZE
		"patch":
			return PATTERN_PATCH
		"speckle":
			return PATTERN_SPECKLE
		"scar":
			return PATTERN_SCAR
	return PATTERN_NONE


func _is_legacy_mark_name(node_name: String) -> bool:
	for prefix in LEGACY_MARK_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _hide_legacy_mark_geometry(actor: Node) -> void:
	for path in ["BodyPivot", "BodyPivot/LeftArm", "BodyPivot/RightArm"]:
		var parent := actor.get_node_or_null(path)
		if parent == null:
			continue
		for child in parent.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null or not mesh.has_meta("cosmetic"):
				continue
			if not _is_legacy_mark_name(str(mesh.name)):
				continue
			mesh.visible = false
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin_meshes(actor: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var head := actor.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	if head != null:
		meshes.append(head)
	for root_path in ["BodyPivot/LeftArm", "BodyPivot/RightArm"]:
		var root := actor.get_node_or_null(root_path) as Node3D
		if root == null:
			continue
		var upper := root.get_node_or_null("Mesh") as MeshInstance3D
		if upper != null:
			meshes.append(upper)
		var elbow := root.get_node_or_null("Elbow") as Node3D
		var fore: MeshInstance3D = null
		if elbow != null:
			fore = elbow.get_node_or_null("Mesh") as MeshInstance3D
		if fore != null:
			meshes.append(fore)
	return meshes


func _clear_overlays(actor: Node) -> void:
	for mesh in _skin_meshes(actor):
		var overlay := mesh.material_overlay
		if overlay != null and overlay.has_meta("voli_surface_mark"):
			mesh.material_overlay = null


func _mask_pass_active(actor: Node, head: MeshInstance3D) -> bool:
	## `VoliSticker` paints the whole body exact black, then the arms exact white,
	## to recover an arm contour. A surface overlay must disappear for that one
	## render or its coat colour becomes a false island in the binary mask.
	if not bool(actor.get("flat_shading")):
		return false
	var material := head.material_override as StandardMaterial3D
	if material == null:
		return false
	var color := material.albedo_color
	return _same_color(color, Color.BLACK) or _same_color(color, Color.WHITE)


func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.0001 \
		and absf(a.g - b.g) < 0.0001 \
		and absf(a.b - b.b) < 0.0001 \
		and absf(a.a - b.a) < 0.0001


func _apply_overlay(
	mesh: MeshInstance3D,
	pattern: int,
	part_kind: int,
	arm_side: float,
	segment_index: int,
	mark_side: float,
	scar_arm_side: float,
	seed: float,
	ink: Color,
	flat: bool,
) -> void:
	if mesh.mesh == null:
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _shader_code()
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.render_priority = 1
	material.set_meta("voli_surface_mark", true)
	var bounds := mesh.get_aabb()
	material.set_shader_parameter("bounds_center", bounds.position + bounds.size * 0.5)
	material.set_shader_parameter("bounds_half", bounds.size * 0.5)
	material.set_shader_parameter("pattern", pattern)
	material.set_shader_parameter("part_kind", part_kind)
	material.set_shader_parameter("arm_side", arm_side)
	material.set_shader_parameter("segment_index", segment_index)
	material.set_shader_parameter("mark_side", mark_side)
	material.set_shader_parameter("scar_arm_side", scar_arm_side)
	material.set_shader_parameter("seed_value", seed)
	material.set_shader_parameter("mark_color", ink)
	material.set_shader_parameter("flat_mode", flat)
	mesh.material_overlay = material


func _shader_code() -> String:
	return """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform int pattern = 0;
uniform int part_kind = 0;
uniform float arm_side = 0.0;
uniform int segment_index = 0;
uniform float mark_side = 1.0;
uniform float scar_arm_side = -1.0;
uniform float seed_value = 0.0;
uniform vec4 mark_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform bool flat_mode = false;
uniform vec3 bounds_center = vec3(0.0);
uniform vec3 bounds_half = vec3(1.0);

varying vec3 mark_local;
const float PI_F = 3.14159265359;

float hash11(float n) {
	return fract(sin(n * 12.9898 + seed_value * 0.071) * 43758.5453);
}

float soft_disc(vec2 p, vec2 centre, float radius) {
	float d = distance(p, centre);
	return 1.0 - smoothstep(radius * 0.78, radius, d);
}

float head_pattern(vec3 q) {
	// The rig and the expression system both face -Z.
	float front = 1.0 - smoothstep(-0.22, 0.08, q.z);
	float m = 0.0;
	if (pattern == 1) {
		// Three brow bars with tiny deterministic changes in slope/height.
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float y0 = 0.43 - fi * 0.24 + (hash11(10.0 + fi) - 0.5) * 0.045;
			float slope = (hash11(20.0 + fi) - 0.5) * 0.16;
			float line = abs(q.y - (y0 + slope * q.x));
			float stroke = 1.0 - smoothstep(0.043, 0.066, line);
			float width = 1.0 - smoothstep(0.46, 0.72, abs(q.x));
			m = max(m, stroke * width * front);
		}
	} else if (pattern == 2) {
		// One facial spot; the rest of this coat lives around the arms.
		vec2 centre = vec2(0.48 * mark_side, -0.16);
		m = soft_disc(q.xy, centre, 0.18) * front;
	} else if (pattern == 3) {
		// A blaze is a field of coat, not a raised capsule: broad at the brow,
		// tapering toward the muzzle and following the skull automatically.
		float width = mix(0.13, 0.22, clamp((q.y + 0.62) / 1.25, 0.0, 1.0));
		float stripe = 1.0 - smoothstep(width, width + 0.035, abs(q.x));
		float vertical = smoothstep(-0.70, -0.50, q.y) * (1.0 - smoothstep(0.72, 0.86, q.y));
		m = stripe * vertical * front;
	} else if (pattern == 4) {
		// Eye patch. The face solids remain above it, so the eye is still legible.
		vec2 p = vec2(q.x - 0.40 * mark_side, q.y - 0.18);
		p.x *= 1.08;
		p.y *= 0.88;
		m = (1.0 - smoothstep(0.30, 0.35, length(p))) * front;
	} else if (pattern == 5) {
		// Actual speckling: many tiny pigment islands rather than five beads.
		for (int i = 0; i < 13; i++) {
			float fi = float(i);
			vec2 centre = vec2(
				hash11(40.0 + fi * 3.1) * 1.12 - 0.56,
				hash11(80.0 + fi * 5.3) * 0.92 - 0.34
			);
			float radius = 0.035 + hash11(120.0 + fi) * 0.028;
			m = max(m, soft_disc(q.xy, centre, radius) * front);
		}
	} else if (pattern == 6) {
		// Thin diagonal change in coat tone. No thickness, no cast shadow.
		float signed_line = q.y - (0.13 + mark_side * 0.82 * (q.x - 0.18 * mark_side));
		float stroke = 1.0 - smoothstep(0.027, 0.048, abs(signed_line));
		float extent = 1.0 - smoothstep(0.34, 0.48, abs(q.x - 0.18 * mark_side));
		m = stroke * extent * front;
	}
	return m;
}

float arm_pattern(vec3 q) {
	float m = 0.0;
	float angle = atan(q.x, -q.z) / PI_F; // 0 is the front of the arm.
	if (pattern == 1) {
		// Rings are genuinely circumferential because the mask depends only on Y.
		if (segment_index == 0) {
			float a = 1.0 - smoothstep(0.055, 0.085, abs(q.y - 0.30));
			float b = 1.0 - smoothstep(0.055, 0.085, abs(q.y + 0.42));
			m = max(a, b);
		} else {
			m = 1.0 - smoothstep(0.055, 0.085, abs(q.y - 0.10));
		}
	} else if (pattern == 2) {
		// Spots use angle + height, so they wrap around the limb instead of
		// becoming flat pills stuck to the camera-facing side.
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float local_seed = seed_value + arm_side * 31.0 + float(segment_index) * 67.0;
			float cx = fract(sin(local_seed * 0.013 + fi * 4.17) * 43758.5453) * 1.55 - 0.775;
			float cy = fract(sin(local_seed * 0.021 + fi * 7.91) * 24634.6345) * 1.50 - 0.75;
			float radius = 0.11 + fract(sin(local_seed + fi * 9.3) * 15731.743) * 0.055;
			float dx = abs(angle - cx);
			dx = min(dx, 2.0 - dx); // seam-safe around the cylinder.
			m = max(m, 1.0 - smoothstep(radius * 0.76, radius, length(vec2(dx, q.y - cy))));
		}
	} else if (pattern == 6 && segment_index == 1 && abs(arm_side - scar_arm_side) < 0.1) {
		// One forearm scar, diagonal across the cylindrical surface.
		float line = q.y - 0.70 * angle;
		float stroke = 1.0 - smoothstep(0.035, 0.060, abs(line));
		float around = 1.0 - smoothstep(0.32, 0.50, abs(angle));
		m = stroke * around;
	}
	return m;
}

void vertex() {
	mark_local = VERTEX;
}

void fragment() {
	vec3 safe_half = max(bounds_half, vec3(0.0001));
	vec3 q = (mark_local - bounds_center) / safe_half;
	float mask = part_kind == 0 ? head_pattern(q) : arm_pattern(q);
	if (mask < 0.38) {
		discard;
	}
	ROUGHNESS = 0.78;
	if (flat_mode) {
		// Sticker bake: reproduce the actor's unshaded colour regions without
		// forcing the live court actor to become unlit too.
		ALBEDO = vec3(0.0);
		EMISSION = mark_color.rgb;
	} else {
		ALBEDO = mark_color.rgb;
		EMISSION = vec3(0.0);
	}
}
"""
