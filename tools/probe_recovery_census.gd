extends SceneTree

## How often does a voli actually end up on the floor?
##
## **Before asking why a getting-up looks wrong, ask whether it happens.** A pose
## drawn perfectly and selected once in four hundred rallies is
## indistinguishable, from a viewer's chair, from one that is never drawn at all
## -- and the two have completely different repairs. Written when the floor
## recoveries were reported as never seen: 97.2 per cent of contacts came back
## `platform`, fourteen bodies went down in four hundred rallies, and
## `blown_away` did not occur once.
##
## It also reports the distribution behind the gate `blown_away` sits on, because
## the obvious explanation for an empty band here is a threshold outside its own
## distribution and that guess was wrong: 12 per cent of contacts clear the force
## gate and the maximum is 1.000. The band is empty because it is a conjunction
## of two uncommon conditions, not because either is unreachable. Measuring the
## input was the only thing that could tell those apart.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const EVENT := preload("res://scripts/models/rally_event.gd")
const RALLIES := 400


func _initialize() -> void:
	var by_state := {}
	var by_state_kind := {}
	var contacts := 0
	var rallies := 0
	var forces: Array = []
	var shortfalls: Array = []
	for index in range(RALLIES):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = index % 2 == 0
		var result: Resource = manager.resolve_active_rally(500000 + index)
		if result == null:
			continue
		rallies += 1
		for raw in result.events:
			var event: Resource = raw
			if event == null:
				continue
			var state := str(event.metadata.get("contact_recovery", ""))
			if state.is_empty():
				continue
			contacts += 1
			by_state[state] = int(by_state.get(state, 0)) + 1
			if event.metadata.has("incoming_force"):
				forces.append(float(event.metadata["incoming_force"]))
			var kind := str(EVENT.EventType.keys()[int(event.event_type)])
			var key := "%s|%s" % [kind, state]
			by_state_kind[key] = int(by_state_kind.get(key, 0)) + 1
	print("\n%d rallies, %d contacts publishing a recovery state" % [
		rallies, contacts,
	])
	print("\n%-14s %8s %9s %14s" % ["state", "count", "share", "per rally"])
	for state in ["platform", "knee", "fall", "blown_away"]:
		var count := int(by_state.get(state, 0))
		print("%-14s %8d %8.2f%% %14.3f" % [
			state, count,
			100.0 * float(count) / float(maxi(contacts, 1)),
			float(count) / float(maxi(rallies, 1)),
		])
	var other := 0
	for state in by_state:
		if not (state in ["platform", "knee", "fall", "blown_away"]):
			other += int(by_state[state])
	if other > 0:
		print("%-14s %8d" % ["(other)", other])
	## **The gate the empty band is behind.** `blown_away` needs incoming_force
	## past RECOVERY_HEAVY_FORCE +/- the anchor swing, which the constants put at
	## 0.74 to 0.98. If the force a ball actually arrives with never gets there,
	## the band is unreachable however the shortfall behaves -- which is the
	## failure this repository keeps finding: a threshold outside the
	## distribution it acts on does nothing, and does nothing silently.
	forces.sort()
	if not forces.is_empty():
		print("\n-- incoming_force, the gate blown_away is behind --")
		print("  n=%d  min %.3f  p50 %.3f  p95 %.3f  p99 %.3f  max %.3f" % [
			forces.size(), forces[0],
			forces[int(forces.size() * 0.50)],
			forces[int(forces.size() * 0.95)],
			forces[int(forces.size() * 0.99)],
			forces[forces.size() - 1],
		])
		var over := 0
		for f in forces:
			if float(f) >= 0.74:
				over += 1
		print("  at or past 0.74, the easiest the gate ever gets: %d of %d (%.2f%%)" % [
			over, forces.size(), 100.0 * float(over) / float(forces.size()),
		])
	print("\n-- which contacts put a body down --")
	var keys: Array = by_state_kind.keys()
	keys.sort()
	for key in keys:
		if key.ends_with("|platform"):
			continue
		print("  %-28s %6d" % [key, int(by_state_kind[key])])
	quit(0)
