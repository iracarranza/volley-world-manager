extends SceneTree

## What does a block event actually know about its own objective?
##
##     godot --headless --path . --script res://tools/run_block_verdict_probe.gd
##
## A shield should not shatter because the ball got past it. A **funnel** that
## sends the swing into a waiting digger has done exactly what it set out to do,
## and drawing that as a broken shield says the opposite of what happened. What
## breaks a shield is a block that meant to stop the ball and got beaten.
##
## That distinction needs two facts on the same event -- what the block *intended*
## and what it *did* -- and this measures whether both are there before any rule
## is written against them. `_contest_block` computes `block_intent`, `outcome`
## and `block_hands` together, but computing a thing and publishing it are
## different, and the layer can only read what reaches the event.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()

	var Verdict := load("res://scripts/data/block_verdict.gd")
	var verdicts := {}
	var intents := {}
	var keys := {}
	var pairs := {}
	var blocks := 0
	for rally_seed in range(70000, 70240):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		for event in result.events:
			if int(event.event_type) != Events.EventType.BLOCK:
				continue
			blocks += 1
			for key in [
				"outcome", "block_intent", "block_hands", "block_miss_reason",
				"block_contact_kind", "block_deflection_playable",
			]:
				if event.metadata.has(key):
					keys[key] = int(keys.get(key, 0)) + 1
			var pair := "%s / %s / %s" % [
				str(event.metadata.get("outcome", "(absent)")),
				str(event.metadata.get("block_hands", "(absent)")),
				str(event.metadata.get("block_miss_reason", "")) \
					if str(event.metadata.get("block_miss_reason", "")) != "" \
					else "-",
			]
			pairs[pair] = int(pairs.get(pair, 0)) + 1
			var intent := str(event.metadata.get("block_intent", "Balanced"))
			intents[intent] = int(intents.get(intent, 0)) + 1
			var verdict: String = Verdict.of(
				intent,
				str(event.metadata.get("outcome", "")),
				str(event.metadata.get("block_hands", "neutral")),
				str(event.metadata.get("block_miss_reason", "")),
			)
			verdicts[verdict] = int(verdicts.get(verdict, 0)) + 1

	print("%d block events across 240 rallies\n" % blocks)
	print("%-16s %8s %8s" % ["key", "present", "share"])
	for key in [
		"outcome", "block_intent", "block_hands", "block_miss_reason",
		"block_contact_kind", "block_deflection_playable",
	]:
		print("%-16s %8d %7.1f%%" % [
			key, int(keys.get(key, 0)),
			float(keys.get(key, 0)) / maxf(float(blocks), 1.0) * 100.0,
		])

	print("\n%-34s %8s %8s" % ["outcome / hands / miss reason", "count", "share"])
	var rows := pairs.keys()
	rows.sort_custom(func(a, b): return int(pairs[a]) > int(pairs[b]))
	for row in rows:
		print("%-34s %8d %7.1f%%" % [
			row, int(pairs[row]),
			float(pairs[row]) / maxf(float(blocks), 1.0) * 100.0,
		])
	print("")
	_table("verdict", verdicts, blocks)
	print("")
	_table("plan intent", intents, blocks)
	print("\nA shield breaks on %.1f%% of blocks: a wall that went up to stop"
		% (float(verdicts.get("broken", 0)) / maxf(float(blocks), 1.0) * 100.0))
	print("the ball and was beaten around the edge. Beaten over the top stays")
	print("plain, because being out-jumped is not being out-read.")
	manager.free()
	quit()


func _table(label: String, table: Dictionary, total: int) -> void:
	var keys := table.keys()
	keys.sort_custom(func(a, b): return int(table[a]) > int(table[b]))
	print("%-16s %8s %8s" % [label, "count", "share"])
	for key in keys:
		print("%-16s %8d %7.1f%%" % [
			key, int(table[key]),
			float(table[key]) / maxf(float(total), 1.0) * 100.0,
		])
