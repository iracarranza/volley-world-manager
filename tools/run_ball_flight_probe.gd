extends SceneTree

## Does the drawn ball fly like a ball?
##
##     godot --headless --path . --script res://tools/run_ball_flight_probe.gd
##
## Reported from watching playback: "the ball takes a flat moving trajectory
## until it reaches the x/z coordinate of the floor or voli it reaches, then
## teleports down to continue the play."
##
## That is a claim about a *shape*, so it needs an instrument that measures shape
## rather than endpoints. Every existing playback probe checks that the ball
## finishes where the next contact begins -- `run_contact_continuity_probe` does
## exactly that -- and a ball that flies flat and then drops passes every one of
## them, because both of its ends are right. The whole defect lives in the middle.
##
## **The measure: what gravity the drawn ball appears to fall under.** Both
## curves are quadratics in the flight fraction, so comparing their shapes by eye
## or by "where does it drop" gets nowhere -- what separates them is one
## coefficient. Writing the retired hump out,
##
##     h(t) = lerp(h0, h1, t) + 4A*t*(1-t),   A = apex - midpoint
##
## its t-squared term is -4A, and a real flight's is -g*T^2/2. So the hump draws a
## ball falling under an implied `8A / T^2`, and dividing that by 9.8 says how
## many times too hard the drawn ball was being pulled down. A ball under six
## times gravity thrown six times too hard upward stays high and then plummets,
## which is the reported symptom exactly: it is not that the old curve was not a
## parabola, it is that it was the wrong parabola and the error was concentrated
## in the middle where nothing was checking.
##
## Also reported per contact pair, because the fix has one way to go wrong that
## the descent share cannot see. The old drawn apex was *floored* above the net
## for serves and sets -- clearance was guaranteed by presentation rather than
## earned by the flight -- so removing the floor can put a ball through the tape.
## `net_crossing_height` is the check for that, and a serve or set drawn under
## 2.43 m at the crossing is a defect this change would have introduced.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 120
const NET_HEIGHT_METERS: float = CourtConstants.NET_HEIGHT_METERS


## The retired curve's implied gravity, and how far it sat from the real flight,
## measured on the same flights.
##
## Kept in the probe rather than described in prose so the comparison can be
## re-run rather than believed. It is the only copy of the old formula left
## anywhere.
var legacy_gravity := {}
var legacy_error := {}

## What each pass was worth to the setter, bucketed by how well it was received.
const PASS_BANDS: Array[String] = [
	"0.0-0.2", "0.2-0.4", "0.4-0.6", "0.6-0.8", "0.8-1.0",
]
var pass_bands := {}


