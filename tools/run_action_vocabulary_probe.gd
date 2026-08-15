extends SceneTree

## Does the vocabulary hit the draft's own targets?
##
##     godot --headless --path . --script res://tools/run_action_vocabulary_probe.gd
##
## `docs/design/ACTION_VOCABULARY_DRAFT.md` states three, and they use different
## denominators on purpose -- names should be **rare per contact and dominant
## per point**:
##
##   - share of rallies with at least one named action: 40-60%
##   - named actions per rally, mean: about 1
##   - share of points whose decisive event carries a name: high
##
## Printed rather than asserted, because the first two are a budget the classifier
## has to be tuned into and the third depends on the block rate the draft itself
## says is not calibrated yet.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")

const RALLIES: int = 400
const FIRST_SEED: int = 52000


func _initialize() -> void:
	var rallies := 0
	var rallies_with_a_name := 0
	var names := 0
	var decisive_named := 0
	var by_name := {}
	var offered := 0
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			rallies += 1
			var named_here := 0
			## The draft's third target is "the share of *points* whose decisive
			## event carries a name". The decisive **event** is the rally's last
			## real contact; `decisive_actor_id` is who the point was *credited*
			## to, and on a stuffed swing those are different players on opposite
			## sides of the net. Measuring the actor answered a question the draft
			## did not ask, and read 34.5% while the budget was in fact naming the
			## final contact almost every time.
			var final_index := -1
			for index in range(result.events.size() - 1, -1, -1):
				var candidate: Resource = result.events[index]
				if int(candidate.event_type) != 7 and int(candidate.event_type) != 2:
					final_index = index
					break
			var decisive_has_name := final_index >= 0 and bool(
				(result.events[final_index] as Resource).metadata.get(
					"named_action", false
				)
			)
			for raw_event in result.events:
				var event: Resource = raw_event
				var outcome := str(event.metadata.get("action_outcome", ""))
				if float(event.metadata.get("action_notability", 0.0)) >= 0.70 \
						and not outcome.is_empty():
					offered += 1
				if not bool(event.metadata.get("named_action", false)):
					continue
				named_here += 1
				by_name[outcome] = int(by_name.get(outcome, 0)) + 1
				pass
			names += named_here
			if named_here > 0:
				rallies_with_a_name += 1
			if decisive_has_name:
				decisive_named += 1
		manager.free()

	print("=== the vocabulary against its own targets ===")
	print("")
	print("%-46s %8.1f%%   target 40-60%%" % [
		"rallies with at least one named action",
		float(rallies_with_a_name) / maxf(float(rallies), 1.0) * 100.0,
	])
	print("%-46s %9.2f   target ~1" % [
		"named actions per rally", float(names) / maxf(float(rallies), 1.0),
	])
	print("%-46s %8.1f%%   target high" % [
		"points whose decisive contact is named",
		float(decisive_named) / maxf(float(rallies), 1.0) * 100.0,
	])
	print("")
	print("%-46s %9d" % ["names offered before the budget", offered])
	print("%-46s %9d" % ["names kept", names])
	print("")
	var ordered: Array = by_name.keys()
	ordered.sort_custom(func(a, b): return int(by_name[a]) > int(by_name[b]))
	for name in ordered:
		print("  %-40s %6d  %5.1f%%" % [
			name, int(by_name[name]),
			float(by_name[name]) / maxf(float(names), 1.0) * 100.0,
		])
	print("")
	print("%d rallies over both serving sides." % rallies)
	quit()
