class_name RallyRolloutPolicy
extends RefCounted

const FeatureFlags := preload("res://scripts/simulation/rally_feature_flags.gd")
const ReceptionRolloutAuditModel := preload(
	"res://scripts/simulation/reception_rollout_audit.gd"
)
const SetterRolloutAuditModel := preload(
	"res://scripts/simulation/setter_rollout_audit.gd"
)
const AttackRolloutAuditModel := preload(
	"res://scripts/simulation/attack_rollout_audit.gd"
)
const BlockRolloutAuditModel := preload(
	"res://scripts/simulation/block_rollout_audit.gd"
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


static func select_setter_source(
	shadow_summary: Dictionary,
	home_lineup: RotationLineup = null,
	rollout_enabled: bool = FeatureFlags.ENABLE_CONTINUOUS_SETTER_EVENTS,
) -> Dictionary:
	var audit := SetterRolloutAuditModel.evaluate(shadow_summary, home_lineup)
	var use_candidate := rollout_enabled and bool(audit.get("eligible", false))
	var selected_setter: Dictionary = audit.get("setter_candidate", {}) \
		if use_candidate else {}
	return {
		"flag_enabled": rollout_enabled,
		"selected_source": "continuous_setter" if use_candidate else "official",
		"candidate_available": bool(audit.get("eligible", false)),
		"candidate_audit": audit,
		"selected_setter": selected_setter,
		"official_identity_preserved": not use_candidate,
		"activation_implemented": true,
		"fallback_reason": "" if use_candidate else (
			"rollout_disabled" if not rollout_enabled else ";".join(
				Array(audit.get("failure_reasons", []))
			)
		),
	}


## Gate 48: the block selection boundary. Unlike the three selectors above,
## this one has no activation branch behind it yet -- no LiveBlockIntegrator
## exists, so `activation_implemented` is false and a candidate can never be
## selected regardless of the flag. Building the promotion path is Gate 49.
##
## The lineup argument is the *opponent* lineup: blockers are opponents of the
## attacking home side, and the audit's front-row legality check is meaningless
## against the home lineup.
static func select_block_source(
	shadow_summary: Dictionary,
	opponent_lineup: RotationLineup = null,
	rollout_enabled: bool = FeatureFlags.ENABLE_CONTINUOUS_BLOCK_EVENTS,
) -> Dictionary:
	var shadow_block: Dictionary = shadow_summary.get("shadow_block", {})
	var audit := BlockRolloutAuditModel.evaluate(shadow_block, opponent_lineup)
	var candidate_available := bool(audit.get("eligible", false))
	## Gate 48 deliberately never selects the candidate. `use_candidate` stays
	## false even with the flag on, because promoting a block contact requires
	## the reviewed Gate 49 integrator that does not exist yet.
	var use_candidate := false
	return {
		"flag_enabled": rollout_enabled,
		"selected_source": "official",
		"candidate_available": candidate_available,
		"candidate_audit": audit,
		"selected_block": {},
		"official_identity_preserved": not use_candidate,
		"activation_implemented": false,
		"fallback_reason": "rollout_disabled" if not rollout_enabled else (
			"activation_not_implemented" if candidate_available else ";".join(
				Array(audit.get("failure_reasons", []))
			)
		),
	}


static func select_attack_source(
	shadow_summary: Dictionary,
	home_lineup: RotationLineup = null,
	rollout_enabled: bool = FeatureFlags.ENABLE_CONTINUOUS_ATTACK_EVENTS,
) -> Dictionary:
	var audit := AttackRolloutAuditModel.evaluate(shadow_summary, home_lineup)
	var use_candidate := rollout_enabled and bool(audit.get("eligible", false))
	var selected_attack: Dictionary = audit.get("attack_candidate", {}) \
		if use_candidate else {}
	return {
		"flag_enabled": rollout_enabled,
		"selected_source": "continuous_attack" if use_candidate else "official",
		"candidate_available": bool(audit.get("eligible", false)),
		"candidate_audit": audit,
		"selected_attack": selected_attack,
		"official_identity_preserved": not use_candidate,
		"activation_implemented": true,
		"fallback_reason": "" if use_candidate else (
			"rollout_disabled" if not rollout_enabled else ";".join(
				Array(audit.get("failure_reasons", []))
			)
		),
	}
