class_name VolleyballNewCareerScreen
extends Control

signal career_created
signal back_requested

@onready var career_name_edit: LineEdit = %CareerNameEdit
@onready var organization_name_edit: LineEdit = %OrganizationNameEdit
@onready var region_option: OptionButton = %RegionOption
@onready var organization_type_option: OptionButton = %OrganizationTypeOption
@onready var identity_option: OptionButton = %IdentityOption
@onready var setup_description: Label = %SetupDescription
@onready var error_label: Label = %ErrorLabel


func _ready() -> void:
	for region_name in VolleyballRegions.names():
		region_option.add_item(region_name)
	for type_name in ["Club", "Academy"]:
		organization_type_option.add_item(type_name)
	for identity_name in ["Balanced", "Technical", "Physical", "Defensive", "Fast Tempo", "Development"]:
		identity_option.add_item(identity_name)
	region_option.item_selected.connect(_refresh_description)
	organization_type_option.item_selected.connect(_refresh_description)
	identity_option.item_selected.connect(_refresh_description)
	%CreateCareerButton.pressed.connect(_create_career)
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	_refresh_description()


func reset_form() -> void:
	error_label.text = ""
	_refresh_description()


func _refresh_description(_index: int = -1) -> void:
	var region_name := region_option.get_item_text(region_option.selected)
	var organization_type := organization_type_option.get_item_text(
		organization_type_option.selected
	)
	var region := VolleyballRegions.definition(region_name)
	var type_text := "Enter senior competition immediately with a ten-player roster, larger budget and transfer focus." \
		if organization_type == "Club" else \
		"Develop a twelve-player youth roster with higher potential, smaller budget and stronger long-term emphasis."
	setup_description.text = "%s\n\n%s\n\nStarting matches use best-of-three sets, with every set played to 25 by two." % [
		region.tagline, type_text]


func _create_career() -> void:
	var error := CareerManager.create_career(
		career_name_edit.text, organization_name_edit.text,
		region_option.get_item_text(region_option.selected),
		organization_type_option.get_item_text(organization_type_option.selected),
		identity_option.get_item_text(identity_option.selected),
	)
	error_label.text = error
	if error.is_empty():
		career_created.emit()
