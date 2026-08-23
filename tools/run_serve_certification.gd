extends SceneTree

## The forward serve, measured under control.
##
##     godot --headless --path . --script res://tools/run_serve_certification.gd
##
## **A factorial, not a sample of the game.** The live census in
## `run_serve_census.gd` measures what the vertical slice's twelve servers
## actually do, which is the ecological question and cannot separate a style
## effect from the fact that one roster's setter serves standing. This calls the
## resolver directly across side x style x risk x ability, so every cell has the
## same number of draws and a main effect is a main effect.
##
## The planned launch is obtained by resolving the same serve with **all three
## execution draws at zero** rather than by reproducing the resolver's arithmetic
## here. A probe that recomputes what it is measuring is measuring its own copy;
## this repository has that mistake written down twice.

const GeometricAttackResolver := preload(
	"res://scripts/simulation/geometric_attack_resolver.gd"
)
const GeometricAttackPromotion := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const SAMPLES_PER_CELL: int = 400
const STYLES: Array[String] = [
	"Standing", "Jump Topspin", "Jump Float", "Hybrid", "Sky Ball",
]
const RISKS: Array[float] = [0.0, 0.5, 1.0]

## Weak, average and strong at the serve, spanning the attribute range the world
## generator actually produces rather than 0 and 100.
const ABILITIES := {
	"weak": {"power": 35, "technique": 30, "consistency": 35, "placement": 30},
	"average": {"power": 60, "technique": 58, "consistency": 60, "placement": 55},
	"strong": {"power": 88, "technique": 85, "consistency": 84, "placement": 86},
}

## Both ends of the court, mirrored. `attacking_negative_y` is the direction of
## travel, so the home server stands at high y and serves toward low.
const SIDES := {
	"home": {
		"contact": Vector2(0.82, 1.056), "target": Vector2(0.20, 0.16),
		"negative_y": true,
	},
	"opp": {
		"contact": Vector2(0.82, -0.056), "target": Vector2(0.20, 0.84),
		"negative_y": false,
	},
}


func _initialize() -> void:
	var rows: Array[String] = []
	rows.append(
		"side|style|risk|ability|sample|outcome|reason|speed|angle|vx|vy"
		+ "|contact_h|clear_planned|clear_real|relief|mode|dur|land_x|land_y"
		+ "|target_err|depth|draw_power|draw_vertical|draw_bearing"
	)
	var rng := RandomNumberGenerator.new()
	for side_name in SIDES:
		var side: Dictionary = SIDES[side_name]
		for style in STYLES:
			for risk in RISKS:
				for ability_name in ABILITIES:
					rows.append_array(_cell(
						rng, str(side_name), side, str(style), float(risk),
						str(ability_name),
					))
	var path := "user://serve_certification.csv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows))
	file.close()
	print("wrote %s (%d rows)" % [
		ProjectSettings.globalize_path(path), rows.size() - 1])
	quit()


