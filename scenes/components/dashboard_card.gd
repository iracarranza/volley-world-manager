class_name VolleyballDashboardCard
extends Button

signal section_requested(section_id: String)

@export var section_id: String = ""
@export var title_text: String = "Section"
@export_multiline var summary_text: String = "Open this management section."
@export var icon_text: String = "•"

@onready var icon_label: Label = %IconLabel
@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel


func _ready() -> void:
	pressed.connect(func() -> void: section_requested.emit(section_id))
	_apply_content()


## `configure()` was the card's original setup entry point, superseded by the
## per-field setters the dashboard actually calls. Uncalled.


func set_summary(summary: String) -> void:
	summary_text = summary
	tooltip_text = summary
	if is_node_ready():
		_apply_content()


func _apply_content() -> void:
	icon_label.text = icon_text
	title_label.text = title_text
	summary_label.text = summary_text
