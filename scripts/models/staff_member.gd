class_name VolleyballStaffMember
extends Resource

## Somebody you hired, who owns exactly one resource.
##
## `CLUB_LIFE.md` sets the rule the roles follow: four of them, each owning one
## thing, which is what stops the staff list being four hires in a row with
## interchangeable numbers. Two make volis better and two keep them knowable and
## available.
##
##   Assistant Coach  training throughput
##   Scout            information confidence
##   Chef             morale and nourishment
##   Physio           condition and fatigue recovery
##
## Only the scout is wired to anything yet, deliberately. It is the one whose
## resource is also a *foundation* -- hidden potential, unreliable self-report,
## thought bubbles and scout reports are all one mechanism -- so building it
## first means the other three inherit it rather than each inventing a private
## version, which is the failure `CLUB_LIFE.md` section 5 warns about by name.

const Regions := preload("res://scripts/data/regions.gd")

const ROLE_ASSISTANT_COACH := "Assistant Coach"
const ROLE_SCOUT := "Scout"
const ROLE_CHEF := "Chef"
const ROLE_PHYSIO := "Physio"

const ROLES: Array[String] = [
	ROLE_ASSISTANT_COACH, ROLE_SCOUT, ROLE_CHEF, ROLE_PHYSIO,
]

## What each role owns, for anything that wants to explain itself to the player
## without a second table somewhere else saying something slightly different.
const ROLE_RESOURCE := {
	ROLE_ASSISTANT_COACH: "training throughput",
	ROLE_SCOUT: "information confidence",
	ROLE_CHEF: "morale and nourishment",
	ROLE_PHYSIO: "condition and fatigue recovery",
}

@export var id: int = -1
@export var display_name: String = "Staff"
@export_enum("Assistant Coach", "Scout", "Chef", "Physio") var role: String = ROLE_SCOUT

## Where they are from and where they are now, the same pair a voli carries.
## Origin is not decoration for every role: a chef cooks their own region's
## cuisine better, and distance from the club sets import cost.
@export var home_region: String = "Landavol"
@export var club_region: String = "Landavol"

## How good they are at the one thing they own. Deliberately a single number:
## a staff member with a spread of attributes is a player, and the design wants
## the interesting variation to be in *which resource is scarce*, not in reading
## six bars per hire.
@export_range(1, 100) var rating: int = 50

## Weeks employed. Not yet spent by anything; carried because every system that
## will read this staff member -- a chef's palate memory, a physio's history
## with a body -- needs tenure and inventing it separately later is how one fact
## ends up with two sources.
@export var weeks_employed: int = 0


func resource_owned() -> String:
	return str(ROLE_RESOURCE.get(role, ""))


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "role": role,
		"home_region": home_region, "club_region": club_region,
		"rating": rating, "weeks_employed": weeks_employed,
	}


static func from_dict(data: Dictionary) -> VolleyballStaffMember:
	var staff := VolleyballStaffMember.new()
	staff.id = int(data.get("id", -1))
	staff.display_name = str(data.get("display_name", "Staff"))
	staff.role = str(data.get("role", ROLE_SCOUT))
	staff.home_region = str(data.get("home_region", "Landavol"))
	staff.club_region = str(data.get("club_region", staff.home_region))
	staff.rating = clampi(int(data.get("rating", 50)), 1, 100)
	staff.weeks_employed = int(data.get("weeks_employed", 0))
	return staff