func _initialize() -> void:
	var by_pair := {}
	var crossings := {}
	var under_the_net: Array[Dictionary] = []
	var sampled := 0
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(7000, 7000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			sampled += _collect(result, by_pair, crossings, under_the_net)
		manager.free()

	print("=== drawn flights sampled: %d ===" % sampled)
	print("")
	print("The gravity the retired curve implied, and how far from the real")
	print("flight it drew the ball. The current curve is 1.00 g by construction.")
	print("")
	print("%-24s %6s %10s %10s %10s %10s" % [
		"contact pair", "n", "was, x g", "worst x g", "off by m", "worst m",
	])
	var pair_names := by_pair.keys()
	pair_names.sort()
	for key in pair_names:
		var gravity: Array = legacy_gravity.get(key, [])
		var error: Array = legacy_error.get(key, [])
		gravity.sort()
		error.sort()
		var gravity_total := 0.0
		for value in gravity:
			gravity_total += float(value)
		var error_total := 0.0
		for value in error:
			error_total += float(value)
		print("%-24s %6d %10.2f %10.2f %10.2f %10.2f" % [
			key, int(by_pair[key].size()),
			gravity_total / maxf(float(gravity.size()), 1.0),
			float(gravity[gravity.size() - 1]) if not gravity.is_empty() else 0.0,
			error_total / maxf(float(error.size()), 1.0),
			float(error[error.size() - 1]) if not error.is_empty() else 0.0,
		])

	print("")
	print("=== height at the tape, metres (net is %.2f) ===" % NET_HEIGHT_METERS)
	print("%-24s %6s %8s %8s %8s" % ["contact pair", "n", "mean", "min", "under"])
	var crossing_names := crossings.keys()
	crossing_names.sort()
	for key in crossing_names:
		var values: Array = crossings[key]
		values.sort()
		var total := 0.0
		var under := 0
		for value in values:
			total += float(value)
			if float(value) < NET_HEIGHT_METERS:
				under += 1
		print("%-24s %6d %8.2f %8.2f %8d" % [
			key, values.size(), total / float(values.size()),
			float(values[0]), under,
		])

	print("")
	print("=== what a pass buys the setter, by reception quality ===")
	print("A good pass is a high one, and height is time. If this table is flat,")
	print("or slopes the wrong way, the second contact is not being paid for.")
	print("")
	print("%-16s %6s %10s %10s" % ["reception", "n", "apex m", "hang s"])
	for band in PASS_BANDS:
		var values: Array = pass_bands.get(band, [])
		if values.is_empty():
			print("%-16s %6d %10s %10s" % [band, 0, "--", "--"])
			continue
		var apex_total := 0.0
		var hang_total := 0.0
		for entry in values:
			apex_total += float(entry.apex)
			hang_total += float(entry.hang)
		print("%-16s %6d %10.2f %10.2f" % [
			band, values.size(),
			apex_total / float(values.size()),
			hang_total / float(values.size()),
		])

	if not under_the_net.is_empty():
		print("")
		print("=== worst five flights drawn through the net ===")
		under_the_net.sort_custom(func(a, b): return float(a.height) < float(b.height))
		for index in range(mini(5, under_the_net.size())):
			var case: Dictionary = under_the_net[index]
			print("  %-22s %.2f m at the tape, %.2f s, %.2f m -> %.2f m, seed %d" % [
				case.pair, case.height, case.duration,
				case.start_height, case.end_height, case.seed,
			])
	quit()


func _collect(
	result: Resource,
	by_pair: Dictionary,
	crossings: Dictionary,
	under_the_net: Array[Dictionary],
) -> int:
	var contacts: Array = []
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) in [
			RallyEventScript.EventType.SET_DECISION,
			RallyEventScript.EventType.POINT,
		]:
			continue
		contacts.append(event)
	var profiles: Dictionary = result.player_physical_profiles
	var counted := 0
	for index in range(contacts.size()):
		var event: Resource = contacts[index]
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			continue
		var next_contact: Resource = contacts[index + 1] \
			if index + 1 < contacts.size() else null
		## The screen's own function, not a copy of it. A probe that re-derived
		## the drawn flight would be measuring its own arithmetic.
		var display := BallPresentation.display_trajectory(
			event, next_contact, trajectory, profiles
		)
		counted += 1
		var key := "%s -> %s" % [
			event.type_name(),
			"floor" if next_contact == null else next_contact.type_name(),
		]
		if not by_pair.has(key):
			by_pair[key] = []
		(by_pair[key] as Array).append(true)
		var legacy := _legacy_display(event, display, trajectory)
		if not legacy_gravity.has(key):
			legacy_gravity[key] = []
			legacy_error[key] = []
		(legacy_gravity[key] as Array).append(_implied_gravity(legacy))
		(legacy_error[key] as Array).append(_worst_height_gap(legacy, display))
		if int(event.event_type) in [
			RallyEventScript.EventType.RECEPTION,
			RallyEventScript.EventType.DEFENSE,
		]:
			var band := PASS_BANDS[clampi(
				int(floor(clampf(float(event.quality), 0.0, 0.999) * 5.0)), 0, 4
			)]
			if not pass_bands.has(band):
				pass_bands[band] = []
			(pass_bands[band] as Array).append({
				"apex": float(display.get("apex_height_meters", 0.0)),
				"hang": float(display.get("duration", 0.0)),
			})
		var tape := BallPresentation.net_crossing_height(display)
		if tape >= 0.0:
			if not crossings.has(key):
				crossings[key] = []
			(crossings[key] as Array).append(tape)
			if tape < NET_HEIGHT_METERS:
				under_the_net.append({
					"pair": key, "height": tape,
					"duration": float(display.get("duration", 0.0)),
					"start_height": float(display.get("start_height_meters", 0.0)),
					"end_height": float(display.get("end_height_meters", 0.0)),
					"seed": int(result.rally_seed) if "rally_seed" in result else 0,
				})
	return counted


