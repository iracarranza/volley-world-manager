class_name ScriptedRallyDriver
extends RallySimulator

## Intent-only boundary for deterministic rally fixtures.
##
## Like `VignetteRallySimulator`, this subclass may constrain decisions but does
## not own movement, contacts, trajectories, or legality. Those remain in the
## production simulator. The only stochastic term suppressed here is the
## production execution-error source; geometric/capability terms still run.

const ACTIONS: Array[StringName] = [
	&"serve", &"receive", &"set", &"attack", &"block", &"dig", &"cover",
]
const COURT_MIN := Vector2.ZERO
const COURT_MAX := Vector2.ONE


## Validate author intent without mutating it. An empty string means that the
## schema is sound; physical resolvers may still refuse an impossible play.
## Keeping one reason (the earliest in timeline order) makes fixture failures
## stable and directly assertable.
static func validate(script: Dictionary) -> String:
	var positions: Dictionary = script.get("initial_positions", {})
	if positions.size() != 12:
		return "initial_positions must contain exactly 12 volis"
	var player_ids: Dictionary = {}
	for raw_id: Variant in positions:
		if not (raw_id is int) or int(raw_id) < 0:
			return "initial_positions contains an invalid voli id"
		if player_ids.has(int(raw_id)):
			return "initial_positions contains a duplicate voli id"
		player_ids[int(raw_id)] = true
		var position: Variant = positions[raw_id]
		if not (position is Vector2) or not _on_court(position):
			return "initial position for voli %s is outside normalized court" % raw_id

	var actions: Variant = script.get("actions", [])
	if not (actions is Array) or actions.is_empty():
		return "actions must contain at least one authored contact"
	var previous_time := -INF
	for index in range(actions.size()):
		var action: Variant = actions[index]
		if not (action is Dictionary):
			return "action %d must be a dictionary" % index
		var kind := StringName(action.get("action", &""))
		if kind not in ACTIONS:
			return "action %d has unsupported action '%s'" % [index, kind]
		var actor: Variant = action.get("actor", null)
		if not (actor is int) or not player_ids.has(int(actor)):
			return "action %d names an unknown actor" % index
		var time: Variant = action.get("time", null)
		if not (time is float or time is int) or not is_finite(float(time)):
			return "action %d has an invalid time" % index
		if float(time) <= previous_time:
			return "action %d must occur after the previous contact" % index
		previous_time = float(time)
		if not action.has("contact_height_m") \
				or not (action.contact_height_m is float or action.contact_height_m is int) \
				or float(action.contact_height_m) < 0.0:
			return "action %d must declare a non-negative contact_height_m" % index
		var target: Variant = action.get("target", null)
		if target is int:
			if not player_ids.has(int(target)):
				return "action %d names an unknown target voli" % index
		elif target is Vector2:
			if not _on_court(target):
				return "action %d target is outside normalized court" % index
		else:
			return "action %d target must be a voli id or normalized court coordinate" % index
		if action.has("quality_override"):
			var override: Variant = action.quality_override
			if not (override is float or override is int) \
					or float(override) < 0.0 or float(override) > 1.0:
				return "action %d quality_override must be between 0 and 1" % index

	return _validate_paths(script.get("movement", []), player_ids)


static func _validate_paths(raw_paths: Variant, player_ids: Dictionary) -> String:
	if not (raw_paths is Array):
		return "movement must be an array"
	for index in range(raw_paths.size()):
		var path: Variant = raw_paths[index]
		if not (path is Dictionary):
			return "movement %d must be a dictionary" % index
		if not (path.get("actor", null) is int) \
				or not player_ids.has(int(path.get("actor", -1))):
			return "movement %d names an unknown actor" % index
		var start: Variant = path.get("start_time", null)
		var finish: Variant = path.get("end_time", null)
		if not (start is float or start is int) or not (finish is float or finish is int) \
				or not is_finite(float(start)) or not is_finite(float(finish)) \
				or float(finish) <= float(start):
			return "movement %d must have a finite positive interval" % index
		var waypoint: Variant = path.get("target", null)
		if not (waypoint is Vector2) or not _on_court(waypoint):
			return "movement %d target is outside normalized court" % index
	return ""


static func _on_court(point: Vector2) -> bool:
	return point.x >= COURT_MIN.x and point.x <= COURT_MAX.x \
		and point.y >= COURT_MIN.y and point.y <= COURT_MAX.y \
		and is_finite(point.x) and is_finite(point.y)


## Deterministic fixtures remove variance at its single production source. This
## deliberately does not override `_set_terms()` (or any other quality model).
func _execution_error(
	_player: VolleyballPlayer,
	_control_attribute: String,
	_base_spread: float,
) -> float:
	return 0.0


## Apply the opt-in probe override only after production has computed quality.
## Callers must pass the individual action; absence preserves the live result.
static func authored_quality(action: Dictionary, production_quality: float) -> float:
	if action.has("quality_override"):
		return float(action.quality_override)
	return production_quality
