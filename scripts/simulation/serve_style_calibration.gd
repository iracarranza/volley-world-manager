class_name ServeStyleCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const CalibrationReportModel := preload("res://scripts/simulation/rally_calibration_report.gd")

const SERVE_STYLES: Array[String] = [
	"Standing", "Jump Topspin", "Jump Float", "Hybrid", "Sky Ball",
]
const CONTROLLED_PROFICIENCY: int = 75


## Uses identical seed ranges and serve proficiency for every style. Each style
## receives a fresh manager so fixtures cannot inherit state from another style.
static func run(
	samples_per_style: int,
	start_seed: int,
	gate_name: String = "serve_style_calibration_gate_2",
) -> Dictionary:
	var safe_sample_count := maxi(samples_per_style, 1)
	var report := CalibrationReportModel.new(gate_name)
	var fixture_errors: Array[String] = []
	for serve_style in SERVE_STYLES:
		var manager := GameManagerModel.new()
		manager.seed_vertical_slice_data()
		var server := _legal_opponent_server(manager)
		if server == null:
			fixture_errors.append("%s: legal opponent server missing" % serve_style)
			continue
		server.primary_serve_style = serve_style
		server.serve_style_proficiencies[serve_style] = CONTROLLED_PROFICIENCY
		for offset in range(safe_sample_count):
			manager.match_state.serving_home = false
			var result: Resource = manager.resolve_active_rally(start_seed + offset)
			var trace: Dictionary = result.analysis.get("shadow_reception", {}) \
				if result != null and result.analysis is Dictionary else {}
			report.add_shadow_trace(trace)
	var summary := report.build_summary()
	summary["fixture"] = {
		"serve_styles": SERVE_STYLES.duplicate(),
		"samples_per_style": safe_sample_count,
		"controlled_proficiency": CONTROLLED_PROFICIENCY,
		"paired_seed_start": start_seed,
		"fixture_errors": fixture_errors,
	}
	summary["style_coverage_complete"] = (
		fixture_errors.is_empty()
		and Dictionary(summary.get("by_serve_style", {})).size()
			== SERVE_STYLES.size()
	)
	return summary


static func _legal_opponent_server(manager: Node) -> VolleyballPlayer:
	if manager == null or manager.opponent_team == null:
		return null
	var lineup: RotationLineup = manager.opponent_team.current_lineup()
	if lineup == null:
		return null
	return manager.opponent_team.player_by_id(
		lineup.player_at_slot(1)
	) as VolleyballPlayer
