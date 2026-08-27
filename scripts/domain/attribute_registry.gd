class_name AttributeRegistry
extends RefCounted

## Canonical identity/metadata registry for player ability attributes.
## Formulas remain in their owning gameplay systems; this registry gives every
## generator, role, region, scout, trainer and UI one attribute vocabulary.

const ABILITY_ATTRIBUTES := AttributeRegistry.ABILITY_ATTRIBUTES

const PHYSICAL_ATTRIBUTES := AttributeRegistry.PHYSICAL_ATTRIBUTES

const MENTAL_ATTRIBUTES := AttributeRegistry.MENTAL_ATTRIBUTES

static func all_ids() -> Array[String]:
    var result: Array[String] = []
    for attribute in ABILITY_ATTRIBUTES:
        result.append(str(attribute))
    return result


static func category_of(attribute_id: String) -> String:
    if attribute_id in PHYSICAL_ATTRIBUTES:
        return "Physical"
    if attribute_id in MENTAL_ATTRIBUTES:
        return "Mental"
    return "Technical"


static func definition(attribute_id: String) -> Dictionary:
    return {
        "id": attribute_id,
        "category": category_of(attribute_id),
        "trainable": attribute_id in ABILITY_ATTRIBUTES,
        "scoutable": attribute_id in ABILITY_ATTRIBUTES,
    }


static func invalid_ids(attribute_ids: Array) -> Array[String]:
    var invalid: Array[String] = []
    for attribute in attribute_ids:
        var key := str(attribute)
        if key not in ABILITY_ATTRIBUTES and key not in invalid:
            invalid.append(key)
    return invalid
