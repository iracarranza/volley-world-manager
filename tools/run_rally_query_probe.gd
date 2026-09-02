extends SceneTree

const RallyQueryModel := preload("res://scripts/simulation/rally_query.gd")

const FROM_SEED: int = 24000
const RALLIES: int = 1200


func _initialize() -> void:
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var searches: Array[Dictionary] = [
		{"name": "standing front set", "query": "set[1].posture=standing;set[1].side=front", "required": true},
		{"name": "jump back set", "query": "set[1].posture=jump;set[1].side=back", "required": true},
		{"name": "underhand second contact", "query": "set[1].posture=underhand", "required": true},
		{"name": "Jump Topspin reception", "query": "serve.style=Jump Topspin;reception[1].success=true", "required": false},
		{"name": "Jump Float reception", "query": "serve.style=Jump Float;reception[1].success=true", "required": true},
		{"name": "terminal block tool", "query": "terminal.event=BLOCK;terminal.outcome=tool", "required": false},
		{"name": "quick sequence", "query": "sequence contains SERVE > RECEPTION > SET > ATTACK;attack[1].quick=true", "required": true},
	]
	for search in searches:
		search["clauses"] = RallyQueryModel.clauses_from_text(str(search.query))
		search["hits"] = 0
		search["first"] = {}
		var clause_hits: Array[int] = []
		clause_hits.resize(Array(search.clauses).size())
		clause_hits.fill(0)
		search["clause_hits"] = clause_hits
	for seed_value in range(FROM_SEED, FROM_SEED + RALLIES):
		var serving_home := seed_value % 2 == 0
		manager.match_state.serving_home = serving_home
		var result: Resource = manager.resolve_active_rally(seed_value)
		for search in searches:
			var evaluation := RallyQueryModel.evaluate(result, serving_home, search.clauses)
			var clause_hits: Array[int] = search.clause_hits
			for index in range(evaluation.clauses.size()):
				if bool(evaluation.clauses[index].passed): clause_hits[index] += 1
			search["clause_hits"] = clause_hits
			if bool(evaluation.matches):
				search.hits = int(search.hits) + 1
				if Dictionary(search.first).is_empty():
					search.first = {
						"seed": seed_value, "serving_home": serving_home,
						"summary": RallyQueryModel.result_summary(seed_value, evaluation),
					}

	var failures := 0
	print("rally query -- %d deterministic rallies" % RALLIES)
	var guided_fields := RallyQueryModel.guided_fields()
	if guided_fields.size() < 20:
		print("  FAIL guided field catalog is incomplete (%d fields)" % guided_fields.size())
		failures += 1
	else:
		print("  guided builder exposes %d prompted fields" % guided_fields.size())
	for preset_index in range(RallyQueryModel.guided_presets().size()):
		var preset: Dictionary = RallyQueryModel.guided_presets()[preset_index]
		if preset_index == 0:
			continue
		var preset_clauses := RallyQueryModel.clauses_from_text(str(preset.query))
		var round_trip := RallyQueryModel.clauses_from_text(
			RallyQueryModel.clauses_to_text(preset_clauses)
		)
		if preset_clauses.is_empty() or not _same_clauses(preset_clauses, round_trip):
			print("  FAIL guided preset round trip: %s" % preset.label)
			failures += 1
	print("  guided presets parse and round-trip through shared predicates")
	for search in searches:
		var first: Dictionary = search.first
		print("\n  %s: %d hits (%.2f%%)" % [
			search.name, search.hits, 100.0 * float(search.hits) / RALLIES,
		])
		for index in range(Array(search.clauses).size()):
			print("    clause %-44s %5.1f%%" % [
				RallyQueryModel.clause_label(search.clauses[index]),
				100.0 * float(search.clause_hits[index]) / RALLIES,
			])
		if first.is_empty():
			print("    no combined fixture in census")
			if bool(search.required): failures += 1
			continue
		print("    fixture %s" % first.summary)
		manager.match_state.serving_home = bool(first.serving_home)
		var repeated: Resource = manager.resolve_active_rally(int(first.seed))
		var repeated_evaluation := RallyQueryModel.evaluate(
			repeated, bool(first.serving_home), search.clauses
		)
		var repeated_summary := RallyQueryModel.result_summary(
			int(first.seed), repeated_evaluation
		)
		if not bool(repeated_evaluation.matches) or repeated_summary != str(first.summary):
			print("    FAIL deterministic repeat: %s" % repeated_summary)
			failures += 1
		else:
			print("    deterministic repeat matched")

	## The vertical-slice roster has no topspin server. Exercise that query only
	## under a named, explicit repertoire fixture; the natural 0% above remains
	## visible and the predicate itself never manufactures a serve style.
	for player in manager.players: player.primary_serve_style = "Jump Topspin"
	for player in manager.opponent_team.players: player.primary_serve_style = "Jump Topspin"
	manager.match_state.serving_home = true
	var controlled_result: Resource = manager.resolve_active_rally(24000)
	var topspin_clauses := RallyQueryModel.clauses_from_text(
		"serve.style=Jump Topspin;reception[1].success=true"
	)
	var controlled := RallyQueryModel.evaluate(controlled_result, true, topspin_clauses)
	print("\n  explicit Jump Topspin repertoire fixture:")
	print("    %s" % RallyQueryModel.result_summary(24000, controlled))
	if not bool(controlled.matches): failures += 1

	print("\n%s: shared RallyQuery deterministic fixtures" % (
		"PASS" if failures == 0 else "FAIL (%d missing/unstable)" % failures
	))
	manager.free()
	quit(0 if failures == 0 else 1)


func _same_clauses(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if RallyQueryModel.clause_label(left[index]) \
				!= RallyQueryModel.clause_label(right[index]):
			return false
	return true
