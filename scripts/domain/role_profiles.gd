class_name RoleProfiles
extends RefCounted

## Canonical role definitions shared by generation and ability scoring.
## Capabilities remain situational systems: a role describes weighting and
## development preference rather than hard-coded permission to act.

const POSITION_WEIGHTS := RoleProfiles.POSITION_WEIGHTS

const POSITION_APPROACH_STEP_MODIFIER := RoleProfiles.POSITION_APPROACH_STEP_MODIFIER

const POSITION_APPROACH_TOLERANCE_MODIFIER := RoleProfiles.POSITION_APPROACH_TOLERANCE_MODIFIER

const POSITION_EGO_BIAS := RoleProfiles.POSITION_EGO_BIAS

const POSITION_LEADERSHIP_BIAS := RoleProfiles.POSITION_LEADERSHIP_BIAS

const POSITION_AGGRESSION_BIAS := RoleProfiles.POSITION_AGGRESSION_BIAS

const POSITIONS := RoleProfiles.POSITIONS

const ROLE_SECONDARY := RoleProfiles.ROLE_SECONDARY

const ROLE_HEIGHT_SPREAD := RoleProfiles.ROLE_HEIGHT_SPREAD

static func primary_attributes(role_name: String) -> Array:
    return Array(POSITION_WEIGHTS.get(role_name, []))


static func secondary_attributes(role_name: String) -> Array:
    return Array(ROLE_SECONDARY.get(role_name, []))
