extends SceneTree

## Paired Phase Two claimant census; same seeds, only the development gate differs.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const FIRST_SEED: int = 20000
const RALLIES_PER_SIDE: int = 350


func _initialize() -> void:
	var closed := _arm(false)
	var open := _arm(true)
	var changed := 0
	for key in closed.signatures:
		if closed.signatures[key] != open.signatures.get(key, "missing"):
			changed += 1
	print("=== off-ball position claimant rollout ===")
	print("  paired rallies            %d" % int(closed.rallies))
	print("  changed rally signatures  %d" % changed)
	_print_arm("closed", closed)
	_print_arm("open", open)
	print("  delta contacts/rally      %+.3f" % (
		_rate(open.contacts, open.rallies) - _rate(closed.contacts, closed.rallies)
	))
	print("  delta kill rate           %+.3f" % (
		_rate(open.kills, open.swings) - _rate(closed.kills, closed.swings)
	))
	print("  delta dig rate            %+.3f" % (
		_rate(open.digs_up, open.digs) - _rate(closed.digs_up, closed.digs)
	))
	print("  delta stuff rate          %+.3f" % (
		_rate(open.stuffs, open.swings) - _rate(closed.stuffs, closed.swings)
	))
	print("  delta serve-error rate    %+.3f" % (
		_rate(open.serve_errors, open.serves)
			- _rate(closed.serve_errors, closed.serves)
	))
	quit()


func _arm(open_claimants: bool) -> Dictionary:
	var report := {
		"rallies": 0, "contacts": 0, "swings": 0, "kills": 0,
		"digs": 0, "digs_up": 0, "stuffs": 0,
		"serves": 0, "serve_errors": 0, "signatures": {},
	}
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SIDE):
			var result: Resource = manager.resolve_active_rally(
				seed_value, false, false, false, false, open_claimants
			)
			if result == null:
				continue
			report.rallies += 1
			_collect(result, report)
			report.signatures["%s:%d" % [serving_home, seed_value]] = \
				_signature(result)
		manager.free()
	return report


func _collect(result: Resource, report: Dictionary) -> void:
	for raw_event in result.events:
		var event: Resource = raw_event
		var kind: String = event.type_name()
		if kind not in ["Set Decision", "Point"]:
			report.contacts += 1
		if kind == "Serve":
			report.serves += 1
		if kind == "Attack":
			report.swings += 1
		if kind == "Dig":
			report.digs += 1
			if bool(event.success):
				report.digs_up += 1
		if kind == "Block" and str(event.metadata.get("outcome", "")) == "stuff":
			report.stuffs += 1
	var outcome := str(result.terminal_outcome)
	if outcome in ["kill", "opponent_kill"]:
		report.kills += 1
	if outcome in ["serve_error", "home_serve_error"]:
		report.serve_errors += 1


func _signature(result: Resource) -> String:
	var parts: Array[String] = [
		str(result.terminal_outcome), str(result.home_team_won),
		str(result.decisive_actor_id),
	]
	for raw_event in result.events:
		var event: Resource = raw_event
		parts.append("%s:%d:%s" % [
			event.type_name(), int(event.actor_id), str(event.success),
		])
	return "|".join(parts)


func _print_arm(label: String, report: Dictionary) -> void:
	print("  %s contacts/rally     %.3f" % [label, _rate(
		report.contacts, report.rallies
	)])
	print("  %s kill/dig/stuff/error   %.3f / %.3f / %.3f / %.3f" % [
		label, _rate(report.kills, report.swings),
		_rate(report.digs_up, report.digs), _rate(report.stuffs, report.swings),
		_rate(report.serve_errors, report.serves),
	])


func _rate(numerator: Variant, denominator: Variant) -> float:
	return float(numerator) / maxf(float(denominator), 1.0)
