extends Node

## Solve for the albedo that *renders* as the colour the palette names.
##
## Three separate things were wrong and only the third is interesting.
##
## 1. `tonemap_white` is inert -- four values, pixel-identical frames.
## 2. `FillLight.light_energy` is nearly inert -- 5.0 down to 0.6 moves the court
##    by six points. It was never the hot term.
## 3. **The court material and the palette are two sources of truth that were
##    never connected.** `match_court_3d.tscn` authors the surface at `#b86633`
##    by hand; `ui_palette.gd` calls `court_surface` `#cf8659`. Nothing ever
##    reconciled them, so "the 3D court does not match the palette" was true
##    before a single photon was traced.
##
## Fixing 3 needs more than pasting the hex into the material, because albedo is
## not what reaches the screen: it is lit, then tonemapped. So this measures the
## transfer instead of assuming it -- render, sample, correct each channel by the
## ratio it missed by, repeat. Four rounds converge, and the answer is an albedo
## that can be pasted into the scene with the receipt attached.
##
## Exposure is chosen for **headroom**, not for the default court: a stop that
## lands the terracotta but clips maple and board leaves three regional surfaces
## rendering as one white, which is the whole reason this began.
##
## Run:
##   xvfb-run -a godot --path . res://tools/court_albedo_solve.tscn

const COURT := preload("res://scenes/components/match_court_3d.tscn")

## From `ui_palette.gd`. The one authority; the material should follow it.
const TARGET := Color("cf8659")

## Pale surfaces that must stay apart from each other for regional courts to be
## possible at all. Their job here is to fail an exposure that is too hot.
const HEADROOM_PROBES: Array = [
	["concrete", Color(0.66, 0.64, 0.61)],
	["maple", Color(0.88, 0.75, 0.54)],
	["board", Color(0.79, 0.66, 0.46)],
]

const EXPOSURES: Array = [0.60, 0.50, 0.42, 0.35, 0.30]
const ROUNDS := 5
const PATCH := Vector2i(380, 560)
const PATCH_RADIUS := 14

var _floor: MeshInstance3D
var _env: WorldEnvironment


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var court := COURT.instantiate()
	add_child(court)
	await get_tree().process_frame
	_floor = court.get_node_or_null("CourtSurface") as MeshInstance3D
	_env = court.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _floor == null or _env == null:
		push_error("court is missing CourtSurface or WorldEnvironment")
		get_tree().quit()
		return
	print("target #%s (ui_palette court_surface)" % TARGET.to_html(false))
	print("expo | solved albedo | renders as | dE | headroom: concrete/maple/board")
	for exposure in EXPOSURES:
		_env.environment.tonemap_exposure = float(exposure)
		var solved := await _solve()
		var seen := await _render(solved)
		var clipped: Array[String] = []
		var shown: Array[String] = []
		for probe in HEADROOM_PROBES:
			var pale := await _render(Color(probe[1]))
			shown.append("#%s" % pale.to_html(false))
			if pale.r >= 0.996 or pale.g >= 0.996 or pale.b >= 0.996:
				clipped.append(str(probe[0]))
		print("%.2f | #%s | #%s | %.1f | %s %s" % [
			float(exposure), solved.to_html(false), seen.to_html(false),
			_distance(seen, TARGET), " ".join(shown),
			"CLIPS %s" % ", ".join(clipped) if not clipped.is_empty() else "ok",
		])
	get_tree().quit()


## Correct each channel by the factor it missed by. The transfer is monotonic per
## channel, so a ratio step converges without needing to model the curve -- and
## not modelling it is the point, because the curve is Godot's and may change.
func _solve() -> Color:
	var albedo := Color(0.72, 0.40, 0.20)
	for _round in range(ROUNDS):
		var seen := await _render(albedo)
		albedo = Color(
			clampf(albedo.r * (TARGET.r / maxf(seen.r, 0.004)), 0.0, 1.0),
			clampf(albedo.g * (TARGET.g / maxf(seen.g, 0.004)), 0.0, 1.0),
			clampf(albedo.b * (TARGET.b / maxf(seen.b, 0.004)), 0.0, 1.0)
		)
	return albedo


func _render(albedo: Color) -> Color:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.76
	_floor.material_override = material
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_tree().root.get_texture().get_image()
	var total := Vector3.ZERO
	var count := 0
	for y in range(PATCH.y - PATCH_RADIUS, PATCH.y + PATCH_RADIUS):
		for x in range(PATCH.x - PATCH_RADIUS, PATCH.x + PATCH_RADIUS):
			var pixel := image.get_pixel(x, y)
			total += Vector3(pixel.r, pixel.g, pixel.b)
			count += 1
	total /= maxf(float(count), 1.0)
	return Color(total.x, total.y, total.z)


func _distance(seen: Color, want: Color) -> float:
	return Vector3(
		(seen.r - want.r) * 255.0, (seen.g - want.g) * 255.0, (seen.b - want.b) * 255.0
	).length()
