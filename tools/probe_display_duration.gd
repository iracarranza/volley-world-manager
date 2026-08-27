extends SceneTree
const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BP := preload("res://scripts/simulation/ball_presentation.gd")
func _initialize() -> void:
	var bad := 0; var worst := 0.0; var total := 0; var nan_count := 0
	for side in range(2):
		for i in range(60):
			var m = MANAGER.new(); m.seed_vertical_slice_data(); m.match_state.serving_home = side == 0
			var r: Resource = m.resolve_active_rally(500000 + i)
			if r == null: continue
			var cs: Array = []
			for raw in r.events:
				var e := raw as RallyEvent
				if e == null or int(e.actor_id) < 0: continue
				if int(e.event_type) in [RallyEvent.EventType.SET_DECISION, RallyEvent.EventType.POINT]: continue
				cs.append(e)
			for p in range(cs.size()):
				var e: RallyEvent = cs[p]
				var nxt: RallyEvent = cs[p+1] if p+1 < cs.size() else null
				var t: Dictionary = e.metadata.get("outgoing_trajectory", {})
				if t.is_empty(): continue
				var d: Dictionary = BP.display_trajectory(e, nxt, t, r.player_physical_profiles)
				var dur := float(d.get("duration", -1.0))
				total += 1
				if is_nan(dur) or is_inf(dur): nan_count += 1
				elif dur <= 0.0 or dur > 3.5: bad += 1
				worst = maxf(worst, dur if not (is_nan(dur) or is_inf(dur)) else 0.0)
	print("legs %d | NaN/inf %d | outside (0,3.5] %d | longest %.3f s" % [total, nan_count, bad, worst])
	quit(0)
