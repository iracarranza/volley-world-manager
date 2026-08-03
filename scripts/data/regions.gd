class_name VolleyballRegions
extends RefCounted

const TeamPrinciplesModel := preload("res://scripts/models/team_principles.gd")

const DEFINITIONS := {
	"Landavol": {"tagline": "No dominant tradition -- clubs here develop players broadly rather than toward one specialty.",
		"physical": 2, "technical": 2, "mental": 2, "names": ["Mila", "Luka", "Nora", "Ivo", "Toma", "Elin", "Sven", "Kaja"]},
	"Spëddigh": {"tagline": "Compact community gyms prize relentless work, tempo pressure and rapid transitions.",
		"physical": 2, "technical": 3, "mental": 2, "names": ["Edda", "Siv", "Nils", "Veya", "Tekk", "Orri", "Fenn", "Lïv"]},
	"Pāwa Hitō": {"tagline": "Conditioning halls build relentless transition attackers who can strike at full quality deep into a rally.",
		"physical": 4, "technical": 1, "mental": 1, "names": ["Aki", "Hana", "Ren", "Sora", "Yuna", "Kai", "Mio", "Taro"]},
	"Bloc du Larg": {"tagline": "Methodical halls teach net control, court reading and patient structure.",
		"physical": 2, "technical": 2, "mental": 3, "names": ["Luc", "Mire", "Noé", "Ciel", "Aude", "Remy", "Léon", "Véra"]},
	"Xérvu": {"tagline": "Serving academies drill relentless toss discipline, spin variation and first-strike aggression.",
		"physical": 2, "technical": 4, "mental": 1, "names": ["Kofi", "Amara", "Zola", "Kwame", "Aziza", "Tendai", "Njeri", "Baraka"]},
	"Taktikã": {"tagline": "Tactical schools reward composed intelligence, adaptable systems and execution insulated from emotion.",
		"physical": 1, "technical": 1, "mental": 4, "names": ["Inti", "Aylen", "Kuyen", "Amaru", "Wayra", "Nayra", "Chaska", "Illari"]},
	"Ispayk": {"tagline": "Once a Sixnet flagship, now a proud, cash-strapped program clawing back toward relevance -- birthplace of the set-and-spike, where large-framed bomberinos still end rallies with the crushing bomba.",
		"physical": 4, "technical": 2, "mental": 1, "names": ["Kiko", "Mika", "Jun", "Rico", "Bea", "Nico", "Liza", "Ana"]},
	"A'ace": {"tagline": "The circuit's newest flagship-in-waiting, buying in overnight the star talent a young program hasn't had time to grow -- all the resources, none of the history.",
		"physical": 3, "technical": 2, "mental": 1, "names": ["Omar", "Layla", "Yusuf", "Amal", "Faisal", "Noor", "Rashid", "Huda"]},

	## Minor regions. Small programs that never contest the Sixnet, with
	## ratings summing to 4-5 against the majors' 6-8 and a specialty of two or
	## three attributes rather than four to six. Weak overall, sharply
	## specialized -- a player from one grades poorly by
	## `current_ability_score()` while sitting near the top of the world on the
	## two or three things their tradition actually teaches.
	##
	## Names follow the same device as the majors (see
	## `docs/world/STYLE_AND_SETTING.md`): a volleyball phrase reworded oddly
	## and dressed in unfamiliar spelling -- Tu'ul ys Feynt is "tools and
	## feints", Rhen Tempaol is "one tempo", Longh Ralhi is "long rally".
	"Tu'ul ys Feynt": {"tagline": "Village halls where the ball is won by the shot the blocker didn't believe -- wrists over power, patience over height.",
		"physical": 1, "technical": 3, "mental": 1, "names": ["Bryn", "Eilir", "Tewdr", "Anwen", "Maelo", "Ffion", "Gwern", "Rhosyn"]},
	"Longh Ralhi": {"tagline": "Thin-air gyms three days' travel from anywhere. Rallies here end when someone's legs go, and nobody's legs go.",
		"physical": 2, "technical": 1, "mental": 2, "names": ["Dorje", "Pema", "Tenzin", "Tsering", "Norbu", "Lhamo", "Kunzang", "Yangchen"]},
	"Bhomp Passau": {"tagline": "Concrete courts, no net posts worth the name, and a religion built around the first contact. If it's passable, it gets passed.",
		"physical": 1, "technical": 3, "mental": 1, "names": ["Nilo", "Yaritza", "Elpidio", "Marisol", "Ozéias", "Caridad", "Tavo", "Idalia"]},
	"Rhen Tempaol": {"tagline": "Small halls where the set is already gone before the block has finished landing. Nobody here hits hard. Everybody here hits early.",
		"physical": 2, "technical": 2, "mental": 1, "names": ["Soah", "Minjae", "Haerin", "Wonsik", "Yerin", "Doha", "Jiwoo", "Seong"]},
	"Kutt Lyne": {"tagline": "Technical schools that treat a hard swing as an admission of failure. The corner is always open if you can see it.",
		"physical": 1, "technical": 3, "mental": 1, "names": ["Zorana", "Miloš", "Vesna", "Ilija", "Radmila", "Novak", "Danica", "Stevan"]},
	## The one region whose name is not a volleyball phrase, because it is the
	## one region with no technique of its own to name itself after. It borrows
	## whatever just won instead -- see `SixnetLeague`'s zeitgeist rule.
	"Zaitgaist": {"tagline": "A city-state you could walk across in a morning, landlocked inside Landavol, which has never developed a style and has played every style there is.",
		"physical": 1, "technical": 1, "mental": 2, "names": ["Anselm", "Reike", "Vasholt", "Merrin", "Ottlin", "Sabet", "Frauke", "Delvin"]},
}

