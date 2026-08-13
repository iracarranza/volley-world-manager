class_name VolleyballFixture
extends Resource

@export var id: int = -1
@export var week: int = 1
@export var opponent_name: String = "Port Azure VC"
@export var competition_name: String = "Regional League"
@export var completed: bool = false
@export var home_sets: int = 0
@export var opponent_sets: int = 0
## What each side actually did, kept rather than discarded.
##
## `MatchStatistics` counts kills, blocks, aces and digs for both sides on every
## rally, and until this existed the whole of it was thrown away the moment the
## fixture was written -- the result kept two integers and nothing else. So a
## completed season held no record of *how* any match was won, and the lock-in
## screen's opponent panel had nothing to print: the figures a manager would
## actually want before facing someone again were computed, used once, and lost.
##
## Stored as the two side dictionaries rather than the whole model, because the
## per-player breakdown is large, changes shape as attributes move, and is
## already spent on the volis themselves through `_apply_player_match_outcomes`.
@export var home_statistics: Dictionary = {}
@export var opponent_statistics: Dictionary = {}

## Who did what, keyed by voli id.
##
## `MatchStatistics` has kept this per rally since it was written and nothing has
## ever stored it: the fixture took the two *side* totals and dropped the players
## on the floor when the match ended. So the game knew, for the length of one
## match, that somebody had a twenty-kill night, and then forgot -- which made
## every season a table of scorelines with no people in it.
##
## Kept because the scouting board's clippings are reports of things that
## happened to *somebody*, and a clipping derived from a scoreline can only ever
## say who won.
@export var player_statistics: Dictionary = {}

## Which club this fixture is actually against.
##
## `opponent_name` on its own was decoration. The three names a new career was
## given -- Port Azure VC, "<Region> Select", Northbridge Volley -- belonged to
## no region and matched no club in `VolleyballRegions.CLUB_NAMES`, and
## `prepare_fixture` never told the game manager about them, so every fixture in
## a season was played against the same default squad under whatever name the
## calendar happened to print. The lock-in board is what exposed it: it names the
## fixture at the top and the opponent's record underneath, and the two lines
## disagreed.
##
## An empty region means "an old save, or a fixture nobody targeted" and the
## opponent is left exactly as it was, so loading a career written before this
## existed behaves the way it did.
@export var opponent_region: String = ""
## Which club of that region, by index into `VolleyballRegions.CLUB_NAMES`.
## Indexed rather than drawn, because a fixture must field the same eleven
## people every time it is loaded.
@export var opponent_club_index: int = 0


func result_text() -> String:
	return "%d–%d" % [home_sets, opponent_sets] if completed else "Scheduled"


func to_dict() -> Dictionary:
	return {"id": id, "week": week, "opponent_name": opponent_name,
		"competition_name": competition_name, "completed": completed,
		"home_sets": home_sets, "opponent_sets": opponent_sets,
		"home_statistics": home_statistics.duplicate(true),
		"opponent_statistics": opponent_statistics.duplicate(true),
		"player_statistics": player_statistics.duplicate(true),
		"opponent_region": opponent_region,
		"opponent_club_index": opponent_club_index}


static func from_dict(data: Dictionary) -> VolleyballFixture:
	var fixture := VolleyballFixture.new()
	fixture.id = int(data.get("id", -1))
	fixture.week = maxi(int(data.get("week", 1)), 1)
	fixture.opponent_name = str(data.get("opponent_name", "Port Azure VC"))
	fixture.competition_name = str(data.get("competition_name", "Regional League"))
	fixture.completed = bool(data.get("completed", false))
	fixture.home_sets = int(data.get("home_sets", 0))
	fixture.opponent_sets = int(data.get("opponent_sets", 0))
	## Absent in every save written before the figures were kept, which loads as
	## a completed fixture whose detail is simply unknown rather than as a zeroed
	## one -- an empty dictionary and a dictionary of noughts read very
	## differently on a panel that prints them.
	fixture.player_statistics = Dictionary(
		data.get("player_statistics", {})
	).duplicate(true)
	fixture.home_statistics = Dictionary(data.get("home_statistics", {})).duplicate(true)
	fixture.opponent_statistics = Dictionary(
		data.get("opponent_statistics", {})
	).duplicate(true)
	fixture.opponent_region = str(data.get("opponent_region", ""))
	fixture.opponent_club_index = int(data.get("opponent_club_index", 0))
	return fixture
