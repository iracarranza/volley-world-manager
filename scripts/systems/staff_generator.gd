class_name StaffGenerator
extends RefCounted

## Who is already working here when you arrive.
##
## ## The audit finding this closes
##
## `VolleyballStaffMember` has existed for a long time, is persisted, is
## incremented weekly by `advance_week`, and is read by `ScoutingSystem` — and
## **nothing ever created one.** `career.staff` started empty and stayed empty
## for the life of every save.
##
## Which meant `ScoutingSystem.scout_rating` returned `0` in every career that
## has ever been played. Every scouting reading in the game ran at the worst
## possible scout, silently, and `scout_id_for` never found anybody, so the
## per-scout belief the design is built around had exactly one view: the club's.
## That is `FAILURE_MODES` §0 in its purest form — a knob with a stated range of
## 1–100 that could only ever hold one value, and nothing anywhere said so.
##
## Meanwhile the Club tab printed four staff members with names, regions and
## sentences about what they do. None of them existed.
##
## ## Four hires, one per role, and the club decides how good they are
##
## No choice at generation, because a hiring screen is a system and this is a
## seeding: you arrive somewhere that already has a physio. What varies is
## **how good they are**, off the same two facts the roster already reads —
## whether the region is a major one and whether you founded the club or took
## over an established one.
##
## The spread within a club is deliberate and is the point of the whole staff
## layer: a club with a good scout and a poor chef is a different club from the
## reverse, and neither is better. Ratings are drawn per role so that spread
## exists from week one rather than arriving with the first hire.
const StaffMember := preload("res://scripts/models/staff_member.gd")
const Regions := preload("res://scripts/data/regions.gd")

## Where a club's staff sit before the per-role spread is applied.
##
## A major region's established club is where the good people already are; a
## founded club in a minor region is where you make do. Matched to the same
## `is_major` / `Founded` pair `create_career` already reads for funds and
## standing, rather than a third axis nobody set.
const BASE_MAJOR: int = 58
const BASE_MINOR: int = 46
const FOUNDED_PENALTY: int = 9
## How far a single hire can sit from their club's base. Wide enough that the
## club with the good scout is legible as *the club with the good scout*.
const ROLE_SPREAD: int = 22


## The four people already here.
##
## Seeded from the career's own seed so a save reloaded is the same club, and so
## two careers started in the same place with different names get different
## people.
static func for_club(
	region: String, organization_type: String, seed_value: int
) -> Array[Resource]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base := BASE_MAJOR if Regions.is_major(region) else BASE_MINOR
	if organization_type == "Founded":
		base -= FOUNDED_PENALTY
	var staff: Array[Resource] = []
	var next_id := 1
	for role in StaffMember.ROLES:
		var member: Resource = StaffMember.new()
		member.id = next_id
		next_id += 1
		member.role = str(role)
		## Staff are from somewhere, and it is not always here. A chef from the
		## region next door is the cheapest way this world says that people move
		## about — and for the chef in particular it is load-bearing, since §13
		## makes cooking somebody else's larder a real difference.
		member.home_region = _origin(region, rng)
		member.club_region = region
		member.display_name = _name_from(member.home_region, rng)
		member.rating = clampi(
			base + rng.randi_range(-ROLE_SPREAD, ROLE_SPREAD), 1, 100
		)
		staff.append(member)
	return staff


## Mostly local, sometimes from a neighbour, rarely from anywhere.
##
## Weighted rather than uniform because a club's staff being drawn evenly from
## twelve regions would say the world has no geography, which is the one thing
## `REGION_ADJACENCY` exists to deny.
static func _origin(club_region: String, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.55:
		return club_region
	var neighbours: Array = Array(Regions.REGION_ADJACENCY.get(club_region, []))
	if roll < 0.85 and not neighbours.is_empty():
		return str(neighbours[rng.randi() % neighbours.size()])
	var everywhere := Regions.names()
	return str(everywhere[rng.randi() % everywhere.size()])


## A name in that region's own tradition, from the table the roster already uses.
##
## Drawn at random rather than indexed, unlike a roster: staff are hired one at a
## time and never form a list that has to be internally distinct, so the
## coprimality `person_name` relies on buys nothing here and the seed already
## keeps a hire reproducible.
static func _name_from(region: String, rng: RandomNumberGenerator) -> String:
	var definition: Dictionary = Regions.definition(region)
	var names: Array = Array(definition.get("names", []))
	if names.is_empty():
		return "Staff"
	return Regions.person_name(region, rng.randi())
