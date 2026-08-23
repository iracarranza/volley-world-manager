extends SceneTree

## Which execution channel actually puts a serve in the tape.
##
##     godot --headless --path . --script res://tools/run_serve_miss_channels.gd
##
## The forward serve plans its clearance against **vertical** spread, which is
## the budget `_feasible_launch` derived for a swing. A swing is struck between
## 0.36 and 4 m from the tape; a serve is struck nine metres from it, and over
## that ground the gravity drop term is dominated by speed rather than by angle.
## So the question this answers is whether the planned margin is being spent by
## the channel it budgets for, or by one it does not.
##
## Straight at the resolver, no rally: one server, one aim, many draws.

const GeometricAttackResolver := preload(
	"res://scripts/simulation/geometric_attack_resolver.gd"
)
const GeometricAttackPromotion := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const SAMPLES: int = 2000


func _initialize() -> void:
	var server := VolleyballPlayer.new()
	server.id = 7
	server.height_cm = 190.0
	server.wingspan_cm = 194.0
	server.jump_reach = 60
	server.explosiveness = 60
	server.serve_power = 70
	server.serve_technique = 65
	server.serve_consistency = 60
	server.primary_serve_style = "Topspin"
	var contact := Vector2(0.82, 0.92)
	var height: float = GeometricAttackPromotion.serve_contact_height_meters(
		server,
		GeometricAttackPromotion.serve_effort_for_style(
			str(server.primary_serve_style)
		),
	)
	var spin: Dictionary = BallSpin.from_serve(
		str(server.primary_serve_style), 0.70, 0.65, true
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99001
	var by_outcome := {}
	## Sums of each channel's draw, split by whether the ball netted, so a
	## channel that decides the miss shows up as a shifted mean rather than as a
	## story about which term looks biggest in the formula.
	var netted_power := 0.0
	var netted_vertical := 0.0
	var netted := 0
	var clean_power := 0.0
	var clean_vertical := 0.0
	var clean := 0
	for sample in range(SAMPLES):
		var draws := GeometricAttackPromotion.serve_draws(rng)
		var serve: Dictionary = GeometricAttackResolver.resolve_serve(
			server, contact, height, Vector2(0.20, 0.16), true, 0.5, draws, spin
		)
		var outcome := "%s:%s" % [
			str(serve.outcome), str(serve.get("out_reason", ""))
		]
		by_outcome[outcome] = int(by_outcome.get(outcome, 0)) + 1
		if str(serve.get("out_reason", "")) == "net":
			netted += 1
			netted_power += float(draws.power)
			netted_vertical += float(draws.vertical)
		elif str(serve.outcome) == "in":
			clean += 1
			clean_power += float(draws.power)
			clean_vertical += float(draws.vertical)
	print("outcomes: %s" % by_outcome)
	if netted > 0 and clean > 0:
		print("netted  n=%d  mean power draw %+.3f  mean vertical draw %+.3f" % [
			netted, netted_power / netted, netted_vertical / netted])
		print("clean   n=%d  mean power draw %+.3f  mean vertical draw %+.3f" % [
			clean, clean_power / clean, clean_vertical / clean])
		print("A channel that decides the miss shows a mean far from zero.")
	quit()
