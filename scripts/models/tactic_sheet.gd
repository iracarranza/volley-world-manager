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

## Where the manager has dropped each voli, by roster slot, in court coordinates.
##
## Keyed by slot rather than by player id on purpose: a plan is a shape the club
## plays, and it outlives the particular voli standing in position four. Signing
## a new outside hitter should not silently empty half the sheet.
@export var placements: Dictionary = {}

## What each voli has been told to do, keyed `"slot:phase"`.
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