const LEGACY_REGIONS := {
	"East Asia": "Pāwa Hitō", "Southeast Asia": "Ispayk",
	"Europe": "Landavol", "North America": "Pāwa Hitō",
	"South America": "Taktikã",
}

## The six regions with their own development identity -- REGION_ADJACENCY
## and influence drift are scoped to exactly this list. Ispayk and A'ace are
## deliberately excluded from *that* system (they don't have a development
## tradition to spread or absorb; their identity comes from history and
## money, not geography), even though both now play in the Sixnet bracket
## itself -- see `SIXNET_PARTICIPANTS`.
const CORE_REGIONS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Bloc du Larg", "Xérvu", "Taktikã",
]

## Every region that actually competes in the Sixnet's 8 bracket slots.
## Ispayk and A'ace hold a fixed starting slot each (see
## `SixnetLeague.ISPAYK_FIXED_SLOT`/`AACE_FIXED_SLOT`) -- lower for Ispayk
## (fallen flagship, clawing back), upper for A'ace (bought its way straight
## to the top) -- but afterward are subject to the same promotion/relegation
## as everyone else; "always starts" is a starting condition, not a
## permanent pin. The remaining 6 slots go to `CORE_REGIONS`, one each.
const SIXNET_PARTICIPANTS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Bloc du Larg", "Xérvu", "Taktikã",
	"Ispayk", "A'ace",
]

