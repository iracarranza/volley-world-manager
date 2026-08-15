extends SceneTree

## Does a team identity actually change which shot gets hit?
##
##     godot --headless --path . --script res://tools/run_identity_shot_probe.gd
##
## `_identity_hit_type` is the only path by which a team's `decisiveness`
## reaches its attack **error** rate: a cautious side substitutes a controlled
## roll or a tip on a ball it does not like, and a safe shot misses less often.
## `_attack_effectiveness` deliberately does not touch error -- its own comment
## says "execution still decides whether the ball lands in" -- so if the
## substitution does not fire, the identity cannot move error at all.
##
## The suite asserts that it does, across six career seeds. This prints the
## substitution rate directly, and it prints what `_identity_hit_type` actually
## returned rather than what the attack ended up as, so a branch that never fires
## can be told from one whose result is overwritten downstream.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const PrincipleScript := preload("res://scripts/models/team_principles.gd")
func _initialize() -> void:
	for identity in ["Defensive", "Physical"]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.team.principles = PrincipleScript.for_identity(identity)
		var attacks := 0
		var safe := 0
		var errors := 0
		var transition := 0
		var set_quals := []
		for seed_value in range(70000, 70200):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null: continue
			var last_set := 0.5
			var last_path := "first"
			for raw in result.events:
				var e: Resource = raw
				if int(e.event_type) == RallyEventScript.EventType.SET \
						and str(e.metadata.get("side","")) == "home":
					last_set = float(e.quality)
					last_path = str(e.metadata.get("set_path", "home_first_ball"))
				if int(e.event_type) != RallyEventScript.EventType.ATTACK: continue
				if str(e.metadata.get("side","")) != "home": continue
				attacks += 1
				if last_path == "home_transition":
					transition += 1
				set_quals.append(last_set)
				var kind := str(e.metadata.get("attack_type",""))
				if kind in ["Controlled roll", "Emergency tip", "Roll shot", "Tip"]:
					safe += 1
				if bool(e.metadata.get("attack_missed", false)) or not bool(e.success):
					errors += 1
		## Verify the identity actually reached the resolver before believing any
		## rate measured under it. The last result carries it.
		var applied := "?"
		var probe: Resource = manager.resolve_active_rally(79999)
		if probe != null:
			applied = str(Dictionary(probe.analysis).get("team_identity", "?"))
		print("  (resolver saw identity: %s)" % applied)
		## What `_identity_hit_type` actually returned, which distinguishes "the
		## branch never fired" from "it fired and something downstream overwrote
		## it". `identity_effects` is published on the result for exactly this.
		var chosen := {}
		var seen_decisiveness := -1.0
		for seed_value in range(70000, 70200):
			var r: Resource = manager.resolve_active_rally(seed_value)
			if r == null: continue
			var effects: Dictionary = Dictionary(r.analysis).get("identity_effects", {})
			var selection: Dictionary = effects.get("attack_selection", {})
			if selection.has("hit_type"):
				var t := str(selection.hit_type)
				chosen[t] = int(chosen.get(t, 0)) + 1
			var principles: Dictionary = Dictionary(r.analysis).get("team_principles", {})
			if principles.has("decisiveness"):
				seen_decisiveness = float(principles.decisiveness)
		print("  identity_hit_type returned: ", chosen)
		print("  resolver decisiveness: %.2f" % seen_decisiveness)
		set_quals.sort()
		var below := 0
		for q in set_quals:
			if float(q) < 0.48: below += 1
		print("%-10s attacks %4d  safe %5.1f%%  error %5.1f%%  set<0.48 %5.1f%%  from transition %5.1f%%" % [
			identity, attacks, float(safe)/maxf(attacks,1)*100.0,
			float(errors)/maxf(attacks,1)*100.0,
			float(below)/maxf(set_quals.size(),1)*100.0,
			float(transition)/maxf(attacks,1)*100.0])
		manager.free()
	quit()
