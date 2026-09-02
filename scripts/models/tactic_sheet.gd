class_name TacticSheet
extends Resource

## What the manager drew on the clipboard, kept.
##
## Nothing on the tactic sheet survived the screen. Placements, the priorities on
## the net zones, the drill the manager circled and -- most recently -- the
## per-voli instruction for each phase were all held on `UIWorksheet`, which is a
## `Control`: it is built when the clipboard opens and its state is gone the
## moment the page is rebuilt, let alone when the game is saved and reloaded.
##
## That is worse than an inconvenience. A plan nobody can keep is a plan nothing
## downstream can *read*, so the drill session has nothing to run and the rally
## has nothing to run *from* -- and the whole point of telling a voli to close
## the line is that they then close the line. This is the thing in between.
##
## Deliberately plain data. It holds what was drawn and knows nothing about how
## it is drawn or what consumes it, so the clipboard can change its mind about
## presentation without a save migration and a consumer can arrive later.

## Where the manager has dropped each voli, by roster-tray slot, in court
## coordinates.  Each row also carries `who: v<player id>`; the tray index is an
## editor address while `who` is the gameplay identity.  A rotation slot is a
## third, unrelated namespace and must never be used as the tray key.
@export var placements: Dictionary = {}

## What each tray row has been told to do, keyed `"tray-slot:phase"`.  Rally
## consumers resolve that row through the placement's `who` identity.
##
## Both parts of the key are load-bearing. The same voli closes the line when
## blocking and digs cross when the ball comes down, so one instruction per voli
## would have the second overwrite the first.
@export var behaviours: Dictionary = {}

## How hard the club defends each net zone, in the sheet's own order:
## line, seam, cross, tip.
@export var zone_priorities: Array[int] = [3, 2, 1, 2]

## The zone the manager circled to drill.
@export var drill_zone: int = 2

## Which page the clipboard was left on, so it opens where it was closed.
@export var phase: String = "Block"
@export var view: String = "Three quarter"


## Everything the sheet was holding, read off a worksheet.
static func from_worksheet(worksheet: Control) -> TacticSheet:
	var sheet := TacticSheet.new()
	if worksheet == null:
		return sheet
	sheet.placements = Dictionary(worksheet.placements).duplicate(true)
	sheet.behaviours = Dictionary(worksheet.behaviours).duplicate(true)
	sheet.zone_priorities = Array(worksheet.zone_priorities).duplicate()
	sheet.drill_zone = int(worksheet.drill_zone)
	sheet.phase = str(worksheet.phase)
	sheet.view = str(worksheet.view)
	return sheet


## Put it back on a worksheet.
##
## Assigns the fields directly rather than going through `place_voli_at`,
## because the refusals that function enforces -- the net zone, the clearance
## between two volis -- are rules about *making* a placement, and a plan that was
## already accepted should not be re-litigated when it is reopened. A rule that
## changes later is a migration, not a silent deletion of somebody's work.
func apply_to(worksheet: Control) -> void:
	if worksheet == null:
		return
	worksheet.placements = placements.duplicate(true)
	worksheet.behaviours = behaviours.duplicate(true)
	worksheet.zone_priorities = _typed_priorities()
	worksheet.drill_zone = drill_zone
	worksheet.set_phase(phase)
	worksheet.set_view(view)


## What this voli has been told to do in this phase, or "" for nothing.
##
## The reader's half of the sheet, here rather than on the worksheet so a drill
## session or a rally can ask without instantiating a `Control`.
func behaviour_of(slot: int, for_phase: String) -> String:
	return str(behaviours.get("%d:%s" % [slot, for_phase], ""))


## Resolve a tray-authored instruction by the player identity stored alongside
## the placement.  Clipboard slots are roster-tray indices, not rotation slots;
## treating them as interchangeable sends a call to a different player as soon
## as the lineup rotates.  The legacy slot fallback keeps early saves readable.
func behaviour_for_player(
	player_id: int, for_phase: String, legacy_rotation_slot: int = -1
) -> String:
	var player_key := "v%d" % player_id
	for raw_slot in placements:
		var placement: Dictionary = placements[raw_slot] as Dictionary
		if str(placement.get("who", "")) == player_key:
			return behaviour_of(int(raw_slot), for_phase)
	if legacy_rotation_slot >= 0:
		return behaviour_of(legacy_rotation_slot, for_phase)
	return ""


## The authored court point for a player, still in worksheet metres.  Returning
## a tagged dictionary distinguishes an absent mark from the valid centre point.
func placement_for_player(player_id: int) -> Dictionary:
	var player_key := "v%d" % player_id
	for raw_slot in placements:
		var placement: Dictionary = placements[raw_slot] as Dictionary
		if str(placement.get("who", "")) == player_key:
			return {
				"authored": true,
				"tray_slot": int(raw_slot),
				"meters": Vector2(placement.get("at", Vector2.ZERO)),
			}
	return {"authored": false}


func to_dict() -> Dictionary:
	var placement_data := {}
	for raw_slot in placements:
		var placement: Dictionary = placements[raw_slot] as Dictionary
		var at := Vector2(placement.get("at", Vector2.ZERO))
		placement_data[str(int(raw_slot))] = {
			"at": [at.x, at.y],
			"who": str(placement.get("who", "")),
		}
	return {
		"placements": placement_data,
		"behaviours": behaviours.duplicate(true),
		"zone_priorities": Array(zone_priorities).duplicate(),
		"drill_zone": drill_zone,
		"phase": phase,
		"view": view,
	}


static func from_dict(data: Dictionary) -> TacticSheet:
	var sheet := TacticSheet.new()
	sheet.placements.clear()
	for raw_slot in Dictionary(data.get("placements", {})):
		var saved: Dictionary = Dictionary(data.placements[raw_slot])
		var coordinates: Array = Array(saved.get("at", [0.0, 0.0]))
		if coordinates.size() >= 2:
			sheet.placements[int(raw_slot)] = {
				"at": Vector2(float(coordinates[0]), float(coordinates[1])),
				"who": str(saved.get("who", "")),
			}
	sheet.behaviours = Dictionary(data.get("behaviours", {})).duplicate(true)
	sheet.zone_priorities.clear()
	for value in Array(data.get("zone_priorities", [3, 2, 1, 2])):
		sheet.zone_priorities.append(clampi(int(value), 0, 3))
	while sheet.zone_priorities.size() < 4:
		sheet.zone_priorities.append(0)
	sheet.zone_priorities.resize(4)
	sheet.drill_zone = clampi(int(data.get("drill_zone", 2)), 0, 3)
	sheet.phase = str(data.get("phase", "Block"))
	sheet.view = str(data.get("view", "Three quarter"))
	return sheet


## Every instruction for one phase, as slot -> behaviour.
func behaviours_for(for_phase: String) -> Dictionary:
	var found := {}
	var suffix := ":%s" % for_phase
	for raw_key in behaviours:
		var key := str(raw_key)
		if key.ends_with(suffix):
			found[int(key.split(":")[0])] = str(behaviours[raw_key])
	return found


## How much of the sheet the manager has actually filled in.
##
## The number a drill session wants: a club that has told nobody anything has no
## plan to rehearse, and should be told that rather than shown an empty list.
func instruction_count() -> int:
	return behaviours.size()


func _typed_priorities() -> Array[int]:
	var typed: Array[int] = []
	for value in zone_priorities:
		typed.append(int(value))
	return typed
