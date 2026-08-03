extends SceneTree

## Attack-error diagnostic across many careers.
##
## `fixture_base_seed()` hashes the career name, so a single career is one
## sample rather than a result -- every earlier attempt to read this number
## from one save reached a different and equally confident wrong answer. This
## walks ten careers of three fixtures each and reports correlations plus
## quartile groupings.
##
## Whole-roster mean CA is deliberately *not* the headline variable: it averages
## in players who never swing, and it measured at Spearman -0.05 against the
## error rate -- no relationship at all. The CA of the players actually taking
## the attacks measured -0.68. A diagnostic built on roster average would have
## reported "capability is not the driver" and sent the investigation somewhere
## else entirely.
##
## Run with:
##   godot --headless --path . --script res://tools/run_attack_diagnostic.gd

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var career_manager := get_root().get_node("/root/CareerManager")
	var game_manager := get_root().get_node("/root/GameManager")

	var rows: Array[Dictionary] = []
	for career_index in range(10):
		var career_name := "__Diag %d__" % career_index
		if not career_manager.create_career(
				career_name, "Probe FC", "Landavol", "Club", "Balanced").is_empty():
			continue
		for fixture_id in [1, 2, 3]:
			while int(career_manager.career.absolute_week) < fixture_id * 2:
				career_manager.advance_week()
			if not career_manager.prepare_fixture(fixture_id).is_empty():
				continue
			rows.append(_play(career_manager, game_manager, fixture_id))
			career_manager.complete_active_match()

	print("n = %d matches\n" % rows.size())
	for key in ["lineup_ca", "hitter_ca", "roster_ca", "differential",
			"mean_fatigue", "mean_quality"]:
		print("%-14s  pearson %+.3f   spearman %+.3f" % [
			key, _pearson(rows, key, "error_rate"), _spearman(rows, key, "error_rate")])

	print("\n--- grouped by starting-lineup CA quartile ---")
	_grouped(rows, "lineup_ca")
	print("\n--- grouped by hitter CA quartile ---")
	_grouped(rows, "hitter_ca")

	var sorted_rows := rows.duplicate()
	sorted_rows.sort_custom(func(a, b): return float(a.error_rate) < float(b.error_rate))
	print("\n--- the extremes ---")
	for row in [sorted_rows[0], sorted_rows[-1]]:
		print("  err %.3f | lineup_ca %.1f | hitter_ca %.1f | diff %+.1f | fatigue %.2f | q %.3f" % [
			row.error_rate, row.lineup_ca, row.hitter_ca, row.differential,
			row.mean_fatigue, row.mean_quality])
	return true


func _play(career_manager: Node, game_manager: Node, fixture_id: int) -> Dictionary:
	var base_seed: int = career_manager.fixture_base_seed(fixture_id)
	var lineup_ca := _lineup_ca(game_manager)
	var roster_ca := _roster_ca(game_manager)
	var opponent_ca := _opponent_ca(game_manager)
	var rallies := 0
	var attacks := 0
	var errors := 0
	var quality_total := 0.0
	var quality_count := 0
	var fatigue_total := 0.0
	var hitter_ca_total := 0.0
	var hitter_ca_count := 0
	while not bool(game_manager.match_state.match_complete) and rallies < 1000:
		var result: Resource = game_manager.resolve_active_rally(base_seed + rallies)
		game_manager.record_rally(result)
		rallies += 1
		for event_resource in result.events:
			var event := event_resource as RallyEvent
			if event == null or event.event_type != RallyEvent.EventType.ATTACK \
					or str(event.metadata.get("side", "")) != "home":
				continue
			attacks += 1
			if bool(event.metadata.get("attack_missed", false)):
				errors += 1
			var hitter: VolleyballPlayer = game_manager.player_by_id(event.actor_id)
			if hitter != null:
				hitter_ca_total += float(hitter.current_ability_score())
				hitter_ca_count += 1
			quality_total += float(event.quality)
			quality_count += 1
		fatigue_total += _lineup_fatigue(game_manager)
	return {
		"error_rate": float(errors) / maxf(float(attacks), 1.0),
		"lineup_ca": lineup_ca,
		"roster_ca": roster_ca,
		"hitter_ca": hitter_ca_total / maxf(float(hitter_ca_count), 1.0),
		"differential": lineup_ca - opponent_ca,
		"mean_fatigue": fatigue_total / maxf(float(rallies), 1.0),
		"mean_quality": quality_total / maxf(float(quality_count), 1.0),
	}


