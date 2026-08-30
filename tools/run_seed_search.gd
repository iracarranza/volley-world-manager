extends SceneTree

## Deterministic rally search, backed by the same pure RallyQuery used by the
## in-game debug panel.
##
## Examples:
##   --serve-style="Jump Float" --serving=home
##   --terminal-event=BLOCK --outcome=tool
##   --set-achieved-tempo=1 --set-duration=0.18
##   --query="first set achieved tempo is T1; first attack is quick"
##   --where="set[1].duration<0.18;attack[1].metadata.wall_size>=2"
##
## All clauses are AND-combined. When no conjunction matches, every clause's
## individual hit rate is printed so an impossible condition is distinguishable
## from a merely rare one.

const RallyQueryModel := preload("res://scripts/simulation/rally_query.gd")
const DEFAULT_FROM: int = 20000
const DEFAULT_TO: int = 21000
const DEFAULT_COUNT: int = 5


func _initialize() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var clauses := RallyQueryModel.clauses_from_arguments(args)
	clauses.append_array(RallyQueryModel.clauses_from_text(str(args.get("query", ""))))
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var region := str(args.get("region", ""))
	if not region.is_empty() and manager.has_method("set_opponent_region"):
		manager.set_opponent_region(region)

	var from_seed := int(args.get("from", DEFAULT_FROM))
	var to_seed := int(args.get("to", DEFAULT_TO))
	var wanted := maxi(int(args.get("count", DEFAULT_COUNT)), 1)
	var serving := str(args.get("serving", "alternate")).to_lower()
	var passed: Array[int] = []
	passed.resize(clauses.size())
	passed.fill(0)
	var matches: Array[Dictionary] = []
	var searched := 0
	for rally_seed in range(from_seed, to_seed):
		var serving_home := rally_seed % 2 == 0
		if serving == "home": serving_home = true
		elif serving in ["opponent", "away"]: serving_home = false
		manager.match_state.serving_home = serving_home
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null: continue
		searched += 1
		var evaluation := RallyQueryModel.evaluate(result, serving_home, clauses)
		for clause_index in range(evaluation["clauses"].size()):
			if bool(evaluation["clauses"][clause_index]["passed"]):
				passed[clause_index] += 1
		if bool(evaluation["matches"]) and matches.size() < wanted:
			matches.append({
				"seed": rally_seed, "evaluation": evaluation,
				"serving_home": serving_home,
			})

	print("searched %d seeds in [%d, %d)" % [searched, from_seed, to_seed])
	if clauses.is_empty():
		print("no filters given -- nothing to search for")
	else:
		print("\nAND filters, each counted independently")
		for clause_index in range(clauses.size()):
			print("  %-46s %5d  %5.1f%%" % [
				RallyQueryModel.clause_label(clauses[clause_index]),
				passed[clause_index],
				100.0 * float(passed[clause_index]) / maxf(float(searched), 1.0),
			])

	print("\n%d matching seed%s" % [matches.size(), "" if matches.size() == 1 else "s"])
	for entry in matches:
		print("  %s" % RallyQueryModel.result_summary(
			int(entry["seed"]), entry["evaluation"]
		))
		print("    reproduce: %s" % RallyQueryModel.reproduction_command(
			int(entry["seed"]), int(entry["seed"]) + 1,
			"home" if bool(entry["serving_home"]) else "opponent",
			str(args.get("query", _argument_query(args))),
		))
	if matches.is_empty() and not clauses.is_empty():
		print("\nNo combined match. A 0.0%% clause is not produced in this census;")
		print("a non-zero clause is individually possible but may be rare in combination.")
	manager.free()
	quit()


func _argument_query(args: Dictionary) -> String:
	var parts: Array[String] = []
	for clause in RallyQueryModel.clauses_from_arguments(args):
		parts.append(RallyQueryModel.clause_label(clause))
	return "; ".join(parts)


func _parse(raw: PackedStringArray) -> Dictionary:
	var parsed := {}
	for argument in raw:
		if not argument.begins_with("--"): continue
		var body := argument.substr(2)
		var split := body.split("=", true, 1)
		parsed[split[0]] = split[1] if split.size() > 1 else true
	return parsed
