extends Node

## How far playback time has drifted from the rally clock the simulator keeps.
##
##     xvfb-run -a godot --path . res://tools/playback_timing_probe.tscn
##
## The resolver already stamps every event with an `event_time` taken from its
## own cumulative `rally_clock`, and every ball flight already carries a real
## `duration`. Playback does not use either for pacing: `main.gd` paces a leg on
## `clampf(duration, 0.28, 2.60)` and a contact on `clampf(duration, 0.55,
## 2.60)`. Both clamps were written without measuring the distribution they act
## on, which is the failure `FAILURE_MODES.md` §0 names.
##
## This probe measures that distribution before anything is changed, so the size
## of the divergence is a number rather than an impression.

const LEG_FLOOR: float = 0.28
const LEG_CEILING: float = 2.60
const CONTACT_FLOOR: float = 0.55
const CONTACT_CEILING: float = 2.60
const RALLIES: int = 240

## What `main.gd` paces on now. Mirrored here rather than imported because
## `main.gd` cannot be loaded outside a booted scene tree -- so these two have to
## be kept in step by hand, and the probe says so where it prints them.
const SCALE: float = 1.8
const MINIMUM_PHASE: float = 0.06
const IMPLAUSIBLE: float = 6.0


## The stretch each event actually receives. One factor means this is flat; the
## clamps meant it ran from 1.0 to 4.6 across one rally, and that spread is what
## desynchronised the bodies from the ball.
static func _stretch_now(physical: float) -> float:
	var seconds := minf(maxf(physical, 0.0), IMPLAUSIBLE)
	var drawn := maxf(seconds * SCALE, MINIMUM_PHASE)
	return drawn / maxf(physical, 0.001)