func _lineup_ca(game_manager: Node) -> float:
	var total := 0.0
	var count := 0
	for player_id in game_manager.team.starting_player_ids:
		var player: VolleyballPlayer = game_manager.player_by_id(int(player_id))
		if player != null:
			total += float(player.current_ability_score())
			count += 1
	return total / maxf(float(count), 1.0)


func _roster_ca(game_manager: Node) -> float:
	var total := 0.0
	for player in game_manager.players:
		total += float(player.current_ability_score())
	return total / maxf(float(game_manager.players.size()), 1.0)


func _opponent_ca(game_manager: Node) -> float:
	if game_manager.opponent_team == null:
		return 50.0
	var total := 0.0
	var count := 0
	for player_resource in game_manager.opponent_team.on_court_players():
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player != null:
			total += float(player.current_ability_score())
			count += 1
	return total / maxf(float(count), 1.0)


func _lineup_fatigue(game_manager: Node) -> float:
	var total := 0.0
	var count := 0
	for player_id in game_manager.team.starting_player_ids:
		var player: VolleyballPlayer = game_manager.player_by_id(int(player_id))
		if player != null:
			total += float(player.fatigue)
			count += 1
	return total / maxf(float(count), 1.0)


func _pearson(rows: Array[Dictionary], key_a: String, key_b: String) -> float:
	var n := float(rows.size())
	var sum_a := 0.0
	var sum_b := 0.0
	for row in rows:
		sum_a += float(row[key_a])
		sum_b += float(row[key_b])
	var mean_a := sum_a / n
	var mean_b := sum_b / n
	var cov := 0.0
	var var_a := 0.0
	var var_b := 0.0
	for row in rows:
		var da := float(row[key_a]) - mean_a
		var db := float(row[key_b]) - mean_b
		cov += da * db
		var_a += da * da
		var_b += db * db
	return cov / maxf(sqrt(var_a * var_b), 0.000001)


func _spearman(rows: Array[Dictionary], key_a: String, key_b: String) -> float:
	var ranked: Array[Dictionary] = []
	for index in range(rows.size()):
		ranked.append({"a": float(rows[index][key_a]), "b": float(rows[index][key_b])})
	var rank_a := _ranks(ranked, "a")
	var rank_b := _ranks(ranked, "b")
	var as_rows: Array[Dictionary] = []
	for index in range(ranked.size()):
		as_rows.append({"x": rank_a[index], "y": rank_b[index]})
	return _pearson(as_rows, "x", "y")


func _ranks(rows: Array[Dictionary], key: String) -> Array[float]:
	var order: Array[int] = []
	for index in range(rows.size()):
		order.append(index)
	order.sort_custom(func(i, j): return float(rows[i][key]) < float(rows[j][key]))
	var result: Array[float] = []
	result.resize(rows.size())
	for position in range(order.size()):
		result[order[position]] = float(position)
	return result


func _grouped(rows: Array[Dictionary], key: String) -> void:
	var sorted_rows := rows.duplicate()
	sorted_rows.sort_custom(func(a, b): return float(a[key]) < float(b[key]))
	var per := maxi(sorted_rows.size() / 4, 1)
	for quartile in range(4):
		var start := quartile * per
		var stop := mini(start + per, sorted_rows.size())
		if start >= stop:
			continue
		var err := 0.0
		var val := 0.0
		for index in range(start, stop):
			err += float(sorted_rows[index].error_rate)
			val += float(sorted_rows[index][key])
		var span := float(stop - start)
		print("  Q%d  %s %.1f  ->  error rate %.3f  (n=%d)" % [
			quartile + 1, key, val / span, err / span, int(span)])
