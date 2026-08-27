extends SceneTree

const Attributes := preload("res://scripts/domain/attribute_registry.gd")
const Regions := preload("res://scripts/domain/region_profiles.gd")
const Roles := preload("res://scripts/domain/role_profiles.gd")
const Bodies := preload("res://scripts/domain/body_type_gameplay.gd")
const BodyPresentation := preload("res://scripts/data/body_type_models.gd")

func _initialize() -> void:
	var errors: Array[String] = []
	var known: Array = Attributes.ABILITY_ATTRIBUTES.duplicate()
	for trait_id in Attributes.NON_ABILITY_TRAITS:
		if trait_id not in known:
			known.append(trait_id)
	for region_name in Regions.REGION_SPECIALTY:
		for attribute in Array(Regions.REGION_SPECIALTY[region_name]):
			if str(attribute) not in known:
				errors.append("region %s references unknown player trait %s" % [region_name, attribute])
	for role_name in Roles.POSITION_WEIGHTS:
		for attribute in Array(Roles.POSITION_WEIGHTS[role_name]):
			if str(attribute) not in known:
				errors.append("role %s primary references unknown player trait %s" % [role_name, attribute])
	for role_name in Roles.ROLE_SECONDARY:
		for attribute in Array(Roles.ROLE_SECONDARY[role_name]):
			if str(attribute) not in known:
				errors.append("role %s secondary references unknown player trait %s" % [role_name, attribute])
	for body_name in Bodies.BODY_TYPE_ATTRIBUTES:
		for attribute in Dictionary(Bodies.BODY_TYPE_ATTRIBUTES[body_name]):
			if str(attribute) not in known:
				errors.append("body %s references unknown player trait %s" % [body_name, attribute])
	for body_name in Bodies.BODY_TYPES:
		if str(body_name) not in BodyPresentation.MODELLED:
			errors.append("gameplay body %s has no presentation model" % body_name)
	for body_name in BodyPresentation.MODELLED:
		if str(body_name) not in Bodies.BODY_TYPES:
			errors.append("presentation body %s has no gameplay definition" % body_name)
	if errors.is_empty():
		print("DOMAIN REGISTRY CONTRACT: PASS (%d abilities, %d regions, %d roles, %d bodies)" % [
			Attributes.ABILITY_ATTRIBUTES.size(), Regions.REGION_SPECIALTY.size(),
			Roles.POSITION_WEIGHTS.size(), Bodies.BODY_TYPES.size(),
		])
		quit(0)
		return
	for error in errors:
		push_error(error)
	print("DOMAIN REGISTRY CONTRACT: FAIL (%d errors)" % errors.size())
	quit(1)