## The style a region's players grow up reading every week. New managers may
## reject any part of it, but a larger departure takes longer for the inherited
## roster to trust and execute together.
const REGIONAL_PRINCIPLES := {
	"Landavol": {
		"decisiveness": 0.50, "pin_focus": 0.50, "tempo_variation": 0.50,
		"emotional_expression": 0.50, "serve_aggression": 0.50,
		"transition_commitment": 0.50, "block_commitment": 0.50,
	},
	"Spëddigh": {
		"decisiveness": 0.68, "pin_focus": 0.42, "tempo_variation": 0.85,
		"emotional_expression": 0.65, "serve_aggression": 0.58,
		"transition_commitment": 0.90, "block_commitment": 0.55,
	},
	"Pāwa Hitō": {
		"decisiveness": 0.72, "pin_focus": 0.62, "tempo_variation": 0.50,
		"emotional_expression": 0.65, "serve_aggression": 0.55,
		"transition_commitment": 0.88, "block_commitment": 0.55,
	},
	"Bloc du Larg": {
		"decisiveness": 0.26, "pin_focus": 0.32, "tempo_variation": 0.30,
		"emotional_expression": 0.22, "serve_aggression": 0.30,
		"transition_commitment": 0.35, "block_commitment": 0.72,
	},
	"Xérvu": {
		"decisiveness": 0.68, "pin_focus": 0.50, "tempo_variation": 0.72,
		"emotional_expression": 0.58, "serve_aggression": 0.92,
		"transition_commitment": 0.60, "block_commitment": 0.45,
	},
	"Taktikã": {
		"decisiveness": 0.48, "pin_focus": 0.40, "tempo_variation": 0.58,
		"emotional_expression": 0.12, "serve_aggression": 0.45,
		"transition_commitment": 0.50, "block_commitment": 0.52,
	},
	"Ispayk": {
		"decisiveness": 0.90, "pin_focus": 0.88, "tempo_variation": 0.28,
		"emotional_expression": 0.78, "serve_aggression": 0.72,
		"transition_commitment": 0.62, "block_commitment": 0.78,
	},
	"A'ace": {
		"decisiveness": 0.75, "pin_focus": 0.65, "tempo_variation": 0.65,
		"emotional_expression": 0.70, "serve_aggression": 0.70,
		"transition_commitment": 0.70, "block_commitment": 0.65,
	},
}

## Invented flavor geography for the influence-drift mechanic -- which core
## regions are close enough to plausibly absorb (or resist) each other's
## development traditions. Not tied to each region's real-world naming
## culture (see `docs/world/STYLE_AND_SETTING.md`); this is a made-up world
## map, symmetric by construction (every entry appears on both sides).
const REGION_ADJACENCY := {
	"Landavol": ["Bloc du Larg", "Spëddigh", "Zaitgaist"],
	"Spëddigh": ["Landavol", "Taktikã", "Rhen Tempaol"],
	"Pāwa Hitō": ["Xérvu", "Longh Ralhi"],
	"Bloc du Larg": ["Landavol", "Xérvu", "Bhomp Passau"],
	"Xérvu": ["Bloc du Larg", "Pāwa Hitō", "Taktikã", "Kutt Lyne"],
	"Taktikã": ["Spëddigh", "Xérvu", "Tu'ul ys Feynt"],
	"Tu'ul ys Feynt": ["Taktikã"],
	"Longh Ralhi": ["Pāwa Hitō"],
	"Bhomp Passau": ["Bloc du Larg"],
	"Rhen Tempaol": ["Spëddigh"],
	"Kutt Lyne": ["Xérvu"],
	## Geography only. Zaitgaist is genuinely an enclave inside Landavol, but
	## drift skips it before the adjacency branches ever run -- it tracks the
	## Sixnet champion instead of its neighbor. Reading this table alone would
	## wrongly suggest Landavol influences it.
	"Zaitgaist": ["Landavol"],
}

## Minor regions: present in the world, absent from the Sixnet. Every loop that
## means "regions with a development tradition" iterates DEVELOPMENT_REGIONS;
## every loop that means "regions in the bracket" keeps using
## SIXNET_PARTICIPANTS, which is why adding these needs no league changes.
const MINOR_REGIONS: Array[String] = [
	"Tu'ul ys Feynt", "Longh Ralhi", "Bhomp Passau", "Rhen Tempaol",
	"Kutt Lyne", "Zaitgaist",
]

## Influence drift covers core plus minor. Ispayk and A'ace stay out: their
## identities come from history and money rather than a local training
## tradition that could spread or be absorbed.
const DEVELOPMENT_REGIONS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Bloc du Larg", "Xérvu", "Taktikã",
	"Tu'ul ys Feynt", "Longh Ralhi", "Bhomp Passau", "Rhen Tempaol",
	"Kutt Lyne", "Zaitgaist",
]

