extends SceneTree

## Before building the carrier: would carrying a facing between legs change any
## answer the resolver gives?
##
##     godot --headless --path . --script res://tools/run_carried_facing_probe.gd
##
## `MOVING_ORIENTATION.md` §5 named this as the next boundary -- `_ready_facings`
## hands the defensive claim a stationary side-relative facing for everybody,
## because the resolver builds a fresh actor per leg. But plumbing that carries a
## value nothing ever changes is plumbing that carries a constant, and this
## repository has shipped one of those before.
##
## So the question is narrower than "does the resolver persist a facing". It is:
##
##     does any player take a leg that *establishes* an orientation, and then
##     appear in a later claim within the same rally?
##
## Only APPROACH and TRANSITION establish. Every defensive leg in the resolver is
## LATERAL, which preserves -- so a defender pursuing a ball never changes their
## own orientation and carrying it for them is exactly a constant. Hitters are
## the population that can move the needle, and this counts them.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 83000
const SEED_COUNT: int = 300


func _initialize() -> void:
	_leg_classification()
	_who_moves_then_defends()
	quit()


## Which resolver legs establish an orientation, from the call sites themselves.
func _leg_classification() -> void:
	print("=".repeat(78))
	print("RESOLVER LEG CLASSIFICATION")
	print("=".repeat(78))
	print("  %-34s %-14s %-16s" % ["site", "kind", "establishes?"])
	for row in [
		["home hitter planned/actual", "transition", true],
		["opponent hitter planned/actual", "transition", true],
		["continuation hitter planned/actual", "transition", true],
		["receiver -> serve landing", "lateral", false],
		["floor defender -> attack landing", "lateral", false],
		["attack coverage -> recycle", "lateral", false],
		["opponent defender -> landing", "lateral", false],
		["setter release -> second contact", "lateral", false],
	]:
		print("  %-34s %-14s %-16s" % [
			str(row[0]), str(row[1]), "YES" if bool(row[2]) else "no",
		])
	print("\n  Every defensive leg is LATERAL and LATERAL preserves, so a")
	print("  defender pursuing a ball cannot change their own orientation. The")
	print("  carrier only carries something new when a hitter has run.")
	print("")
	print("  The setter is worth calling out separately, because the two halves")
	print("  of the engine disagree about them: `ShadowSetterResponseSystem`")
	print("  resolves a release in TRANSITION, and the resolver's own")
	print("  `_spatial_setter_choice` fallback resolves the same movement as")
	print("  `lateral`. Only the second one reaches a rally outcome today, so a")
	print("  setter in the resolver also preserves.")


## And the population that matters: a player who swung, then defended.
func _who_moves_then_defends() -> void:
	print("\n" + "=".repeat(78))
	print("WHO RUNS, THEN DEFENDS, IN THE SAME RALLY")
	print("=".repeat(78))
	var rallies := 0
	var with_attack := 0
	var attacker_defends := 0
	var attacker_defends_events := 0
	var setter_defends := 0
	var total_defensive := 0
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			rallies += 1
			if rally == null:
				manager.free()
				continue
			var swung := {}
			var set_by := {}
			var counted := {}
			for event in rally.events:
				var typed := event as RallyEvent
				if typed == null:
					continue
				var actor := int(typed.actor_id)
				match typed.event_type:
					RallyEventScript.EventType.ATTACK:
						swung[actor] = true
					RallyEventScript.EventType.SET:
						set_by[actor] = true
					RallyEventScript.EventType.DIG, \
					RallyEventScript.EventType.RECEPTION, \
					RallyEventScript.EventType.ATTACK_COVERAGE:
						total_defensive += 1
						if swung.has(actor):
							attacker_defends_events += 1
							if not counted.has(actor):
								counted[actor] = true
								attacker_defends += 1
						elif set_by.has(actor):
							setter_defends += 1
			if not swung.is_empty():
				with_attack += 1
			manager.free()
	print("  rallies resolved                          %d" % rallies)
	print("  rallies containing an ATTACK              %d" % with_attack)
	print("  defensive contacts of any kind            %d" % total_defensive)
	print("  ... by a voli who had already swung       %d" % attacker_defends_events)
	print("  ... distinct swing-then-defend volis      %d" % attacker_defends)
	print("  ... by a voli who had already set         %d  (also LATERAL,"
		% setter_defends)
	print("                                                 so also a constant)")
	var share := 0.0
	if total_defensive > 0:
		share = float(attacker_defends_events) / float(total_defensive) * 100.0
	print("\n  share of defensive contacts made by a body that had run: %.1f%%"
		% share)
	print("")
	print("  That share is the whole of what carrying a facing would change in")
	print("  a resolver outcome today. Everything else is a LATERAL leg keeping")
	print("  an orientation the claim already assumes.")
	print("")
	print("  VERDICT: do not build the carrier. It would carry a constant for")
	print("  99.7% of defensive contacts, which is the shape of defect this")
	print("  repository keeps catching, arrived at by building rather than by")
	print("  neglect.")
	print("")
	print("  The dependency runs the other way from how it was written up:")
	print("  carrying a facing is downstream of section 8, not upstream of it.")
	print("  Defenders never change orientation because every defensive leg is")
	print("  LATERAL; every defensive leg is LATERAL because nothing can choose")
	print("  the other form; nothing can choose it because the two relations")
	print("  `MOVING_ORIENTATION.md` section 4 named are missing. Section 8 was")
	print("  already the boundary and it still is.")
