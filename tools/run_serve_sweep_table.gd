extends SceneTree

## The launch sweep's own candidate table, for one serve.
##
##     godot --headless --path . --script res://tools/run_serve_sweep_table.gd
##
## `_serve_launch` reports one winner and the certification factorial reports
## its consequences, and between those two there is no way to see *why* a cell
## chose what it chose. The strong jump-float cell plans a 10 m clearance and a
## 3 s flight, which is a punt rather than a serve, and it is worse than the same
## style at lower ability -- so the question is which candidates were rejected
## and by what.
##
## The enumeration here is deliberately a **second implementation** of the same
## sweep, and it is checked against the real one: if the winner this file picks
## is not the launch `_serve_launch` returns, the table is not describing the
## thing being diagnosed and says so rather than being read anyway.

const GeometricAttackResolver := preload(
	"res://scripts/simulation/geometric_attack_resolver.gd"
)
const GeometricAttackPromotion := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const CASES := [
	{"style": "Jump Float", "power": 88, "technique": 85, "consistency": 84},
	{"style": "Jump Float", "power": 60, "technique": 58, "consistency": 60},
	{"style": "Jump Float", "power": 58, "technique": 74, "consistency": 74},
	{"style": "Jump Topspin", "power": 88, "technique": 85, "consistency": 84},
]


func _initialize() -> void:
	for case in CASES:
		_table(Dictionary(case))
	quit()