## What gravity the retired curve was drawing, as a multiple of the real one.
##
## Read off the coefficient rather than fitted: the hump's t-squared term is
## exactly -4A in flight fraction, and a real parabola's is -g*T^2/2, so the two
## are the same curve only when 8A equals g*T^2.
func _implied_gravity(legacy: Dictionary) -> float:
	var duration := maxf(float(legacy.get("duration", 0.5)), 0.08)
	var start_height := float(legacy.get("start_height_meters", 1.0))
	var end_height := float(legacy.get("end_height_meters", 1.0))
	var apex := float(legacy.get("legacy_apex_height_meters", 1.0))
	var arc := maxf(apex - lerpf(start_height, end_height, 0.5), 0.0)
	return (8.0 * arc / (duration * duration)) / BallFlightModel.DEFAULT_GRAVITY_MPS2


## The furthest apart the two curves ever put the same ball, in metres.
##
## The number that says whether the shape difference is worth anything. Both
## curves agree at both ends by construction, so anything found here is entirely
## in the middle of the flight, which is the part nobody was checking.
func _worst_height_gap(legacy: Dictionary, display: Dictionary) -> float:
	var worst := 0.0
	for step in range(0, 101):
		var t := float(step) / 100.0
		worst = maxf(worst, absf(
			_legacy_height(legacy, t)
				- float(BallPresentation.sample(display, t)["height_meters"])
		))
	return worst


## The curve this change retired, for comparison only.
##
## A symmetric hump between the two contact heights, with an apex manufactured
## from a per-action lift table:
##
##     h(t) = lerp(h0, h1, t) + 4*(apex - midpoint)*t*(1-t)
##
## The floors are the part worth looking at twice. A serve was lifted to at least
## net + 0.48 and a set to net + 1.05 *whatever their flight time was*, so net
## clearance was a property of the drawing rather than of the ball -- which is
## why the tape column in this probe did not exist and could not have.
func _legacy_display(
	event: Resource, display: Dictionary, source: Dictionary
) -> Dictionary:
	var legacy := display.duplicate(true)
	var start_height := float(display.get("start_height_meters", 1.0))
	var end_height := float(display.get("end_height_meters", 1.0))
	var rise := maxf(float(source.get(
		"apex_rise_meters", source.get("apex_height_meters", 0.0)
	)), 0.0)
	var rise_scale := 1.0
	var minimum_lift := 0.25
	match int(event.event_type):
		RallyEventScript.EventType.SERVE:
			rise_scale = 1.35
			minimum_lift = 0.42
		RallyEventScript.EventType.RECEPTION, RallyEventScript.EventType.DEFENSE:
			rise_scale = 1.55
			minimum_lift = 0.62
		RallyEventScript.EventType.SET:
			rise_scale = 1.75
			minimum_lift = 0.90
		RallyEventScript.EventType.ATTACK:
			rise_scale = 0.35
			minimum_lift = 0.12
		RallyEventScript.EventType.BLOCK:
			rise_scale = 0.45
			minimum_lift = 0.16
	var apex := maxf(start_height, end_height) + maxf(rise * rise_scale, minimum_lift)
	match int(event.event_type):
		RallyEventScript.EventType.SERVE:
			apex = maxf(apex, NET_HEIGHT_METERS + 0.48)
		RallyEventScript.EventType.SET:
			apex = maxf(apex, NET_HEIGHT_METERS + 1.05)
		RallyEventScript.EventType.ATTACK:
			apex = maxf(apex, start_height + 0.08)
	legacy["legacy_apex_height_meters"] = apex
	return legacy


## The retired hump, sampled. `BallPresentation.sample` cannot draw it any more,
## which is the point of having retired it.
func _legacy_height(legacy: Dictionary, progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	var start_height := float(legacy.get("start_height_meters", 1.0))
	var end_height := float(legacy.get("end_height_meters", 1.0))
	var apex := float(legacy.get("legacy_apex_height_meters", 1.0))
	var base := lerpf(start_height, end_height, t)
	var midpoint := lerpf(start_height, end_height, 0.5)
	return base + 4.0 * maxf(apex - midpoint, 0.0) * t * (1.0 - t)
