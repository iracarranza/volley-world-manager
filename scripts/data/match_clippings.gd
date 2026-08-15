class_name MatchClippings
extends RefCounted

## What the papers said about last week.
##
## ## The contrast this exists to make
##
## The scouting board has two kinds of thing on it and they are opposites:
##
## | | a polaroid | a clipping |
## |---|---|---|
## | what it is about | a **person** you are tracking | a **thing that happened** |
## | where it came from | you put it there | it arrived |
## | what it grows into | a profile, widening with observation | nothing; it is finished the day it prints |
## | what it can mention | one voli | anybody, including strangers |
##
## That last row is the mechanic. A clipping is the only object on the board that
## can name somebody you have never heard of, which makes it the channel
## `SCOUTING.md` calls *unsolicited discovery* -- a paper reporting a
## twenty-three-kill night by a voli with no polaroid is how you find out they
## exist, and pinning them up is a decision you make from the clipping.
##
## So a clipping is deliberately *not* a summary of a match. It is the one line
## that would have been worth printing, and it is about a person wherever the
## numbers give it one.
##
## ## Everything here is derived, and it says so when it cannot be
##
## `player_statistics` has only existed on a fixture since the clippings were
## built; every fixture simulated before that has the scoreline and nothing else.
## Rather than invent a standout for those, they get the result and no name --
## which is exactly what an old cutting looks like, and is honest about the save
## rather than about the design.

const KIND_RESULT: StringName = &"result"
const KIND_PLAYER: StringName = &"player"
const KIND_ROUT: StringName = &"rout"

## What counts as worth printing.
##
## **Relative to the match, not an absolute count.** The first draft had numbers
## in it -- twelve attacks, nine serves, six blocks -- described as "measured
## against what a simulated match actually generates", and they were not
## measured, because the probe that would have measured them could not be made to
## finish. Shipping them anyway is precisely §0: a threshold outside its own
## distribution does nothing, silently, and nobody would have found out because a
## clippings strip that never fills up looks like a quiet season.
##
## So there is no absolute here to be wrong about. A standout is the top voli in
## some category *in that match*, and only when they are `OUTLIER_RATIO` clear of
## the median voli in the same match and same category. That is self-calibrating:
## if rallies get longer and every count doubles, the ratio is unchanged, and a
## match where everyone did about the same amount produces nothing at all --
## which is the behaviour the absolute version was trying to buy.
##
## The floor exists only to stop a three-touch match producing a hero out of two
## contacts against one.
const OUTLIER_RATIO: float = 1.8
const MIN_FOR_A_STORY: int = 4

## The categories a paper looks at, in the order it looks. `MatchStatistics` keys
## these off the rally event type names lower-cased, which is why they are
## `attack` and `serve` rather than `kills` and `aces` -- those are the *side*
## totals and a different table entirely.
const ANGLES := [
	{"key": "attack", "body": "Swung %d times and kept swinging."},
	{"key": "block", "body": "Up at the net %d times."},
	{"key": "dig", "body": "Dug %d balls off the floor."},
	{"key": "serve", "body": "%d trips to the line."},
]

## A win by this many sets with none dropped is a rout, which is the one thing a
## scoreline alone is allowed to be news about.
const ROUT_SETS: int = 3

## How many cuttings the board keeps. A clippings strip is not an archive: what is
## on it is what is recent, and the rest went in the bin.
const KEPT: int = 8


## Every clipping the completed fixtures are worth, newest first.
##
## `players` is the roster, used only to turn an id into a name -- so a clipping
## about somebody who has since left still prints, with the id it was filed
## under, rather than vanishing from the record because the subject moved club.
static func recent(fixtures: Array, players: Array, keep: int = KEPT) -> Array:
	var by_id := {}
	for player in players:
		by_id[int(player.id)] = player
	var completed: Array = []
	for fixture in fixtures:
		if bool(fixture.completed):
			completed.append(fixture)
	completed.sort_custom(func(a, b) -> bool: return int(a.week) > int(b.week))

	var out: Array = []
	for fixture in completed:
		for clipping in for_fixture(fixture, by_id):
			out.append(clipping)
			if out.size() >= keep:
				return out
	return out


