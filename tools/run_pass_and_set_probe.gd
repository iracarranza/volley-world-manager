extends Node

## How high a pass actually goes, and what the setter does with it.
##
##     xvfb-run -a godot --path . res://tools/pass_and_set_probe.tscn
##
## Four questions, all of them currently answered by reading constants rather
## than by measuring the population they act on:
##
## 1. **How high is a bump?** `PASS_APEX_RISE_MIN/MAX` say 1.05-2.90 m above the
##    platform, but the band is only what the ends allow -- `execution` decides
##    where in it a pass lands, and nothing has ever printed that distribution.
## 2. **How often is the ball above the setter's hands?** A pass that apexes
##    below `set_contact_height_meters` has to be bumped, and a bump set is a
##    penalty this engine already prices. If most passes are below it, the
##    standard second contact in this game is an underhand one.
## 3. **How much time does the setter get?** Read the pass, scan the block,
##    check the hitter, square up, release. If that window is short, a standing
##    set is the only thing physically available and set quality should say so.
## 4. **Does a set drift?** `intended_target` and `end_position` are both on the
##    event. The gap between them is delivery error; whether it grows with
##    distance and shrinks with the setter is the question, and it is answerable
##    from data that already exists.
const RALLIES: int = 1200


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Pass Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	var apex: Array[float] = []
	var above_hands := 0
	var passes := 0
	var windows: Array[float] = []
	var drift: Array[float] = []
	var drift_by_distance := {"short (<3m)": [], "mid (3-6m)": [], "long (>6m)": []}
	var distances: Array[float] = []
	var postures := {}
	var release: Array[float] = []
	var margins: Array[float] = []
	var serve_apex: Array[float] = []
	var serve_by_style := {}
	var attack_apex: Array[float] = []
	for index in range(RALLIES):
		var result: Resource = game_manager.resolve_active_rally(
			hash("passprobe|%d" % index)
		)
		if result == null:
			continue
		for raw in result.events:
			var event: Resource = raw
			if event == null:
				continue
			var flight: Dictionary = event.metadata.get("outgoing_trajectory", {})
			var rise := float(flight.get("apex_rise_meters", flight.get(
				"apex_height_meters", 0.0
			)))
			match int(event.event_type):
				RallyEvent.EventType.SERVE:
					## How far the ball climbs above where it was struck. A serve
					## is a flat ball; anything that reads like a lob here is
					## either a sky ball or a defect.
					serve_apex.append(rise)
					## In or out. The arc solver falls back to a minimum-force
					## solve when nothing the server has clears the tape, and a
					## minimum-force solve is a lob -- so if the high tail is
					## failed serves, this splits it out.
					var style := "%s / %s" % [
						str(event.metadata.get("serve_style", "?")),
						"in" if bool(event.success) else "OUT",
					]
					var bucket: Array = serve_by_style.get(style, [])
					bucket.append(rise)
					serve_by_style[style] = bucket
				RallyEvent.EventType.ATTACK:
					attack_apex.append(rise)
				RallyEvent.EventType.RECEPTION, RallyEvent.EventType.DEFENSE:
					var pass_apex := float(event.metadata.get("pass_apex_meters", 0.0))
					if pass_apex <= 0.0:
						continue
					passes += 1
					apex.append(pass_apex)
					## The reach a setter of ordinary height has with hands
					## above the head. Compared against, not derived from, the
					## event -- the point is how much of the population clears it.
					if pass_apex >= SET_HANDS_HEIGHT_METERS:
						above_hands += 1
				RallyEvent.EventType.SET:
					## The whole budget between the pass being played and the
					## ball leaving the setter's hands: travel, read, square up.
					var window := float(event.metadata.get("movement_duration", 0.0)) \
						+ float(event.metadata.get("release_interval", 0.0))
					if window > 0.0:
						windows.append(window)
					var posture := "%s / %s" % [
						str(event.metadata.get("set_posture", "?")),
						str(event.metadata.get("set_posture_reason", "?")),
					]
					postures[posture] = int(postures.get(posture, 0)) + 1
					if event.metadata.has("arrival_margin"):
						margins.append(float(event.metadata["arrival_margin"]))
					if event.metadata.has("set_release_height_meters"):
						release.append(float(
							event.metadata["set_release_height_meters"]
						))
					if not event.metadata.has("intended_target"):
						continue
					var intended := Vector2(event.metadata["intended_target"])
					var landed: Vector2 = event.end_position
					var missed := RallyKinematics.court_delta_meters(
						intended, landed
					).length()
					drift.append(missed)
					var distance := float(event.metadata.get(
						"set_distance_meters", RallyKinematics.court_delta_meters(
							event.start_position, landed
						).length()
					))
					distances.append(distance)
					var bucket := "long (>6m)"
					if distance < 3.0:
						bucket = "short (<3m)"
					elif distance <= 6.0:
						bucket = "mid (3-6m)"
					var samples: Array = drift_by_distance[bucket]
					samples.append(missed)
					drift_by_distance[bucket] = samples

	print("=== pass and set: %d rallies, %d passes" % [RALLIES, passes])
	_report("pass apex above the floor (m)", apex)
	print("passes apexing above a setter's hands (%.2f m): %d of %d (%.2f%%)" % [
		SET_HANDS_HEIGHT_METERS, above_hands, passes,
		100.0 * float(above_hands) / maxf(float(passes), 1.0),
	])
	print("--- how high the struck balls climb above the contact")
	_report("serve rise (m)", serve_apex)
	var style_keys: Array = serve_by_style.keys()
	style_keys.sort()
	for style in style_keys:
		_report("  serve rise, %s" % style, serve_by_style[style])
	_report("attack rise (m)", attack_apex)
	print("--- the setter's budget")
	_report("travel + release before the ball leaves the hands (s)", windows)
	print("--- posture")
	var posture_keys: Array = postures.keys()
	posture_keys.sort()
	for key in posture_keys:
		print("  %-34s %d" % [key, int(postures[key])])
	_report("release height (m)", release)
	## What the jump-set decision is actually gated on. If this sits below
	## JUMP_SET_LOAD_SECONDS for most of the population then the posture is
	## decided by a broken instrument rather than by a threshold worth tuning.
	_report("setter arrival margin (s)", margins)
	print("--- delivery")
	_report("set distance (m)", distances)
	_report("drift from the intended target (m)", drift)
	for bucket in ["short (<3m)", "mid (3-6m)", "long (>6m)"]:
		_report("  %s" % bucket, drift_by_distance[bucket])


## Roughly where an average setter's hands are with the ball above the forehead,
## standing. Stated here rather than read off a player so the share above it is
## one number against one bar, not a per-voli comparison that hides the spread.
const SET_HANDS_HEIGHT_METERS: float = 2.25


func _report(label: String, samples: Array) -> void:
	if samples.is_empty():
		print("%s: no samples" % label)
		return
	var values: Array[float] = []
	for value in samples:
		values.append(float(value))
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	print("%s: n=%d  min %.2f  p05 %.2f  median %.2f  mean %.2f  p95 %.2f  max %.2f" % [
		label, values.size(), values[0],
		values[int(floor(float(values.size() - 1) * 0.05))],
		values[values.size() / 2],
		total / float(values.size()),
		values[int(floor(float(values.size() - 1) * 0.95))],
		values[-1],
	])
