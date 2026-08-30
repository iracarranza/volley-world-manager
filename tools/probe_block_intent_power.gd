extends SceneTree

## Can the block-intent test resolve the claim it makes?
##
## `_test_block_intent_effects` asserts that a sealing block deflects more than
## a funnelling one, and reads that off `touch`/`funnel` outcomes over 150 seeds
## a side. Those are rare -- about 25 of 160-odd home blocks -- so the assertion
## is a comparison of two small counts, and it inverted to 25 against 26 when the
## attack leg began publishing the covering side.
##
## A one-count inversion does not refute a mechanism; it may only mean the
## population cannot resolve it. This runs the identical count over a widening
## series of seed budgets and prints the margin at each, so the question "is the
## direction stable, or is 150 seeds under-powered" is answered by measurement
## rather than by whichever side of zero this particular run landed on.
##
## Deliberately *not* a fix. If the direction holds at larger n the test wants
## more seeds; if it does not, the change reversed a real mechanism and the
## repair is in the simulator. Loosening the comparison is neither.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const EVENT := preload("res://scripts/models/rally_event.gd")

const BUDGETS: Array[int] = [150, 300, 600]


func _initialize() -> void:
	print("%-8s %10s %10s %9s   %10s %10s" % [
		"seeds", "seal defl", "funnel", "margin", "seal stuff", "funnel",
	])
	for budget in BUDGETS:
		var counts := {}
		for intent in ["Seal", "Funnel"]:
			counts[intent] = _count(intent, budget)
		var seal: Dictionary = counts["Seal"]
		var funnel: Dictionary = counts["Funnel"]
		print("%-8d %10d %10d %+9d   %10d %10d" % [
			budget, int(seal.partial), int(funnel.partial),
			int(seal.partial) - int(funnel.partial),
			int(seal.stuff), int(funnel.stuff),
		])


func _count(intent: String, budget: int) -> Dictionary:
	var stuffs := 0
	var partials := 0
	var blocks := 0
	for roster_seed in [11, 12]:
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		for rotation_number in manager.defensive_plans:
			var plan: Resource = manager.defensive_plans[rotation_number]
			if plan != null:
				plan.block_intent = intent
		for serving_home in [true, false]:
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + budget):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				for raw_event in result.events:
					var event: Resource = raw_event
					if event == null \
							or int(event.event_type) \
								!= EVENT.EventType.BLOCK \
							or str(event.metadata.get("side", "")) != "home":
						continue
					blocks += 1
					match str(event.metadata.get("outcome", "miss")):
						"stuff": stuffs += 1
						"touch", "funnel": partials += 1
		manager.free()
		break
	return {"stuff": stuffs, "partial": partials, "blocks": blocks}