## Every region that raises and hosts players -- the eight Sixnet
## participants plus the minor tier. This is the population scope, and it is
## deliberately *not* SIXNET_PARTICIPANTS: minor regions are inhabited places
## that produce, keep and lose players, they simply never contest the bracket.
## Conflating the two is how the tier ends up existing in data and nowhere in
## the actual world.
const INHABITED_REGIONS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Bloc du Larg", "Xérvu", "Taktikã",
	"Ispayk", "A'ace",
	"Tu'ul ys Feynt", "Longh Ralhi", "Bhomp Passau", "Rhen Tempaol",
	"Kutt Lyne", "Zaitgaist",
]

## How much harder than usual it is to absorb a region's tradition, as a
## multiplier on `DOMINANCE_THRESHOLD`.
##
## Minor regions are by design far weaker than any major neighbor, so without
## this the strength gap would always clear the threshold: they would blend
## every single season, never intensify, and lose the specialization that is
## the entire reason the tier exists. Resistance makes absorption a slow risk
## rather than a certainty -- a small tradition can still die, which is a
## better story than one that cannot.
##
## The spread is deliberate. Longh Ralhi is an isolated mountain tradition and
## the hardest to reach; Kutt Lyne is well-connected inland and could plausibly
## be swallowed outright; Zaitgaist has nothing to resist with, which is the
## point of it. Regions absent here resist normally.
const REGION_TRADITION_RESISTANCE := {
	"Longh Ralhi": 1.4,
	"Tu'ul ys Feynt": 1.0,
	"Rhen Tempaol": 0.9,
	"Bhomp Passau": 0.8,
	"Kutt Lyne": 0.7,
	"Zaitgaist": 0.0,
}


static func tradition_resistance(region_name: String) -> float:
	return float(REGION_TRADITION_RESISTANCE.get(canonical_name(region_name), 0.0))


## Regions a new career can be founded in.
##
## Deliberately not every region in `DEFINITIONS`. Minor regions exist in the
## world, raise players and appear in scouting, but they run no academy at the
## level this game is about -- founding a Zaitgaist academy and competing
## toward the Sixnet is not a story the tier supports. They are places you sign
## players *from*, not places you manage.
static func playable_names() -> Array[String]:
	var result: Array[String] = SIXNET_PARTICIPANTS.duplicate()
	result.sort()
	return result


static func names() -> Array[String]:
	var result: Array[String] = []
	for region_name in DEFINITIONS:
		result.append(str(region_name))
	result.sort()
	return result


static func canonical_name(region_name: String) -> String:
	return str(LEGACY_REGIONS.get(region_name, region_name)) \
		if region_name in DEFINITIONS or region_name in LEGACY_REGIONS else "Landavol"


static func definition(region_name: String) -> Dictionary:
	var resolved_name := canonical_name(region_name)
	return Dictionary(DEFINITIONS.get(resolved_name, DEFINITIONS["Landavol"])).duplicate(true)


static func preferred_principles(region_name: String) -> TeamPrinciples:
	var resolved_name := canonical_name(region_name)
	return TeamPrinciplesModel.custom(
		"%s Tradition" % resolved_name,
		Dictionary(REGIONAL_PRINCIPLES.get(
			resolved_name, REGIONAL_PRINCIPLES.Landavol
		)),
	)


static func starting_identity_state(
	region_name: String,
	principles: TeamPrinciples,
) -> Dictionary:
	var regional := preferred_principles(region_name)
	var distance := principles.alignment_distance(regional) if principles != null else 0.0
	return {
		"alignment": 1.0 - distance,
		"familiarity": clampf(0.52 - distance * 0.34, 0.18, 0.52),
		"cohesion": clampf(0.60 - distance * 0.25, 0.35, 0.60),
	}