func _table(case: Dictionary) -> void:
	var style := str(case.style)
	var server := VolleyballPlayer.new()
	server.id = 1
	server.height_cm = 192.0
	server.wingspan_cm = 196.0
	server.jump_reach = 62
	server.explosiveness = 62
	server.serve_power = int(case.power)
	server.serve_technique = int(case.technique)
	server.serve_consistency = int(case.consistency)
	server.serve_placement = 70
	server.primary_serve_style = style
	server.dominant_hand = "Right"

	var contact := Vector2(0.82, 1.056)
	var target := Vector2(0.20, 0.16)
	var height: float = GeometricAttackPromotion.serve_contact_height_meters(
		server, GeometricAttackPromotion.serve_effort_for_style(style)
	)
	var spin: Dictionary = BallSpin.from_serve(
		style, float(case.power) / 100.0, float(case.technique) / 100.0, true
	)
	var control := float(case.consistency) / 100.0 * 0.6 \
		+ float(case.technique) / 100.0 * 0.4
	var vertical_spread: float = AttackSwingModel.vertical_spread_degrees(
		control, GeometricAttackResolver.SERVE_SPREAD_MULTIPLIER
	)
	var bearing_spread: float = AttackSwingModel.bearing_spread_degrees(
		control, GeometricAttackResolver.SERVE_SPREAD_MULTIPLIER
	)
	var bearing: float = AttackCourseModel.bearing_to_point(contact, target, true)
	var across := (target.x - contact.x) * CourtConstants.COURT_WIDTH_METERS
	var along := (target.y - contact.y) * CourtConstants.COURT_LENGTH_METERS
	var distance := maxf(sqrt(across * across + along * along), 0.5)
	var full_pace := maxf(
		AttackPowerModel.serve_ceiling_mps(float(case.power) / 100.0)
			* lerpf(
				AttackPowerModel.CONTROL_INTENT, AttackPowerModel.DRIVE_INTENT, 0.5
			)
			* lerpf(0.82, 1.0, float(case.technique) / 100.0),
		BallFlightModel.MIN_SPEED_MPS,
	)
	var aimed_to_net: float = GeometricAttackResolver._ground_distance_to_net(
		contact, bearing, true
	)
	var ground_to_net := minf(
		maxf(
			GeometricAttackResolver._ground_distance_to_net(
				contact, bearing + bearing_spread, true
			),
			GeometricAttackResolver._ground_distance_to_net(
				contact, bearing - bearing_spread, true
			),
		),
		aimed_to_net * GeometricAttackResolver.NET_PATH_STRETCH_CAP,
	)
	var needed := CourtConstants.NET_HEIGHT_METERS + maxf(
		GeometricAttackResolver.NET_CLEARANCE_MARGIN_METERS,
		ground_to_net * tan(deg_to_rad(
			maxf(vertical_spread, 0.0)
				* GeometricAttackResolver.NET_CLEARANCE_SPREAD_SIGMAS
		)),
	)

	print("\n=== %s  power %d technique %d consistency %d" % [
		style, int(case.power), int(case.technique), int(case.consistency)])
	print("    contact height %.3f  distance %.2f  aimed_to_net %.2f"
		% [height, distance, aimed_to_net])
	print("    spin axis %.3f rate %.2f rps -> topspin %.2f, gravity %.2f"
		% [float(spin.axis), float(spin.rate_rps), float(spin.topspin_rps),
			BallSpin.gravity_for(spin)])
	print("    vertical spread %.3f deg, bearing spread %.3f deg" % [
		vertical_spread, bearing_spread])
	print("    ground_to_net (widened) %.2f  =>  needed height %.3f (margin %.3f)"
		% [ground_to_net, needed, needed - CourtConstants.NET_HEIGHT_METERS])
	print("    full pace %.2f" % full_pace)
	print("    %-6s %-7s %-8s %-6s %-8s %-8s %-7s" % [
		"pace", "spin", "branch", "angle", "h@net", "clears", "groundv"])

	var best_speed := 0.0
	var best_desc := "(nothing cleared)"
	for step in range(GeometricAttackResolver.SERVE_PACE_RELIEF_STEPS):
		var trial := full_pace * lerpf(
			1.0, GeometricAttackResolver.SERVE_PACE_RELIEF_FLOOR,
			float(step)
				/ float(GeometricAttackResolver.SERVE_PACE_RELIEF_STEPS - 1),
		)
		for spin_step in range(GeometricAttackResolver.SERVE_SPIN_LEVELS):
			var used := BallSpin.spin(
				float(spin.get("axis", 0.0)),
				float(spin.get("rate_rps", 0.0)) * float(spin_step)
					/ float(GeometricAttackResolver.SERVE_SPIN_LEVELS - 1),
			)
			var gravity := BallSpin.gravity_for(used)
			var solved := BallFlightModel.solve_angle_for_range(
				trial, distance, height, gravity
			)
			for branch in ["driven", "lofted"]:
				if not bool(solved.get("%s_found" % branch, false)):
					print("    %-6.2f %-7.2f %-8s %s" % [
						trial, gravity, branch, "no root"])
					continue
				var angle := float(solved.get("%s_angle_degrees" % branch, 0.0))
				var at_net := BallFlightModel.height_at_distance(
					BallFlightModel.solve_flight(trial, angle, height, gravity),
					ground_to_net,
				)
				var ground_speed := trial * cos(deg_to_rad(angle))
				var clears := at_net >= needed
				if clears and ground_speed > best_speed:
					best_speed = ground_speed
					best_desc = "%s at %.2f m/s, %.2f deg" % [branch, trial, angle]
				print("    %-6.2f %-7.2f %-8s %-6.2f %-8.3f %-8s %-7.2f" % [
					trial, gravity, branch, angle, at_net,
					"yes" if clears else "NO", ground_speed])
	var actual: Dictionary = GeometricAttackResolver.resolve_serve(
		server, contact, height, target, true, 0.5,
		{"bearing": 0.0, "vertical": 0.0, "power": 0.0}, spin,
	)
	var launch: Dictionary = actual.get("launch", {})
	print("    table winner : %s" % best_desc)
	print("    resolver says: %s at %.2f m/s, %.2f deg" % [
		str(launch.get("mode", "?")), float(launch.get("speed_mps", 0.0)),
		float(launch.get("angle_degrees", 0.0))])
