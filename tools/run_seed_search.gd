extends SceneTree

## Find a rally that does the thing you want to look at.
##
##     godot --headless --path . --script res://tools/run_seed_search.gd -- \
##         --outcome=tool --serving=opponent --count=5
##
## Every probe written this session has been this loop with different
## bookkeeping: resolve seeds, test a predicate, stop at a match. Rallies are
## deterministic from a seed -- the whole suite leans on it -- so "find me a
## seed that ends in a tool" is a search and not a feature. Written once here so
## the next question is a flag rather than a new file, and so the match screen's
## debug menu has an engine to wrap rather than a thing to reimplement.
##
## **An empty result is a measurement, not a dead end.** This session's most
## useful findings were all cases that turned out not to exist: `reaching` on 0%
## of receptions, an open net on 1 swing in 710, a bystander blocker population
## that was not there. So the report always states how many seeds were searched
## and what share of them each individual filter passed -- a search that finds
## nothing tells you *which* clause emptied it.
##
## Filters, all optional and combined with AND:
##
##   --outcome=kill|ace|tool|stuff|net|out|...   the rally's terminal outcome
##   --signature                                  a signature move was attempted
##   --signature-hit                              ...and it succeeded
##   --block=stuff|tool|touch                     a block contact of that kind
##   --attack-missed                              some swing went out
##   --wall=N                                     a swing faced a wall of N
##   --min-contacts=N / --max-contacts=N          rally length
##   --serving=home|opponent                      who served (default alternates)
##   --region=<name>                              which region the opponent is
##   --from=N --to=N                              the seed range to search
##   --count=N                                    how many matches to report

const DEFAULT_FROM: int = 20000
const DEFAULT_TO: int = 21000
const DEFAULT_COUNT: int = 5


func _initialize() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var region := str(args.get("region", ""))
	if not region.is_empty() and manager.has_method("set_opponent_region"):
		manager.set_opponent_region(region)

	var from_seed := int(args.get("from", DEFAULT_FROM))
	var to_seed := int(args.get("to", DEFAULT_TO))
	var wanted := int(args.get("count", DEFAULT_COUNT))
	var serving := str(args.get("serving", ""))

	## Every clause is counted on its own as well as in the conjunction, so an
	## empty result says which one did it.
	var passed := {}
	var matches: Array[Dictionary] = []
	var searched := 0
	for rally_seed in range(from_seed, to_seed):
		if serving == "home":
			manager.match_state.serving_home = true
		elif serving == "opponent":
			manager.match_state.serving_home = false
		else:
			manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		searched += 1
		var facts := _facts(result, Events)
		var all_pass := true
		for clause in _clauses(args):
			var name: String = clause["name"]
			var ok: bool = clause["test"].call(facts)
			if ok:
				passed[name] = int(passed.get(name, 0)) + 1
			else:
				all_pass = false
		if all_pass and not _clauses(args).is_empty():
			matches.append({"seed": rally_seed, "facts": facts})
			if matches.size() >= wanted:
				break

	print("searched %d seeds in [%d, %d)" % [searched, from_seed, to_seed])
	var clause_names: Array = []
	for clause in _clauses(args):
		clause_names.append(str(clause["name"]))
	if clause_names.is_empty():
		print("no filters given -- nothing to search for")
	else:
		print("\nfilters, each counted on its own")
		for name in clause_names:
			var hits := int(passed.get(name, 0))
			print("  %-22s %5d  %5.1f%% of seeds" % [
				name, hits, 100.0 * float(hits) / maxf(float(searched), 1.0),
			])

	print("\n%d matching seed%s" % [
		matches.size(), "" if matches.size() == 1 else "s"])
	for entry in matches:
		var facts: Dictionary = entry["facts"]
		print("  seed %d  %-10s  %d contacts  block:%-6s  signature:%s" % [
			int(entry["seed"]), str(facts["outcome"]), int(facts["contacts"]),
			str(facts["block_kind"]) if not str(facts["block_kind"]).is_empty() \
				else "-",
			str(facts["signature"]) if not str(facts["signature"]).is_empty() \
				else "-",
		])
	if matches.is_empty() and not clause_names.is_empty():
		## The finding, stated as one. A clause at 0.0% is a case the engine does
		## not produce, which is worth more than a seed would have been.
		print("\nNo rally matched. Any clause above at 0.0%% is not a rare case,")
		print("it is a case this engine does not currently produce.")
	manager.free()
	quit()


## Everything a filter might ask about, read once per rally.
func _facts(result: Resource, Events: Object) -> Dictionary:
	var contacts := 0
	var block_kind := ""
	var signature := ""
	var signature_hit := false
	var attack_missed := false
	var walls := {}
	for event in result.events:
		var type := int(event.event_type)
		if type == Events.EventType.SET_DECISION:
			continue
		contacts += 1
		var kind := str(event.metadata.get("block_contact_kind", ""))
		if not kind.is_empty():
			block_kind = kind
		var move := str(event.metadata.get("signature_move", ""))
		if not move.is_empty():
			signature = move
			signature_hit = signature_hit \
				or bool(event.metadata.get("signature_succeeded", false))
		if bool(event.metadata.get("attack_missed", false)):
			attack_missed = true
		if event.metadata.has("wall_size"):
			walls[int(event.metadata["wall_size"])] = true
	return {
		"outcome": str(result.terminal_outcome),
		"contacts": contacts,
		"block_kind": block_kind,
		"signature": signature,
		"signature_hit": signature_hit,
		"attack_missed": attack_missed,
		"walls": walls,
	}


func _clauses(args: Dictionary) -> Array:
	var built: Array = []
	if args.has("outcome"):
		var wanted := str(args["outcome"])
		built.append({"name": "outcome=%s" % wanted,
			"test": func(f: Dictionary) -> bool: return str(f["outcome"]) == wanted})
	if args.has("signature"):
		built.append({"name": "signature attempted",
			"test": func(f: Dictionary) -> bool: return not str(f["signature"]).is_empty()})
	if args.has("signature-hit"):
		built.append({"name": "signature succeeded",
			"test": func(f: Dictionary) -> bool: return bool(f["signature_hit"])})
	if args.has("block"):
		var kind := str(args["block"])
		built.append({"name": "block=%s" % kind,
			"test": func(f: Dictionary) -> bool: return str(f["block_kind"]) == kind})
	if args.has("attack-missed"):
		built.append({"name": "a swing went out",
			"test": func(f: Dictionary) -> bool: return bool(f["attack_missed"])})
	if args.has("wall"):
		var size := int(args["wall"])
		built.append({"name": "wall of %d" % size,
			"test": func(f: Dictionary) -> bool: return Dictionary(f["walls"]).has(size)})
	if args.has("min-contacts"):
		var least := int(args["min-contacts"])
		built.append({"name": ">= %d contacts" % least,
			"test": func(f: Dictionary) -> bool: return int(f["contacts"]) >= least})
	if args.has("max-contacts"):
		var most := int(args["max-contacts"])
		built.append({"name": "<= %d contacts" % most,
			"test": func(f: Dictionary) -> bool: return int(f["contacts"]) <= most})
	return built


## `--flag` and `--key=value`, which is all this needs.
func _parse(raw: PackedStringArray) -> Dictionary:
	var parsed := {}
	for argument in raw:
		if not argument.begins_with("--"):
			continue
		var body := argument.substr(2)
		var split := body.split("=", true, 1)
		parsed[split[0]] = split[1] if split.size() > 1 else true
	return parsed
