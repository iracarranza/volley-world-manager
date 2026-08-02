extends SceneTree
const REPORT := preload("res://scripts/simulation/rally_readiness_report.gd")
const GM := preload("res://scripts/managers/game_manager.gd")
const EV := preload("res://scripts/models/rally_event.gd")
func _init() -> void:
	var c: Dictionary = REPORT.outcome_calibration(90, 900000)
	print("home_attack_share=%.3f (home %d, opponent %d)" % [
		float(c.get("home_attack_share", 0.0)),
		int(c.get("home_attack_wins", 0)), int(c.get("opponent_attack_wins", 0))])
	# how many opponent attacks the failing check's window actually yields
	var m := GM.new()
	m.seed_vertical_slice_data()
	var attacks := 0
	var staged := 0
	for seed_value in range(20000, 20420):
		var r: Resource = m.resolve_active_rally(seed_value)
		for e_res in r.events:
			var e: Resource = e_res
			if str(e.metadata.get("side", "")) != "opponent":
				continue
			if e.metadata.has("staged_next_actor_id"):
				staged += 1
			if e.metadata.has("resolved_approach"):
				attacks += 1
	print("coverage window 20000-20420: opponent attacks with resolved_approach=%d staged=%d" % [attacks, staged])
	quit()
