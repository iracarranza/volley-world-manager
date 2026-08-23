extends SceneTree
const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BP := preload("res://scripts/simulation/ball_presentation.gd")
func _initialize() -> void:
	var agg := {}
	for index in range(60):
		var m = MANAGER.new(); m.seed_vertical_slice_data(); m.match_state.serving_home = false
		var r: Resource = m.resolve_active_rally(400000 + index)
		if r == null: continue
		var profiles: Dictionary = r.player_physical_profiles
		var cs: Array = []
		for raw in r.events:
			var e := raw as RallyEvent
			if e == null or int(e.actor_id) < 0: continue
			if int(e.event_type) in [RallyEvent.EventType.SET_DECISION, RallyEvent.EventType.POINT]: continue
			cs.append(e)
		for p in range(cs.size() - 1):
			var e: RallyEvent = cs[p]; var n: RallyEvent = cs[p + 1]
			var t: Dictionary = e.metadata.get("outgoing_trajectory", {})
			if t.is_empty(): continue
			if not t.has("end_height_meters"): continue
			var pair := "%s->%s" % [str(RallyEvent.EventType.keys()[int(e.event_type)]), str(RallyEvent.EventType.keys()[int(n.event_type)])]
			var d: Dictionary = BP.display_trajectory(e, n, t, profiles)
			var published := float(t.get("end_height_meters", NAN))
			var drawn := float(d.get("end_height_meters", NAN))
			var body := BP.contact_height(n, profiles)
			if not agg.has(pair): agg[pair] = {"n":0,"pub_vs_drawn":0.0,"pub_vs_body":0.0}
			var a: Dictionary = agg[pair]
			a["n"] = int(a["n"]) + 1
			a["pub_vs_drawn"] = float(a["pub_vs_drawn"]) + absf(published - drawn)
			a["pub_vs_body"] = float(a["pub_vs_body"]) + absf(published - body)
	print("%-24s %5s %14s %14s" % ["pair","n","|pub-drawn|","|pub-body|"])
	var ks: Array = agg.keys(); ks.sort()
	for k in ks:
		var a: Dictionary = agg[k]; var n := maxi(int(a["n"]),1)
		print("%-24s %5d %14.3f %14.3f" % [str(k), int(a["n"]), float(a["pub_vs_drawn"])/float(n), float(a["pub_vs_body"])/float(n)])
	quit(0)
