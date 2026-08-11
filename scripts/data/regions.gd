class_name VolleyballRegions
extends RefCounted

const TeamPrinciplesModel := preload("res://scripts/models/team_principles.gd")

const DEFINITIONS := {
	## Taglines name their own people, so each one contains a demonym that is
	## still being settled -- these do not currently match `DEMONYMS` below, and
	## the two need a sweep once the words are chosen.
	"Landavol": {"tagline": "Landavoli training is intentionally broad, allowing their volis to specialize into anything -- or everything, if they want.",
		"physical": 2, "technical": 2, "mental": 2, "names": ["Mila", "Luka", "Nora", "Ivo", "Toma", "Elin", "Sven", "Kaja"]},
	"Spëddigh": {"tagline": "The close-knit and compact Spëddich give rise to quick transition attackers who push every play to be faster and tighter.",
		"physical": 2, "technical": 3, "mental": 2, "names": ["Edda", "Siv", "Nils", "Veya", "Tekk", "Orri", "Fenn", "Lïv"]},
	"Pāwa Hitō": {"tagline": "Conditioning halls mold the Hitōue into relentless attackers -- nightmarish power and quality deep into a rally.",
		"physical": 4, "technical": 1, "mental": 1, "names": ["Aki", "Hana", "Ren", "Sora", "Yuna", "Kai", "Mio", "Taro"]},
	"Bloc du Larg": {"tagline": "Larçgan culture prizes methodical court reading, perfecting its structure at the net above all else to keep complete control.",
		"physical": 2, "technical": 2, "mental": 3, "names": ["Luc", "Mire", "Noé", "Ciel", "Aude", "Remy", "Léon", "Véra"]},
	"Xérvu": {"tagline": "Ancient and new rhythms reverberate through Xérvyan courts -- a combination of individualism and deep respect for routine creates devastating, unpredictable serves.",
		"physical": 2, "technical": 4, "mental": 1, "names": ["Kofi", "Amara", "Zola", "Kwame", "Aziza", "Tendai", "Njeri", "Baraka"]},
	"Taktikã": {"tagline": "Taktikiãn volleyball demands cerebral players who strip the game down to its roots; emotion has no place in finding the optimal path.",
		"physical": 1, "technical": 1, "mental": 4, "names": ["Inti", "Aylen", "Kuyen", "Amaru", "Wayra", "Nayra", "Chaska", "Illari"]},
	"Ispayk": {"tagline": "The cradle of the set-and-spike has lost its relevance to the modernization of the sport, but veteran and new Ispakyanos alike keep perfecting the bomberino's crushing bomba.",
		"physical": 4, "technical": 2, "mental": 1, "names": ["Kiko", "Mika", "Jun", "Rico", "Bea", "Nico", "Liza", "Ana"]},
	"A'ace": {"tagline": "A'ace'ni volleyball may as well have been born yesterday, but the power of program funding defies history. The world's premier volis dictate their tactics season to season.",
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
	## feints", Rhen Tempaol is "one tempo", Lo-onğ Ralī is "long rally",
	## Bompaşao is "bump pass", and Kutré Lyn is "cut and line".
	##
	## A minor region shares its major neighbour's *spelling*, which is what
	## makes them read as one written language rather than two names drawn from
	## different hats. Kutré Lyn was "Kutre den Lyn" and carried Bloc du Larg's
	## connector ("den" for "du") while sitting next to Xérvu, so it announced
	## kinship with the wrong region; it now takes Xérvu's acute instead. Old
	## saves resolve through `LEGACY_REGIONS`.
	"Tu'ul ys Feynt": {"tagline": "Village halls where the ball is won by the shot the blocker didn't believe -- wrists over power, patience over height.",
		"physical": 1, "technical": 3, "mental": 1, "names": ["Bryn", "Eilir", "Tewdr", "Anwen", "Maelo", "Ffion", "Gwern", "Rhosyn"]},
	"Lo-onğ Ralī": {"tagline": "Thin-air gyms three days' travel from anywhere. Rallies here end when someone's legs go, and nobody's legs go.",
		"physical": 2, "technical": 1, "mental": 2, "names": ["Dorje", "Pema", "Tenzin", "Tsering", "Norbu", "Lhamo", "Kunzang", "Yangchen"]},
	"Bompaşao": {"tagline": "Concrete courts, no net posts worth the name, and a religion built around the first contact. If it's passable, it gets passed.",
		"physical": 1, "technical": 3, "mental": 1, "names": ["Nilo", "Yaritza", "Elpidio", "Marisol", "Ozéias", "Caridad", "Tavo", "Idalia"]},
	"Rhen Tempaol": {"tagline": "Small halls where the set is already gone before the block has finished landing. Nobody here hits hard. Everybody here hits early.",
		"physical": 2, "technical": 2, "mental": 1, "names": ["Soah", "Minjae", "Haerin", "Wonsik", "Yerin", "Doha", "Jiwoo", "Seong"]},
	"Kutré Lyn": {"tagline": "Technical schools that treat a hard swing as an admission of failure. The corner is always open if you can see it.",
		"physical": 1, "technical": 3, "mental": 1, "names": ["Zorana", "Miloš", "Vesna", "Ilija", "Radmila", "Novak", "Danica", "Stevan"]},
	## The one region whose name is not a volleyball phrase, because it is the
	## one region with no technique of its own to name itself after. It borrows
	## whatever just won instead -- see `SixnetLeague`'s zeitgeist rule.
	"Zaitgaist": {"tagline": "A city-state you could walk across in a morning, landlocked inside Landavol, which has never developed a style and has played every style there is.",
		"physical": 1, "technical": 1, "mental": 2, "names": ["Anselm", "Reike", "Vasholt", "Merrin", "Ottlin", "Sabet", "Frauke", "Delvin"]},
}

## The clubs each region sends out, so an opponent is somewhere rather than a
## placeholder.
##
## **Built on the same device as the region names** (see
## `docs/world/STYLE_AND_SETTING.md`): a volleyball phrase reworded oddly and
## dressed in that region's spelling, so a club reads as belonging to the place
## it comes from before anybody is told where that is. Kīru Shotto is "kill
## shot", Mur Complet is a sealed wall, Ásu Sérva is "ace serve", Nõ Errõ is a
## side that does not miss, Sidaut is "side out". A club therefore says what its
## region believes in twice — once in the principles it plays by and once in its
## own name.
##
## Deliberately two apiece rather than a generator. These are read out loud in
## fixtures and results, and a name that is assembled from syllables reads like
## one; when academies exist and each region needs a dozen, a generator is the
## right answer and these become its seed vocabulary rather than its output.
const CLUB_NAMES := {
	"Landavol": ["Sidaut VK", "Doblok Volei"],
	"Spëddigh": ["Kwikkset IF", "Rüsh Lïn"],
	"Pāwa Hitō": ["Kīru Shotto", "Hādo Supaiku"],
	"Bloc du Larg": ["Mur Complet", "Touche du Filet"],
	"Xérvu": ["Ásu Sérva", "Flöté Wän"],
	"Taktikã": ["Leturã Alta", "Nõ Errõ"],
	"Ispayk": ["Los Bomba", "Sét i Spayk"],
	"A'ace": ["Al-Kil'a", "Sirv'aan"],
	"Tu'ul ys Feynt": ["Gwrist ys Bryn"],
	"Lo-onğ Ralī": ["Ralī Chöd"],
	"Bompaşao": ["Primeira Bola"],
	"Rhen Tempaol": ["Tempaol Han"],
	"Kutré Lyn": ["Kutré Kórner"],
	"Zaitgaist": ["Zaitgaist VK"],
}


## A club from this region, chosen by a number the caller already has.
##
## Index rather than a random draw so the same fixture always names the same
## club: a rally is resolved from a seed and re-resolving it must produce the
## same match, opponent included.
static func club_name(region_name: String, index: int = 0) -> String:
	var resolved := canonical_name(region_name)
	var clubs: Array = CLUB_NAMES.get(resolved, [])
	if clubs.is_empty():
		return "%s VC" % resolved
	return str(clubs[posmod(index, clubs.size())])


## What you call a person or a thing *from* a region.
##
## The rule is civic, not ethnic: a demonym is built from the place name and
## says nothing about ancestry or naming tradition. This is the Filipino/Tagalog
## distinction -- Filipino is everyone from the Philippines, Tagalog is one
## people and one language, and conflating them makes a nation into an
## ethnicity. Here it matters mechanically rather than only politely, because
## `home_region` is where a voli was *raised* and `club_region` is where they
## play now: a Xérvyan is anyone from Xérvu, including one whose family came
## from somewhere else, and a voli who moves does not stop being one.
##
## **Diacritics are preserved.** A demonym is the same word in the same written
## language as the place, so Xérvu gives Xérvyan and Taktikã gives Taktikãn. An
## earlier version dropped marks that "would not survive being said out loud",
## which is our world's habit of flattening other people's spelling into the
## alphabet that happens to be convenient, and it is the wrong instinct here: the
## mark is the region's signature and it is the only thing making the name look
## like a written language at all.
##
## Two-word regions contract to whichever half is actually spoken: "Bloc du Larg"
## is *Larg* in a sentence, so Largen.
##
## Nothing derives from the people's naming tradition. That tradition tells you
## what a voli is called; the demonym tells you where they are from.
const DEMONYMS := {
	"Landavol": "Landavolan",
	"Spëddigh": "Spëddish",
	"Pāwa Hitō": "Pāwan",
	"Bloc du Larg": "Largen",
	"Xérvu": "Xérvyan",
	"Taktikã": "Taktikãn",
	"Ispayk": "Ispaykano",
	"A'ace": "A'aceni",
	"Tu'ul ys Feynt": "Feyntish",
	"Lo-onğ Ralī": "Ralīn",
	"Bompaşao": "Bompaşan",
	"Rhen Tempaol": "Tempaoli",
	"Kutré Lyn": "Kutrén",
	"Zaitgaist": "Zaitgaister",
}

## Also carries in-world renames, not only the pre-fiction placeholders. A save
## written before a region was renamed still holds the old string in every
## player's `home_region`, so dropping the entry silently reassigns those volis
## to Landavol via `canonical_name`'s fallback.
const LEGACY_REGIONS := {
	"East Asia": "Pāwa Hitō", "Southeast Asia": "Ispayk",
	"Europe": "Landavol", "North America": "Pāwa Hitō",
	"South America": "Taktikã",
	"Kutre den Lyn": "Kutré Lyn",
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
	## Spëddigh and Pāwa Hitō each own one axis outright, which they previously
	## did not. Spëddigh was 0.85 tempo variation and 0.90 transition commitment
	## against Pāwa's 0.50 and 0.88 -- so Spëddigh was Pāwa plus unpredictability,
	## strictly better on both defining axes, and Pāwa had no dimension of its
	## own to be extreme on. Two regions cannot be distinct when one contains the
	## other.
	##
	## Spëddigh now takes the highest tempo variation in the world and settles
	## for merely high transition; Pāwa takes the highest transition commitment
	## and the lowest tempo variation of any attacking region. One is
	## unpredictable, the other is relentless, and the sim already renders that
	## difference: tempo_variation rotates tempos when reception allows, while
	## transition_commitment drives how hard a side releases into its next swing.
	"Spëddigh": {
		"decisiveness": 0.68, "pin_focus": 0.42, "tempo_variation": 0.90,
		"emotional_expression": 0.68, "serve_aggression": 0.58,
		"transition_commitment": 0.78, "block_commitment": 0.52,
	},
	"Pāwa Hitō": {
		"decisiveness": 0.76, "pin_focus": 0.70, "tempo_variation": 0.32,
		"emotional_expression": 0.62, "serve_aggression": 0.55,
		"transition_commitment": 0.94, "block_commitment": 0.58,
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

## How a region *changes* across a match, as opposed to what it does on a ball.
##
## **The second layer, and the one the taglines were always written for.** The
## seven principles above are dispositions: read fresh every rally from a table
## that never moves, so a side plays the same way at 25-23 in the fifth as it did
## at 0-0 in the first. That cannot express "their quality never declines" or
## "they find your pattern and then defend it", which are claims about a
## trajectory, and both are claims a region in this world is supposed to make.
##
## Each entry is a *rate* applied to state that already accumulates during a
## match. 1.0 is the reference and means "changes at the ordinary speed", which
## is why Landavol is 1.0 on both: a side whose fourth set looks like its first
## is a real identity in a league where everyone else bends, and it is the same
## position the region holds on every other regional system.
##
##   `fatigue_resistance`  multiplies how fast this region's volis tire. Below 1
##                         is a flatter curve. Pāwa Hitō's whole brief -- ordinary
##                         at 8-8 and unchanged when everyone else's legs have
##                         gone -- and it rides on `FatigueModel`'s three stages,
##                         so a resistant side does not merely lose less, it
##                         reaches the *laboured* and *spent* stages later or not
##                         at all. That is the difference between a small bonus
##                         and an identity.
##   `read_rate`           multiplies how fast this region's volis learn a
##                         hitter's spin, tendencies and read tags within a
##                         match. Taktikã's brief, and the only thing that would
##                         make a Taktikãn side genuinely worse to play against in
##                         set four than in set one.
##
## Deliberately two rather than four. `adaptation_rate` and `composure_decay` are
## designed (see `REGIONAL_DIFFERENTIATION_SPEC.md`) and unbuilt, and adding a
## column nothing reads is the exact defect the `physical`/`technical`/`mental`
## ratings spent a year being.
const REGIONAL_CURVES := {
	"Landavol": {"fatigue_resistance": 1.00, "read_rate": 1.00},
	"Spëddigh": {"fatigue_resistance": 1.18, "read_rate": 1.05},
	## The flattest curve in the world, and the reason to fear a long match.
	"Pāwa Hitō": {"fatigue_resistance": 0.55, "read_rate": 0.90},
	"Bloc du Larg": {"fatigue_resistance": 0.88, "read_rate": 1.15},
	"Xérvu": {"fatigue_resistance": 1.10, "read_rate": 0.95},
	## Reads the game faster than anybody, and pays for it in the legs.
	"Taktikã": {"fatigue_resistance": 1.12, "read_rate": 1.55},
	"Ispayk": {"fatigue_resistance": 1.05, "read_rate": 0.80},
	## Assembled squads that never learned to read together.
	"A'ace": {"fatigue_resistance": 0.95, "read_rate": 0.72},
	"Tu'ul ys Feynt": {"fatigue_resistance": 1.05, "read_rate": 1.20},
	"Lo-onğ Ralī": {"fatigue_resistance": 0.50, "read_rate": 1.00},
	"Bompaşao": {"fatigue_resistance": 0.90, "read_rate": 1.10},
	"Rhen Tempaol": {"fatigue_resistance": 1.10, "read_rate": 1.05},
	"Kutré Lyn": {"fatigue_resistance": 1.00, "read_rate": 1.10},
	"Zaitgaist": {"fatigue_resistance": 1.00, "read_rate": 1.00},
}


## How fast this region's volis tire, as a multiplier. Below 1 is slower.
static func fatigue_resistance(region_name: String) -> float:
	return float(Dictionary(REGIONAL_CURVES.get(
		canonical_name(region_name), {}
	)).get("fatigue_resistance", 1.0))


## How fast this region's volis learn a ball within a match.
static func read_rate(region_name: String) -> float:
	return float(Dictionary(REGIONAL_CURVES.get(
		canonical_name(region_name), {}
	)).get("read_rate", 1.0))


## Invented flavor geography for the influence-drift mechanic -- which core
## regions are close enough to plausibly absorb (or resist) each other's
## development traditions. Not tied to each region's real-world naming
## culture (see `docs/world/STYLE_AND_SETTING.md`); this is a made-up world
## map, symmetric by construction (every entry appears on both sides).
const REGION_ADJACENCY := {
	"Landavol": ["Bloc du Larg", "Spëddigh", "Zaitgaist"],
	"Spëddigh": ["Landavol", "Taktikã", "Rhen Tempaol"],
	"Pāwa Hitō": ["Xérvu", "Lo-onğ Ralī"],
	"Bloc du Larg": ["Landavol", "Xérvu", "Bompaşao"],
	"Xérvu": ["Bloc du Larg", "Pāwa Hitō", "Taktikã", "Kutré Lyn"],
	"Taktikã": ["Spëddigh", "Xérvu", "Tu'ul ys Feynt"],
	"Tu'ul ys Feynt": ["Taktikã"],
	"Lo-onğ Ralī": ["Pāwa Hitō"],
	"Bompaşao": ["Bloc du Larg"],
	"Rhen Tempaol": ["Spëddigh"],
	"Kutré Lyn": ["Xérvu"],
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
	"Tu'ul ys Feynt", "Lo-onğ Ralī", "Bompaşao", "Rhen Tempaol",
	"Kutré Lyn", "Zaitgaist",
]

## Influence drift covers core plus minor. Ispayk and A'ace stay out: their
## identities come from history and money rather than a local training
## tradition that could spread or be absorbed.
const DEVELOPMENT_REGIONS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Bloc du Larg", "Xérvu", "Taktikã",
	"Tu'ul ys Feynt", "Lo-onğ Ralī", "Bompaşao", "Rhen Tempaol",
	"Kutré Lyn", "Zaitgaist",
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
	"Tu'ul ys Feynt", "Lo-onğ Ralī", "Bompaşao", "Rhen Tempaol",
	"Kutré Lyn", "Zaitgaist",
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
## The spread is deliberate. Lo-onğ Ralī is an isolated mountain tradition and
## the hardest to reach; Kutré Lyn is well-connected inland and could plausibly
## be swallowed outright; Zaitgaist has nothing to resist with, which is the
## point of it. Regions absent here resist normally.
const REGION_TRADITION_RESISTANCE := {
	"Lo-onğ Ralī": 1.4,
	"Tu'ul ys Feynt": 1.0,
	"Rhen Tempaol": 0.9,
	"Bompaşao": 0.8,
	"Kutré Lyn": 0.7,
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
## Regions a manager can take a job in.
##
## The eight Sixnet participants, because a minor region runs no programme at
## this level -- they are places you sign volis *from* rather than places you
## manage.
##
## **Renamed from `playable_names`, which was answering two different questions
## with one list.** "Where can I manage" and "who can I play" are not the same
## set and were being served by the same eight names, so the six minor regions
## were unreachable as opponents despite every one of them having a club in
## `CLUB_NAMES` and a full identity in `DEFINITIONS`. A list used as the answer
## to two questions is right for at most one of them.
static func manageable_names() -> Array[String]:
	var result: Array[String] = SIXNET_PARTICIPANTS.duplicate()
	result.sort()
	return result


## Regions that field a club you could be drawn against.
##
## All fourteen inhabited regions. A minor region has fewer clubs and weaker
## ones, which is a difference in what the fixture *is* rather than a reason it
## cannot happen -- and playing one is the cheapest way a manager learns that
## the world is bigger than the bracket.
static func opponent_names() -> Array[String]:
	var result: Array[String] = INHABITED_REGIONS.duplicate()
	result.sort()
	return result


## Every club this region fields, in the order `club_name` indexes them.
##
## Majors carry two and minors one, which is the tier difference made concrete
## rather than asserted. A region with no entry is given the fallback name
## `club_name` would produce, so the list is never empty and a caller never has
## to handle a region that exists but cannot be played.
static func clubs_in(region_name: String) -> Array[String]:
	var resolved := canonical_name(region_name)
	var clubs: Array = CLUB_NAMES.get(resolved, [])
	var result: Array[String] = []
	for club in clubs:
		result.append(str(club))
	if result.is_empty():
		result.append(club_name(resolved, 0))
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


## "Xérvyan", for a voli, a paste or a plate of food. Unknown regions fall back
## to the region name itself rather than to Landavol's demonym, because calling
## an unrecognised place's food Landavolan is a wrong answer stated confidently.
## Deliberately not routed through `canonical_name`, which resolves anything it
## does not recognise to Landavol. That is right for picking a region to play in
## and wrong for naming one: it would report an unknown place's food as
## Landavolan, which is a wrong answer stated confidently. Legacy names still
## resolve; everything else echoes back visibly unresolved.
static func demonym(region_name: String) -> String:
	if region_name in DEMONYMS:
		return str(DEMONYMS[region_name])
	var legacy_name := str(LEGACY_REGIONS.get(region_name, ""))
	return str(DEMONYMS.get(legacy_name, region_name))


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
