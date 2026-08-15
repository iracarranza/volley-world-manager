class_name RegionalKits
extends RefCounted

## What a club from each region wears, and how the shirt is built.
##
## **Presentation data, deliberately not on `regions.gd`.** That table is what
## the world and the simulation are made of -- principles, adjacency, fatigue
## resistance, naming. A kit colour decides nothing and predicts nothing; it is
## only how a club is drawn. Keeping the two apart means a renderer can be
## rewritten without touching a file the simulator reads, and a region can gain
## a strip without a save-format question.
##
## Until this existed every club in the world wore the same two colours:
## `player_actor_3d.gd` painted the torso from `UIPalette` keyed on
## `is_home_team` alone, so a Xérvyan side and a Hitōuen side were the same teal.
## The palettes and patterns below were drawn and reviewed in
## `tools/run_venue_probe.gd`, which now reads them from here rather than
## carrying its own copy -- one table, so a kit cannot be right in a render and
## wrong in a match.

## The home strip per region.
##
## **Every one is dark, and nothing sits in the middle.** A kit is seen against a
## terracotta floor and a midtone disappears into it -- the first pass was picked
## against the interface's own background, which is the wrong ground, and cost
## nine of fourteen their contrast.
##
## Measured against the court's albedo they run from 1.85:1 (Spëddigh) to 5.61:1
## (A'ace). A midtone tan or olive scores 1.12, which is the gap the gate in
## `test_runner.gd` sits in. An earlier draft of that gate asserted 3:1 and
## failed twelve of these -- that figure belonged to the court *surface* pass and
## had never been measured against a kit.
const KITS := {
	"Landavol": Color("35393A"),
	"Spëddigh": Color("1F4E6B"),
	"Pāwa Hitō": Color("26355C"),
	"Blôc du Larg": Color("414055"),
	"Xérvu": Color("3A2415"),
	"Taktikã": Color("1E2124"),
	"Ĭspayk": Color("0C4F52"),
	"A'ace": Color("0B0F14"),
	"Tãul ys Feynt": Color("2B3A32"),
	"Lo-ong Ralī": Color("4A2030"),
	"Bompaçao": Color("5A3A1E"),
	"Rhėn Tempaol": Color("2E2C3E"),
	"Kutré Lyn": Color("16413A"),
	"Zaitgaist": Color("332B24"),
}

## The visitors' change strip.
##
## Every home kit above is dark by necessity, so the away side has to be the
## light one -- two dark teams on one terracotta floor and nobody can tell who
## touched the ball. Universal for now, by explicit direction; the eventual
## version keeps each region's *construction* in dark trim on this ground, which
## is why the pattern tables below are keyed by region and not by kit colour.
const AWAY_KIT := Color("E4E0D6")

## How each region's shirt is built, which is what survives grayscale.
##
## **Construction, not colour.** The kits cannot be told apart by hue without
## making them louder, and making them louder undoes the contrast work that got
## them readable at all. Panels, seams, bands and their spacing are value
## structure, so a side stays nameable in a black-and-white frame and at the
## distance a match is actually watched from.
##
## `trim` is how far the marks sit from the kit in value -- lighter for all of
## them, since a dark kit can only be marked by something paler.
const BUILD := {
	## The template every other kit is a deviation from. Not an absence of
	## design: a placket and a collar, cleanly made, so it reads as the canonical
	## strip rather than as one nobody finished.
	"Landavol": {"pattern": "reference", "trim": 0.34},
	## Compressed and repeated -- short marks, many of them, close together. The
	## same thing the region does to a rally.
	"Spëddigh": {"pattern": "ticks", "trim": 0.40},
	## Broad athletic panels running with the body, so the shape reads as motion
	## even standing still.
	"Pāwa Hitō": {"pattern": "panels", "trim": 0.30},
	## Vertical divisions, structural and evenly spaced: the kit is built like
	## the thing the region believes in.
	"Blôc du Larg": {"pattern": "columns", "trim": 0.36},
	## Irregular, rhythmic accents -- uneven spacing that still keeps a beat.
	"Xérvu": {"pattern": "rhythm", "trim": 0.46},
	## Precise geometric seams. Thin, exact, and nothing decorative.
	"Taktikã": {"pattern": "seams", "trim": 0.30},
	## The old strip, one broad chest band, essentially unchanged for decades.
	"Ĭspayk": {"pattern": "heritage", "trim": 0.38},
	## Immaculate and technical, and covered in the people who paid for it.
	"A'ace": {"pattern": "sponsored", "trim": 0.42},
}

## The default a region without its own construction falls back to.
##
## **Named, rather than silently borrowed.** Six minor regions have no drawn
## strip yet, and the honest state is that they wear the reference build -- not
## that they wear Landavol's. The distinction matters the day one of them gets
## its own: this constant is the list of what is still owed.
const FALLBACK_PATTERN := "reference"
const FALLBACK_TRIM := 0.34

