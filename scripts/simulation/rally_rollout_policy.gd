class_name RallyRolloutPolicy
extends RefCounted

const FeatureFlags := preload("res://scripts/simulation/rally_feature_flags.gd")
const ReceptionRolloutAuditModel := preload(
	"res://scripts/simulation/reception_rollout_audit.gd"
)


## Central source-selection boundary. Gate 15 intentionally has no shadow-event
## activation branch: enabling live replacement requires a later reviewed gate.
static func select_reception_source(
	official_events: Array[Resource],
	shadow_summary: Dictionary,
	home_lineup: RotationLineup = null,
	rollout_enabled: bool = FeatureFlags.ENABLE_CONTINUOUS_RECEPTION_EVENTS,
) -> Dictionary:
	var audit := ReceptionRolloutAuditModel.evaluate(shadow_summary, home_lineup)
	var use_candidate := rollout_enabled and bool(audit.get("eligible", false))
	var selected_reception: Dictionary = audit.get("reception_event", {}) \
		if use_candidate else {}
	return {
		"flag_enabled": rollout_enabled,
		"selected_source": "continuous_reception" if use_candidate else "official",
		"candidate_available": bool(audit.get("eligible", false)),
		"candidate_audit": audit,
		"selected_reception": selected_reception,
		"selected_events": [selected_reception] if use_candidate else official_events,
		"selected_event_count": 1 if use_candidate else official_events.size(),
		"official_identity_preserved": not use_candidate,
		"activation_implemented": true,
		"fallback_reason": "" if use_candidate else (
			"rollout_disabled" if not rollout_enabled else ";".join(
				Array(audit.get("failure_reasons", []))
			)
		),
	}
