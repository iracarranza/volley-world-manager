class_name TrainingProjection
extends RefCounted

## What a session works on, drawn as the windows a rally actually reads.
##
## The training screen used to answer "what does this session do" with
## `"system familiarity +2.0%, cohesion +0.5% a week"`. That is a number about a
## number. The tactical planner was legible because it drew the consequence on
## the court, and training should borrow that instrument rather than invent a
## percentage.
##
## The consequence a rally can see is a **system-fit band**.
## `VolleyballPlayer.refresh_system_fit_profiles` derives four from career
## attributes -- approach distance, set release interval, block engagement
## distance, defensive depth -- each an ideal and a tolerance either side. The
## simulator reads them directly.
##
## **This does not draw a before-and-after, and the reason is measured.** The
## obvious build is a ghost bar showing the squad after some weeks of training.
## Projected properly -- by running the real training path on a deep copy, which
## is what the first cut did -- twelve weeks of high-focus work moves the widest
## band by 0.038 m against a 3 m span. That is under two per cent, and drawn it
## is two bars in exactly the same place. Training is deliberately slow
## (`WEEKLY_PROGRESS_POINTS` is 1.15 across a whole squad and a season is thirty
## weeks), so the horizon does not exist where that chart says anything.
##
## What *is* visible is the squad itself: the spread between volis on these axes
## runs 10% to 40% of the median. So the instrument compares volis, which is also
## the thing a manager can act on -- you cannot make this week move a band
## noticeably, but you can see which voli's window is wrong for what you want and
## put *them* on the session.

## The bands, with the unit each is measured in and which way is "sharper".
const AXES: Array[Dictionary] = [
	{
		"key": &"set_release_interval", "label": "Set release",
		"unit": "s", "decimals": 2, "lower_is_sharper": true,
		"note": "How quickly the ball leaves the setter's hands. Lower is a faster tempo.",
	},
	{
		"key": &"attack_approach_distance", "label": "Approach run-up",
		"unit": "m", "decimals": 2, "lower_is_sharper": false,
		"note": "How much runway a hitter wants before take-off.",
	},
	{
		"key": &"block_engagement_distance", "label": "Block engagement",
		"unit": "m", "decimals": 2, "lower_is_sharper": true,
		"note": "How late a blocker can keep reading before committing. Lower holds longer.",
	},
	{
		"key": &"defensive_depth", "label": "Defensive depth",
		"unit": "m", "decimals": 2, "lower_is_sharper": true,
		"note": "Where a defender naturally sits. Lower reads shallow.",
	},
]

## How far a probe attribute is pushed when asking which bands a session feeds.
##
## Large deliberately. The question is "is this band derived from any of these
## attributes at all", which is a yes or no, and a small nudge risks answering it
## with rounding.
const PROBE_STEP: int = 25


## Which windows this session's attribute pool feeds, and in which direction.
##
## Answered by measurement rather than by a hand-kept table: push every attribute
## in the pool on a copy of a real voli, refresh the derived bands, and see which
## ones moved. A table would be a second statement of a relationship that already
## exists in `refresh_system_fit_profiles`, and free to fall out of step with it.
static func axes_touched(
	activity: Dictionary, probe: VolleyballPlayer
) -> Array[Dictionary]:
	var touched: Array[Dictionary] = []
	if probe == null:
		return touched
	var pool := Array(activity.get("attributes", []))
	if pool.is_empty():
		return touched

	var bumped := VolleyballPlayer.from_dict(probe.to_dict())
	if bumped == null:
		return touched
	for attribute_name in pool:
		var value: Variant = bumped.get(str(attribute_name))
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			continue
		bumped.set(str(attribute_name), clampi(int(value) + PROBE_STEP, 0, 100))
	bumped.refresh_system_fit_profiles()

	for axis in AXES:
		var before: SystemFitProfile = probe.system_fit(axis.key)
		var after: SystemFitProfile = bumped.system_fit(axis.key)
		if before == null or after == null:
			continue
		var ideal_shift := after.ideal_value - before.ideal_value
		var tolerance_shift := after.tolerance - before.tolerance
		if absf(ideal_shift) < 0.0005 and absf(tolerance_shift) < 0.0005:
			continue
		var row := axis.duplicate()
		row["ideal_shift"] = ideal_shift
		row["tolerance_shift"] = tolerance_shift
		touched.append(row)
	return touched


## One row per voli on this session, for one axis.
##
## All rows share the axis, so the bars are directly comparable -- which is the
## whole point of drawing them together.
static func squad_rows(
	axis: Dictionary, players: Array, regimen: TrainingRegimen
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for player in players:
		if player == null or not int(player.id) in regimen.player_ids:
			continue
		var profile: SystemFitProfile = player.system_fit(axis.key)
		if profile == null:
			continue
		rows.append({
			"name": str(player.display_name),
			"role": str(player.position_role),
			"ideal": float(profile.ideal_value),
			"tolerance": float(profile.tolerance),
		})
	rows.sort_custom(func(a, b): return float(a.ideal) < float(b.ideal))
	return rows


## What this session does to a window, in words.
##
## The magnitude is deliberately absent: a week's movement is far below what the
## bars can show, and quoting a figure the drawing cannot corroborate is how the
## percentage this replaces went wrong in the first place.
static func direction_sentence(axis: Dictionary) -> String:
	var parts: Array[String] = []
	var ideal_shift := float(axis.get("ideal_shift", 0.0))
	var tolerance_shift := float(axis.get("tolerance_shift", 0.0))
	var lower_is_sharper := bool(axis.get("lower_is_sharper", true))
	if absf(ideal_shift) >= 0.0005:
		var sharper := (ideal_shift < 0.0) == lower_is_sharper
		parts.append("moves the window %s" % ("in" if sharper else "out"))
	if absf(tolerance_shift) >= 0.0005:
		parts.append("%s it" % ("widens" if tolerance_shift > 0.0 else "tightens"))
	if parts.is_empty():
		return ""
	return "Work here %s." % " and ".join(parts)