## Where each pattern's marks sit, in torso-local metres.
##
## The chest is roughly 0.42 across and 0.5 tall, and 0.112 is just clear of the
## torso's own surface. Each entry is `[size, offset]`; the offset is mirrored to
## the back by the builder, because a kit carries its construction round the body
## and half of any frame is backs.
const MARKS := {
	"reference": [
		[Vector3(0.035, 0.34, 0.01), Vector3(0.0, 0.02, 0.115)],
		[Vector3(0.30, 0.035, 0.01), Vector3(0.0, 0.20, 0.108)],
	],
	"panels": [
		[Vector3(0.15, 0.46, 0.012), Vector3(-0.12, 0.0, 0.112)],
		[Vector3(0.15, 0.46, 0.012), Vector3(0.12, 0.0, 0.112)],
	],
	"seams": [
		[Vector3(0.34, 0.014, 0.01), Vector3(0.0, 0.12, 0.112)],
		[Vector3(0.34, 0.014, 0.01), Vector3(0.0, -0.10, 0.112)],
		[Vector3(0.014, 0.44, 0.01), Vector3(0.0, 0.0, 0.112)],
	],
	"sponsored": [
		[Vector3(0.30, 0.075, 0.012), Vector3(0.0, 0.17, 0.112)],
		[Vector3(0.12, 0.055, 0.012), Vector3(-0.10, 0.02, 0.112)],
		[Vector3(0.12, 0.055, 0.012), Vector3(0.10, 0.02, 0.112)],
		[Vector3(0.24, 0.045, 0.012), Vector3(0.0, -0.13, 0.112)],
	],
	"heritage": [
		[Vector3(0.40, 0.13, 0.013), Vector3(0.0, 0.09, 0.112)],
	],
}


## The strip a region's clubs wear, or the change strip when it has no region.
static func kit_for(region: String) -> Color:
	return Color(KITS.get(region, AWAY_KIT))


static func has_kit(region: String) -> bool:
	return KITS.has(region)


static func away_kit() -> Color:
	return AWAY_KIT


static func pattern_for(region: String) -> String:
	return str(Dictionary(BUILD.get(region, {})).get("pattern", FALLBACK_PATTERN))


static func trim_for(region: String) -> float:
	return float(Dictionary(BUILD.get(region, {})).get("trim", FALLBACK_TRIM))


## The colour the marks are made in: the kit, lifted.
static func trim_colour(region: String) -> Color:
	return kit_for(region).lightened(trim_for(region))


## Every mark on this region's shirt, front and back, as `[size, offset]` pairs.
##
## The two repeating patterns are generated rather than listed, because their
## whole character is a count and a spacing -- writing out eight tick positions
## invites one of them being edited and the rhythm quietly breaking.
static func marks_for(region: String) -> Array:
	var pattern := pattern_for(region)
	var front: Array = []
	match pattern:
		"ticks":
			for row in range(4):
				for col in [-1.0, 1.0]:
					front.append([
						Vector3(0.10, 0.026, 0.01),
						Vector3(col * 0.10, 0.16 - float(row) * 0.085, 0.112),
					])
		"columns":
			for col in range(3):
				front.append([
					Vector3(0.045, 0.50, 0.011),
					Vector3(-0.13 + float(col) * 0.13, 0.0, 0.112),
				])
		"rhythm":
			## Uneven gaps that still keep a beat. Listed as intervals rather than
			## as positions so the unevenness is the thing being stated.
			var beat := [0.20, 0.09, 0.15, 0.05, 0.13]
			var y := 0.22
			for i in range(beat.size()):
				front.append([Vector3(0.26, 0.03, 0.011), Vector3(0.0, y, 0.112)])
				y -= float(beat[i])
		_:
			front = Array(MARKS.get(pattern, MARKS[FALLBACK_PATTERN]))
	var both: Array = []
	for mark in front:
		var size: Vector3 = mark[0]
		var at: Vector3 = mark[1]
		for face in [1.0, -1.0]:
			both.append([size, Vector3(at.x * face, at.y, at.z * face)])
	return both


## One region for a whole side, from the players standing in it.
##
## **A kit belongs to a club, not to a body.** Reading `club_region` per player
## and painting each one from it would dress a roster whose data has drifted --
## a transfer half-applied, a generated squad with one unassigned voli -- in
## twelve different shirts, which is worse than the single wrong colour it
## replaced. The mode is immune to that: one outlier cannot split a team.
static func side_region(players: Array) -> String:
	var counts := {}
	var best := ""
	var best_count := 0
	for entry in players:
		if entry == null:
			continue
		var region := str(entry.club_region)
		if region.is_empty():
			continue
		counts[region] = int(counts.get(region, 0)) + 1
		if int(counts[region]) > best_count:
			best_count = int(counts[region])
			best = region
	return best