func _cell(
	rng: RandomNumberGenerator,
	side_name: String,
	side: Dictionary,
	style: String,
	risk: float,
	ability_name: String,
) -> Array[String]:
	var server := _server(style, ability_name)
	var contact: Vector2 = side.contact
	var target: Vector2 = side.target
	var negative_y: bool = side.negative_y
	var height: float = GeometricAttackPromotion.serve_contact_height_meters(
		server, GeometricAttackPromotion.serve_effort_for_style(style)
	)
	var spin: Dictionary = BallSpin.from_serve(
		style,
		float(ABILITIES[ability_name].power) / 100.0,
		float(ABILITIES[ability_name].technique) / 100.0,
		true,
	)
	## The planned ball: the same resolution with every execution draw at zero.
	var still := {"bearing": 0.0, "vertical": 0.0, "power": 0.0}
	var planned: Dictionary = GeometricAttackResolver.resolve_serve(
		server, contact, height, target, negative_y, risk, still, spin
	)
	var planned_launch: Dictionary = planned.get("launch", {})
	var planned_clearance := float(
		Dictionary(planned.get("resolution", {})).get("net_clearance_meters", 0.0)
	)
	var planned_speed := float(planned_launch.get("speed_mps", 0.0))
	## How much pace this server gave up to get over the tape, as a fraction of
	## what they can produce. The sweep only ever relieves downward, so this is
	## bounded by `SERVE_PACE_RELIEF_FLOOR`.
	var full_pace := maxf(
		AttackPowerModel.serve_ceiling_mps(
			float(ABILITIES[ability_name].power) / 100.0
		) * lerpf(
			AttackPowerModel.CONTROL_INTENT, AttackPowerModel.DRIVE_INTENT,
			clampf(risk, 0.0, 1.0),
		) * lerpf(
			0.82, 1.0, float(ABILITIES[ability_name].technique) / 100.0
		),
		BallFlightModel.MIN_SPEED_MPS,
	)
	var relief := planned_speed / maxf(full_pace, 0.0001)

	rng.seed = hash("%s|%s|%.2f|%s" % [side_name, style, risk, ability_name])
	var rows: Array[String] = []
	for sample in range(SAMPLES_PER_CELL):
		var draws: Dictionary = GeometricAttackPromotion.serve_draws(rng)
		var serve: Dictionary = GeometricAttackResolver.resolve_serve(
			server, contact, height, target, negative_y, risk, draws, spin
		)
		var launch: Dictionary = serve.get("launch", {})
		var landing := Vector2(serve.landing)
		## Depth as a fraction of the receiving half, 0 at the tape and 1 at the
		## endline, so the two sides are comparable without a sign convention.
		var depth := (CourtConstants.NET_Y - landing.y) / CourtConstants.NET_Y \
			if negative_y \
			else (landing.y - CourtConstants.NET_Y) / (1.0 - CourtConstants.NET_Y)
		rows.append(
			"%s|%s|%.1f|%s|%d|%s|%s|%.4f|%.3f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f"
			% [
				side_name, style, risk, ability_name, sample,
				str(serve.outcome), str(serve.get("out_reason", "")),
				float(launch.get("speed_mps", 0.0)),
				float(launch.get("angle_degrees", 0.0)),
				float(launch.get("horizontal_speed_mps", 0.0)),
				float(launch.get("vertical_speed_mps", 0.0)),
				height, planned_clearance,
				float(Dictionary(serve.get("resolution", {})).get(
					"net_clearance_meters", 0.0
				)),
				relief,
			]
			+ "|%s|%.4f|%.5f|%.5f|%.4f|%.4f|%+.4f|%+.4f|%+.4f" % [
				str(launch.get("mode", "")),
				float(Dictionary(serve.get("flight", {})).get(
					"duration_seconds", 0.0
				)),
				landing.x, landing.y,
				_court_distance(landing, target), depth,
				float(draws.power), float(draws.vertical), float(draws.bearing),
			]
		)
	return rows


func _server(style: String, ability_name: String) -> VolleyballPlayer:
	var ability: Dictionary = ABILITIES[ability_name]
	var server := VolleyballPlayer.new()
	server.id = 1
	## One body across every cell, so a style or ability effect is not a height
	## effect wearing its coat. Contact height still varies by style, which is
	## the point of `serve_effort_for_style` and is measured rather than removed.
	server.height_cm = 192.0
	server.wingspan_cm = 196.0
	server.jump_reach = 62
	server.explosiveness = 62
	server.serve_power = int(ability.power)
	server.serve_technique = int(ability.technique)
	server.serve_consistency = int(ability.consistency)
	server.serve_placement = int(ability.placement)
	server.primary_serve_style = style
	server.dominant_hand = "Right"
	return server


func _court_distance(from_point: Vector2, to_point: Vector2) -> float:
	return Vector2(
		(to_point.x - from_point.x) * CourtConstants.COURT_WIDTH_METERS,
		(to_point.y - from_point.y) * CourtConstants.COURT_LENGTH_METERS,
	).length()
