class_name BodyTypeGameplay
extends RefCounted

## Gameplay-side body definitions. Rendering remains in body_type_models.gd;
## the body-type key is the explicit contract between simulation and presentation.

const BODY_TYPES := BodyTypeGameplay.BODY_TYPES

const BODY_TYPE_METRICS := BodyTypeGameplay.BODY_TYPE_METRICS

const BODY_TYPE_ATTRIBUTES := BodyTypeGameplay.BODY_TYPE_ATTRIBUTES

static func attribute_modifiers(body_type: String) -> Dictionary:
    return Dictionary(BODY_TYPE_ATTRIBUTES.get(body_type, {}))


static func metric_modifiers(body_type: String) -> Dictionary:
    return Dictionary(BODY_TYPE_METRICS.get(body_type, {}))
