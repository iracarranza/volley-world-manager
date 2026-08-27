class_name RegionProfiles
extends RefCounted

## Player-development/profile inputs by region. PlayerGenerator composes these
## profiles; it no longer authors the world's regional definitions.

const REGION_HEIGHT_BIAS := RegionProfiles.REGION_HEIGHT_BIAS

const REGION_MASS_BIAS := RegionProfiles.REGION_MASS_BIAS

const REGION_WINGSPAN_BIAS := RegionProfiles.REGION_WINGSPAN_BIAS

const REGION_SPECIALTY := RegionProfiles.REGION_SPECIALTY

const REGION_EGO_BIAS := RegionProfiles.REGION_EGO_BIAS

const REGION_AGGRESSION_BIAS := RegionProfiles.REGION_AGGRESSION_BIAS

const REGION_CEILING_PENALTY := RegionProfiles.REGION_CEILING_PENALTY

static func specialty(region_name: String) -> Array:
    return Array(REGION_SPECIALTY.get(region_name, []))


static func physique(region_name: String) -> Dictionary:
    return {
        "height": float(REGION_HEIGHT_BIAS.get(region_name, 0.0)),
        "mass": float(REGION_MASS_BIAS.get(region_name, 0.0)),
        "wingspan": float(REGION_WINGSPAN_BIAS.get(region_name, 0.0)),
    }