static func _stretch_before(physical: float, low: float, high: float) -> float:
	return clampf(physical, low, high) / maxf(physical, 0.001)


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Timing Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	var leg_durations: Array[float] = []
	var legs_floored := 0
	var legs_ceilinged := 0
	var contact_durations: Array[float] = []
	var contacts_floored := 0
	var contacts_ceilinged := 0
	var contacts_without_a_duration := 0
	var rallies_read := 0
	var non_monotonic := 0
	var events_seen := 0
	var events_without_time := 0
	## What the rally would take if paced on the physical clock, against what
	## playback actually spends. The ratio is the headline.
	var physical_total := 0.0
	var playback_total := 0.0
	## Rallies whose last stamped event is earlier than the terminal ball's
	## landing, which is the "rally ends before the ball lands" report.
	var ends_early := 0
	var early_worst := 0.0

	for index in range(RALLIES):
		var result: Resource = game_manager.resolve_active_rally(
			hash("timing|%d" % index)
		)
		if result == null or result.events.is_empty():
			continue
		rallies_read += 1
		var previous_time := -1.0
		var last_time := 0.0
		var last_landing := 0.0
		for event_index in range(result.events.size()):
			var event: Resource = result.events[event_index]
			var metadata: Dictionary = event.metadata
			events_seen += 1
			if not metadata.has("event_time"):
				events_without_time += 1
				continue
			var stamp := float(metadata["event_time"])
			if stamp < previous_time - 0.0001:
				non_monotonic += 1
			previous_time = stamp
			last_time = maxf(last_time, stamp)

			var trajectory: Dictionary = metadata.get("outgoing_trajectory", {})
			if not trajectory.is_empty():
				var duration := float(trajectory.get("duration", 0.0))
				leg_durations.append(duration)
				legs_floored += int(duration < LEG_FLOOR)
				legs_ceilinged += int(duration > LEG_CEILING)
				physical_total += duration
				playback_total += clampf(duration, LEG_FLOOR, LEG_CEILING)
				last_landing = maxf(last_landing, float(
					trajectory.get("end_time", stamp + duration)
				))
				continue

			## A contact drawn in place. `main.gd` falls back to a made-up
			## figure when the event carries no `event_duration`, and how often
			## that happens is itself worth knowing.
			if not metadata.has("event_duration"):
				contacts_without_a_duration += 1
				continue
			var contact := float(metadata["event_duration"])
			contact_durations.append(contact)
			contacts_floored += int(contact < CONTACT_FLOOR)
			contacts_ceilinged += int(contact > CONTACT_CEILING)
			physical_total += contact
			playback_total += clampf(contact, CONTACT_FLOOR, CONTACT_CEILING)
		if last_landing > last_time + 0.0001:
			ends_early += 1
			early_worst = maxf(early_worst, last_landing - last_time)

	print("=== playback timing probe: %d rallies, %d events" % [
		rallies_read, events_seen
	])
	print("events with no event_time stamp: %d" % events_without_time)
	print("events out of chronological order: %d" % non_monotonic)
	print("contacts with no event_duration (main.gd invents one): %d"
		% contacts_without_a_duration)
	_report("ball legs", leg_durations, LEG_FLOOR, LEG_CEILING,
		legs_floored, legs_ceilinged)
	var absurd := 0
	for sample in leg_durations:
		absurd += int(sample > 4.0)
	print("   ball legs longer than 4s: %d" % absurd)
	_report("in-place contacts", contact_durations, CONTACT_FLOOR,
		CONTACT_CEILING, contacts_floored, contacts_ceilinged)
	print("physical seconds: %.1f | playback seconds: %.1f | ratio %.3f" % [
		physical_total, playback_total,
		playback_total / maxf(physical_total, 0.001),
	])
	## The headline. An event's *stretch* is how much longer than life it is
	## drawn; if the spread of stretches across a rally is not flat, the bodies
	## and the ball are on different clocks no matter what the total says.
	var everything: Array[float] = []
	for sample in leg_durations:
		everything.append(sample)
	for sample in contact_durations:
		everything.append(sample)
	var was: Array[float] = []
	var now: Array[float] = []
	for index in range(everything.size()):
		var physical: float = everything[index]
		var is_leg := index < leg_durations.size()
		was.append(_stretch_before(
			physical,
			LEG_FLOOR if is_leg else CONTACT_FLOOR,
			LEG_CEILING if is_leg else CONTACT_CEILING,
		))
		now.append(_stretch_now(physical))
	_spread("stretch with the old clamps", was)
	_spread("stretch at one scale of %.2f" % SCALE, now)


## How evenly a rally is slowed. `p95 / p05` is the number that matters: at 1.00
## every event is drawn at the same multiple of its own length and every ratio
## between two events survives.
func _spread(label: String, samples: Array[float]) -> void:
	if samples.is_empty():
		return
	samples.sort()
	var count := samples.size()
	var low: float = samples[int(count * 0.05)]
	var high: float = samples[mini(int(count * 0.95), count - 1)]
	print("%s: p05 %.2fx  p50 %.2fx  p95 %.2fx  -> spread %.2fx" % [
		label, low, samples[count / 2], high, high / maxf(low, 0.001),
	])
	print("rallies whose last stamp precedes the terminal landing: %d of %d (worst %.2fs)"
		% [ends_early, rallies_read, early_worst])


func _report(
	label: String, samples: Array[float], floor_at: float, ceiling_at: float,
	floored: int, ceilinged: int
) -> void:
	if samples.is_empty():
		print("%s: none seen" % label)
		return
	samples.sort()
	var count := samples.size()
	print("%s: n=%d  p05 %.2f  p25 %.2f  p50 %.2f  p75 %.2f  p95 %.2f  max %.2f"
		% [
			label, count,
			samples[int(count * 0.05)], samples[int(count * 0.25)],
			samples[count / 2], samples[int(count * 0.75)],
			samples[mini(int(count * 0.95), count - 1)], samples[count - 1],
		])
	print("   clamp [%.2f, %.2f] rewrites %d below (%.1f%%) and %d above (%.1f%%)"
		% [
			floor_at, ceiling_at,
			floored, 100.0 * float(floored) / float(count),
			ceilinged, 100.0 * float(ceilinged) / float(count),
		])
