class_name VolleyballTeam
extends Resource

const TeamPrinciplesModel := preload("res://scripts/models/team_principles.gd")

@export var id: int = 1
@export var team_name: String = "Harbor City VC"
@export var short_name: String = "HCV"
@export var identity: String = "Balanced"
@export var principles: Resource = TeamPrinciplesModel.for_identity("Balanced")
@export_range(0.0, 1.0) var tactical_familiarity: float = 0.35
## What each pair of volis knows about each other, keyed `"lowId:highId"`.
##
## The squad already had one familiarity number for the whole team and one per
## voli per slot, and nothing at all between two people -- which left the sport's
## most important relationship, a setter and a hitter who have run the same quick
## two hundred times, unrepresentable. See `PairFamiliarity`.
@export var pair_familiarity: Dictionary = {}
## Trust and emotional connection. Familiarity governs knowing the system;
## cohesion governs how strongly confidence and recovery spread through it.
@export_range(0.0, 1.0) var cohesion: float = 0.50
## How closely this team follows the volleyball tradition of its home region.
## Alignment helps a new roster gel, while departure is harder to pre-scout.
@export_range(0.0, 1.0) var regional_alignment: float = 0.50
@export var player_ids: Array[int] = []
@export var captain_id: int = -1
@export var libero_ids: Array[int] = []
@export var depth_chart: Dictionary = {}
@export var starting_player_ids: Array[int] = []
## The club's day, and the volis who keep their own.
##
## A personal schedule is a copy of the club's that somebody has changed, so the
## interesting quantity is the difference rather than the schedule -- see
## `DailyScheduleSystem.evaluate_roster`.
@export var daily_schedule: DailySchedule = DailySchedule.new()
@export var personal_schedules: Dictionary = {}
@export_range(6, 18) var roster_limit: int = 14

## What the manager drew on the clipboard. See `TacticSheet`.
##
## On the team rather than on the career because it is a property of *this
## squad*: the shape they play, who closes the line, which zone is being drilled.
## A manager who moves clubs takes their ideas and leaves the sheet.
@export var tactic_sheet: TacticSheet = TacticSheet.new()


func add_player(player_id: int) -> String:
	if player_id in player_ids:
		return "That player is already registered to the team."
	if player_ids.size() >= roster_limit:
		return "The active roster limit has been reached."
	player_ids.append(player_id)
	return ""


func remove_player(player_id: int) -> String:
	if player_id not in player_ids:
		return "That player is not registered to the team."
	player_ids.erase(player_id)
	if captain_id == player_id:
		captain_id = -1
	libero_ids.erase(player_id)
	starting_player_ids.erase(player_id)
	for role in depth_chart:
		var ordered_ids: Array = depth_chart[role]
		ordered_ids.erase(player_id)
		depth_chart[role] = ordered_ids
	return ""


func set_captain(player_id: int) -> String:
	if player_id not in player_ids:
		return "The captain must be on the active roster."
	captain_id = player_id
	return ""


func set_libero(player_id: int, enabled: bool) -> String:
	if player_id not in player_ids:
		return "A libero must be on the active roster."
	if enabled and player_id not in libero_ids:
		if libero_ids.size() >= 2:
			return "Only two liberos may be designated."
		libero_ids.append(player_id)
	elif not enabled:
		libero_ids.erase(player_id)
	return ""


func set_depth_chart(role_name: String, ordered_player_ids: Array[int]) -> String:
	for player_id in ordered_player_ids:
		if player_id not in player_ids:
			return "Every depth-chart player must be on the active roster."
	depth_chart[role_name] = ordered_player_ids.duplicate()
	return ""


func validate() -> Array[String]:
	var errors: Array[String] = []
	if player_ids.size() < 6:
		errors.append("A match roster requires at least six players.")
	if player_ids.size() > roster_limit:
		errors.append("The roster exceeds its registration limit.")
	if captain_id >= 0 and captain_id not in player_ids:
		errors.append("The captain is not registered to the team.")
	for libero_id in libero_ids:
		if libero_id not in player_ids:
			errors.append("A designated libero is not registered to the team.")
	return errors


func apply_identity(identity_name: String) -> void:
	identity = identity_name if identity_name in TeamPrinciplesModel.PRESET_NAMES else "Balanced"
	principles = TeamPrinciplesModel.for_identity(identity)


func apply_custom_identity(identity_name: String, values: Dictionary) -> void:
	principles = TeamPrinciplesModel.custom(identity_name, values)
	identity = str(principles.preset_name)


func to_dict() -> Dictionary:
	return {"id": id, "team_name": team_name, "short_name": short_name,
		"identity": identity,
		"principles": principles.to_dict() if principles != null else {},
		"tactical_familiarity": tactical_familiarity,
		"pair_familiarity": pair_familiarity.duplicate(true),
		"cohesion": cohesion,
		"regional_alignment": regional_alignment,
		"player_ids": player_ids.duplicate(), "captain_id": captain_id,
		"libero_ids": libero_ids.duplicate(), "depth_chart": depth_chart.duplicate(true),
		"starting_player_ids": starting_player_ids.duplicate(),
		"daily_schedule": daily_schedule.to_dict() if daily_schedule != null else {},
		"personal_schedules": _personal_schedule_data(),
		"roster_limit": roster_limit}


func _personal_schedule_data() -> Dictionary:
	var rows := {}
	for player_id in personal_schedules:
		var schedule: DailySchedule = personal_schedules[player_id] as DailySchedule
		if schedule != null:
			rows[str(player_id)] = schedule.to_dict()
	return rows


static func from_dict(data: Dictionary) -> VolleyballTeam:
	var team := VolleyballTeam.new()
	team.id = int(data.get("id", 1))
	team.team_name = str(data.get("team_name", "Harbor City VC"))
	team.short_name = str(data.get("short_name", "HCV"))
	team.identity = str(data.get("identity", "Balanced"))
	team.principles = TeamPrinciplesModel.from_dict(
		data.get("principles", {}), team.identity
	)
	team.identity = str(team.principles.preset_name)
	team.tactical_familiarity = clampf(float(data.get("tactical_familiarity", 0.35)), 0.0, 1.0)
	team.pair_familiarity = Dictionary(data.get("pair_familiarity", {})).duplicate(true)
	team.cohesion = clampf(float(data.get("cohesion", 0.50)), 0.0, 1.0)
	team.regional_alignment = clampf(
		float(data.get("regional_alignment", 0.50)), 0.0, 1.0
	)
	for raw_id in data.get("player_ids", []):
		team.player_ids.append(int(raw_id))
	if data.has("daily_schedule") and not Dictionary(data.daily_schedule).is_empty():
		team.daily_schedule = DailySchedule.from_dict(Dictionary(data.daily_schedule))
	for raw_key in Dictionary(data.get("personal_schedules", {})):
		team.personal_schedules[int(raw_key)] = DailySchedule.from_dict(
			Dictionary(data.personal_schedules[raw_key])
		)
	team.captain_id = int(data.get("captain_id", -1))
	for raw_id in data.get("libero_ids", []):
		team.libero_ids.append(int(raw_id))
	team.depth_chart = data.get("depth_chart", {}).duplicate(true)
	for raw_id in data.get("starting_player_ids", []): team.starting_player_ids.append(int(raw_id))
	team.roster_limit = clampi(int(data.get("roster_limit", 14)), 6, 18)
	return team