## One fixture's worth. At most two: a match is allowed one person and one
## result, because three cuttings about one game is a scrapbook rather than a
## board.
static func for_fixture(fixture, by_id: Dictionary) -> Array:
	var out: Array = []
	var standout := _standout(fixture, by_id)
	if not standout.is_empty():
		out.append(standout)
	var result := _result(fixture)
	if not result.is_empty():
		out.append(result)
	return out


## The scoreline, and only when it is worth a headline on its own.
static func _result(fixture) -> Dictionary:
	var home := int(fixture.home_sets)
	var away := int(fixture.opponent_sets)
	var won := home > away
	var routed := won and home >= ROUT_SETS and away == 0
	if not routed:
		return {}
	return {
		"kind": KIND_ROUT,
		"week": int(fixture.week),
		"subject_id": -1,
		"headline": "%d-%d over %s" % [home, away, str(fixture.opponent_name)],
		"body": "Not a set dropped.",
	}


## The one voli worth naming, if there is one.
##
## Angles are tried in order and the first that produces an outlier wins, so a
## voli who both swung a lot and served well gets the swinging story. A paper
## picks an angle; it does not list every way somebody was good.
static func _standout(fixture, by_id: Dictionary) -> Dictionary:
	var stats: Dictionary = fixture.player_statistics
	if stats.is_empty():
		return {}
	for angle in ANGLES:
		var line := _outlier(stats, str(angle["key"]), str(angle["body"]))
		if line.is_empty():
			continue
		var subject = by_id.get(int(line["subject_id"]), null) \
			if str(line.get("side", "home")) == "home" else null
		## Named when it is one of ours, and named by *club* when it is not --
		## because a paper reporting the opposition does not have their squad list
		## either, and "a visiting voli" for every cutting is what it looked like
		## when the side was unknown rather than absent.
		## One of ours gets their name and the fixture; one of theirs gets the club
		## and nothing else. "Doblok Volei's best v Doblok Volei" is what naming
		## both halves produced, and a headline that says the same club twice reads
		## as a formatting fault rather than as a report.
		var headline := "%s's best" % str(fixture.opponent_name)
		if subject != null:
			headline = "%s v %s" % [
				str(subject.display_name), str(fixture.opponent_name)
			]
		return {
			"kind": KIND_PLAYER,
			"week": int(fixture.week),
			"subject_id": int(line["subject_id"]),
			"headline": headline,
			"body": str(line["body"]),
			## Whether the board already has a polaroid of this one is the
			## *board's* question, not the paper's -- so the clipping carries the
			## id and the screen decides whether it is a name you know.
			"known": subject != null,
		}
	return {}


## The top voli in one category, if they are clear enough of the middle of the
## same match to be worth a headline.
static func _outlier(stats: Dictionary, key: String, body: String) -> Dictionary:
	var counts: Array[int] = []
	var best := 0
	var best_id := -1
	var best_side := "home"
	for id_key in stats:
		var entry: Dictionary = stats[id_key]
		var value := int(entry.get(key, 0))
		if value <= 0:
			continue
		counts.append(value)
		if value > best:
			best = value
			best_id = int(str(id_key))
			best_side = str(entry.get("side", "home"))
	if best_id < 0 or best < MIN_FOR_A_STORY or counts.size() < 3:
		return {}
	counts.sort()
	## The median of everyone who did the thing at all, not of the whole squad --
	## a libero with no attacks is not a quiet attacker, they are not an attacker,
	## and including them as a zero would make every hitter an outlier.
	var middle := counts[counts.size() / 2]
	if float(best) < float(maxi(middle, 1)) * OUTLIER_RATIO:
		return {}
	return {"subject_id": best_id, "side": best_side, "body": body % best}
