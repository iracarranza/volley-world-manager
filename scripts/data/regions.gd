class_name VolleyballRegions
extends RefCounted

const TeamPrinciplesModel := preload("res://scripts/models/team_principles.gd")

const DEFINITIONS := {
	## ## Names
	##
	## `names` are given names and are **real, attested and unmarked**. `surnames`
	## are invented, place-derived, and carry the region's gesture from
	## `RegionLanguage`. That asymmetry is the whole naming system in two lines:
	## the orthography belongs to the map, and a person is not a place.
	##
	## Nine surnames against eight given names, deliberately coprime -- a founded
	## club fields twelve volis, and a roster with two Kiko Batangases on it is
	## the same defect as the `"%s %d"` numbering this replaced, arrived at more
	## slowly.
	##
	## Taglines name their own people with the region's `DEMONYMS` entry and are
	## gated on it. They used to carry a second set of words invented separately
	## -- Landavoli, Spëddich, Hitōue, Larçgan, Taktikiãn, Ispakyanos, A'ace'ni --
	## and Larçgan is why that mattered rather than merely being untidy: it hung a
	## cedilla on Blôc du Larg, which is Bompaçao's mark, in the one region whose
	## relationship to Bompaçao is the map's single deliberate opposition.
	## **The taglines say what a region does, not how good it is at it.**
	##
	## Five of these eight carried an adjective the frame had no standing to use
	## -- *nightmarish* power, *devastating* serves, a *crushing* bomba, the
	## *world's premier* volis, structure *perfected* into *complete control*.
	## Three of the five render on the match screen as the opponent's line, which
	## made the frame tell a manager how to feel about a side before the first
	## serve, and one of them is a superlative the standings model would then have
	## to honour. `DIEGETIC_MANAGEMENT.md` §11 is the rule; these were the strings
	## that broke it in the most visible place the game has, since the region
	## picker is also the first screen of a new save.
	##
	## Each now states a practice and its cost, and each is answerable against a
	## number in this file: the axis the region owns in `REGIONAL_PRINCIPLES`, its
	## rate in `REGIONAL_CURVES`, or its list in `REGION_SPECIALTY`. Where a
	## sentence claims an extreme -- serves hardest, changes tempo most, learns
	## fastest -- that region genuinely holds the extreme in the table, and the
	## sentence names the price beside it.
	"Landavol": {"tagline": "Landavolan halls teach every skill and favour none of them. Their volis start where the world averages and go wherever they are coached; their fourth set looks like their first.",
		"physical": 2, "technical": 2, "mental": 2,
		"names": ["Mila", "Luka", "Nora", "Ivo", "Toma", "Elin", "Sven", "Kaja"],
		## Bare, like the region. Landavol leans nowhere and its surnames are
		## plain landscape: valley, ridge, stone, water, lime, east farm.
		"surnames": ["Beladol", "Ravnik", "Stenmark", "Vodgrad", "Lindvik",
			"Osterby", "Kamenar", "Solmar", "Tunsen"]},
	"Spëddigh": {"tagline": "Spëddish halls are small and so are the people in them. No side in the world changes tempo more often, and none spends its legs faster doing it.",
		"physical": 2, "technical": 3, "mental": 2,
		"names": ["Edda", "Siv", "Nils", "Veya", "Tekk", "Orri", "Fenn", "Lïv"],
		## Doubled consonants and a short vowel under two dots, which is the same
		## thing the region does to a rally.
		"surnames": ["Hällgrim", "Skäddur", "Nörvik", "Trëggen", "Vïdden",
			"Bräkkstad", "Ëlfjord", "Snöhamn", "Kvëllby"]},
	"Pāwa Hitō": {"tagline": "Pāwan conditioning halls train one thing: the sixth swing of a rally arriving like the first. They commit to every transition, and they are still committing when the legs across the net have gone.",
		"physical": 4, "technical": 1, "mental": 1,
		"names": ["Aki", "Hana", "Ren", "Sora", "Yuna", "Kai", "Mio", "Taro"],
		## Real surnames, and real ones happen to be the strongest case the whole
		## scheme has: Japanese family names are overwhelmingly landscape -- Ōno
		## is the big field, Ōtani the big valley, Kōno the river field. The
		## long vowel they already carry *is* this region's gesture, so nothing
		## had to be invented and nothing had to be bent.
		"surnames": ["Ōno", "Ōtani", "Kōno", "Sōma", "Gotō", "Satō", "Kudō",
			"Andō", "Tōdō"]},
	"Blôc du Larg": {"tagline": "Largen sides serve safe, decide late, and put a long block in front of everything. What gets past the wall is dug by the floor standing behind it.",
		"physical": 2, "technical": 2, "mental": 3,
		"names": ["Luc", "Mire", "Noé", "Ciel", "Aude", "Remy", "Léon", "Véra"],
		## Wall, rampart, keep, hillside. A region that believes in structure at
		## the net is named for the things people built before nets existed.
		##
		## `Côte` and not Côté, which is the more natural surname and was the
		## first one written here. It carries a roof *and* an acute, and the acute
		## is Xérvu's -- so the obvious French name for a French-shaped region
		## announces kinship with a region three seas away. The gate caught it on
		## the first run, which is the entire argument for having one.
		"surnames": ["Côte", "Châtel", "Fôret", "Rempârt", "Dumûr", "Vallêe",
			"Lacrôix", "Montaîgne", "Bôisclair"]},
	"Xérvu": {"tagline": "Six kinds of serve are taught on Xérvyan courts and no kind of safety. They serve harder than anyone alive and hand back more points doing it.",
		"physical": 2, "technical": 4, "mental": 1,
		"names": ["Kofi", "Amara", "Zola", "Kwame", "Aziza", "Tendai", "Njeri", "Baraka"],
		## Cities and the families that carry their names. The acute is a tone
		## mark here rather than a stress mark, which is what it is in Yoruba and
		## Akan, and which is why it sits comfortably on a name meant to be sung
		## rather than spelled.
		"surnames": ["Ashánti", "Adéyemi", "Okónkwo", "Sékou", "Nyámbe",
			"Kúmasi", "Bandiágara", "Sokóto", "Ilorín"]},
	"Taktikã": {"tagline": "Taktikãn coaching treats a rally as a problem with one right answer, and a face as information you should not give away. They learn your hitters faster than anyone in the world.",
		"physical": 1, "technical": 1, "mental": 4,
		"names": ["Inti", "Aylen", "Kuyen", "Amaru", "Wayra", "Nayra", "Chaska", "Illari"],
		## Real Aymara and Quechua surnames, which are clan-and-place names to
		## begin with, taking the wave instead of the accent they usually carry.
		"surnames": ["Quispẽ", "Mamanĩ", "Huamãn", "Condorĩ", "Ticõna",
			"Choquẽ", "Apazã", "Yupanquĩ", "Cusĩ"]},
	"Ĭspayk": {"tagline": "Ĭspaykano gyms invented the set-and-spike and never stopped running it. The bomba goes to the pin, the decision is made early, and nobody is watching to see what you changed.",
		"physical": 4, "technical": 2, "mental": 1,
		"names": ["Kiko", "Mika", "Jun", "Rico", "Bea", "Nico", "Liza", "Ana"],
		## Provinces and towns, because a colonial surname register hands out
		## place names and everybody keeps them. The region whose given names are
		## all nicknames is the one whose family names are all administrative.
		"surnames": ["Bătangas", "Cavĭte", "Bulăcan", "Marikĭna", "Pangasĭnan",
			"Bĭnondo", "Antĭpolo", "Calămba", "Tarlăc"]},
	"A'ace": {"tagline": "A'aceni programmes are new, funded, and answer to no tradition. They buy a style each season and play it exactly as written, whatever you show them.",
		"physical": 3, "technical": 2, "mental": 1,
		"names": ["Omar", "Layla", "Yusuf", "Amal", "Faisal", "Noor", "Rashid", "Huda"],
		## Every one is "of somewhere" -- the fort, the spring, the headland --
		## which is the joke the region deserves: the place with no history of its
		## own names its families after places, and the gap in the middle of each
		## one is the same gap in the middle of A'ace.
		"surnames": ["Al'Qasr", "Ras'ayn", "Bur'aida", "Sha'ab", "Da'wan",
			"Nu'mani", "Ka'bi", "Sa'idi", "Ha'ili"]},

	## Minor regions. Small programs that never contest the Sixnet, with
	## ratings summing to 4-5 against the majors' 6-8 and a specialty of two or
	## three attributes rather than four to six. Weak overall, sharply
	## specialized -- a player from one grades poorly by
	## `current_ability_score()` while sitting near the top of the world on the
	## two or three things their tradition actually teaches.
	##
	## Names follow the same device as the majors (see
	## `docs/world/STYLE_AND_SETTING.md`): a volleyball phrase reworded oddly
	## and dressed in unfamiliar spelling -- Tãul ys Feynt is "tools and
	## feints", Rhėn Tempaol is "one tempo", Lo-ong Ralī is "long rally",
	## Bompaçao is "bump pass", and Kutré Lyn is "cut and line".
	##
	## A minor region is kin to its major neighbour by *gesture* -- the same
	## mark, a sibling mark from the same movement, or the one deliberate
	## opposition. Kutré Lyn was "Kutre den Lyn" and carried Blôc du Larg's
	## connector ("den" for "du") while sitting next to Xérvu, so it announced
	## kinship with the wrong region; it now takes Xérvu's acute instead. Old
	## saves resolve through `LEGACY_REGIONS`.
	## **Feynt and Kutré Lyn were one claim in two taglines.** Both read as *we do
	## not hit hard, we place it*, which is the defect `REGIONAL_PRINCIPLES` fixed
	## between Spëddigh and Pāwa Hitō written out in prose instead of numbers: two
	## regions cannot be distinct when one contains the other. The attributes were
	## never the same -- `feinting`/`tooling` is a blocker being made to be wrong,
	## `attack_accuracy`/`shot_variety`/`court_vision` is a blocker being right and
	## it not mattering -- so the sentences now say which of the two they are.
	"Tãul ys Feynt": {"tagline": "Village halls where the block is a surface to use rather than a wall to beat. Wrists over power, and the shot the blocker was made to believe in.",
		"physical": 1, "technical": 3, "mental": 1,
		"names": ["Bryn", "Eilir", "Tewdr", "Anwen", "Maelo", "Ffion", "Gwern", "Rhosyn"],
		## Church, fort, rivermouth, town, headland, ford -- the six words every
		## place here starts with. The tradition these are drawn from spells its
		## long vowels with a roof, and this region may not: the roof belongs to
		## Blôc du Larg, three seas away, and a shared mark would claim a kinship
		## that does not exist. The wave is the point of having an orthography.
		"surnames": ["Tãulwen", "Glyndãr", "Penrhõs", "Llanfãr", "Caerlõn",
			"Trefãn", "Aberdõn", "Bryngwãn", "Rhydfãn"]},
	## `fatigue_resistance` is a *rate*, so "nobody's legs go" was an absolute over
	## a distribution -- the shape of claim §0 of `FAILURE_MODES.md` is about. 0.50
	## is the flattest curve in the world and still not immunity, and "generally"
	## is the difference.
	"Lo-ong Ralī": {"tagline": "Thin-air gyms three days' travel from anywhere. Rallies here end when somebody's legs go, and it is generally not theirs.",
		"physical": 2, "technical": 1, "mental": 2,
		"names": ["Dorje", "Pema", "Tenzin", "Tsering", "Norbu", "Lhamo", "Kunzang", "Yangchen"],
		## Places, undisguised, because the tradition these are drawn from has no
		## family names at all -- you are known by the house, and the house is
		## known by the valley it stands in.
		"surnames": ["Ngarī", "Tsāng", "Dīngri", "Lhūntse", "Gyāntse", "Nāgchu",
			"Chāmdo", "Purāng", "Shīgatse"]},
	"Bompaçao": {"tagline": "Concrete courts, no net posts worth the name, and a religion built around the first contact. If it's passable, it gets passed.",
		"physical": 1, "technical": 3, "mental": 1,
		"names": ["Nilo", "Yaritza", "Elpidio", "Marisol", "Ozéias", "Caridad", "Tavo", "Idalia"],
		## Beach, sand, edge-of-water, cleared ground. Caiçara is not invented:
		## it is what the coast calls the people who live on it, and a region
		## whose entire identity is the first contact off a concrete court should
		## be named for the shoreline rather than for the metropole it opposes.
		"surnames": ["Gonçalves", "Praiçal", "Maçado", "Furtaço", "Beiraçu",
			"Caiçara", "Areiçao", "Roçado", "Terraço"]},
	"Rhėn Tempaol": {"tagline": "Small halls where the set is already gone before the block has finished landing. Nobody here hits hard. Everybody here hits early.",
		"physical": 2, "technical": 2, "mental": 1,
		"names": ["Soah", "Minjae", "Haerin", "Wonsik", "Yerin", "Doha", "Jiwoo", "Seong"],
		## Real, one syllable, and place-derived in the strictest sense of the
		## scheme: each is a clan seat, and two families with the same surname
		## from different seats are not related.
		"surnames": ["Ġil", "Ġang", "Ġong", "Ġeum", "Sėol", "Chėon", "Yėom",
			"Bėk", "Hėo"]},
	"Kutré Lyn": {"tagline": "Technical schools that treat a hard swing as an admission of failure. A Kutrén hitter has four shots off the same approach and has already seen which corner is open.",
		"physical": 1, "technical": 3, "mental": 1,
		"names": ["Zorana", "Miloš", "Vesna", "Ilija", "Radmila", "Novak", "Danica", "Stevan"],
		## Mostly patronymic, which is the one place the place-derived rule bends
		## -- and it bends because the tradition is real and the rule is ours. The
		## last three are toponyms (behind the hill, of the hill, of the water)
		## so the scheme is present rather than merely claimed. `ć` is the acute
		## and `č` is the caron, and only one of those is Kutré Lyn's: the whole
		## list had to be picked around a mark that looks almost identical at
		## roster size and belongs to nobody here.
		"surnames": ["Radić", "Perić", "Lukić", "Tomić", "Ilić", "Babić",
			"Zagorić", "Brdarić", "Vodić"]},
	## The one region whose name is not a volleyball phrase, because it is the
	## one region with no technique of its own to name itself after. It borrows
	## whatever just won instead -- see `SixnetLeague`'s zeitgeist rule.
	"Zaitgaist": {"tagline": "A city-state you could walk across in a morning, landlocked inside Landavol, which has never developed a style and has played every style there is.",
		"physical": 1, "technical": 1, "mental": 2,
		"names": ["Anselm", "Reike", "Vasholt", "Merrin", "Ottlin", "Sabet", "Frauke", "Delvin"],
		## Bare, like Landavol, and named for streets and gates rather than for
		## landscape because there is no landscape -- you can walk across the
		## whole place before lunch. Two bare regions are told apart by sound,
		## which is the one thing a gesture system cannot do and does not try to.
		"surnames": ["Torwald", "Steinbrenn", "Althaus", "Marktweil",
			"Ringmauer", "Kleinbek", "Hofstett", "Neuland", "Wendelgass"]},
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
	"Blôc du Larg": ["Mur Complet", "Touche du Filet"],
	"Xérvu": ["Ásu Sérva", "Flóté Wán"],
	"Taktikã": ["Leturã Alta", "Nõ Errõ"],
	"Ĭspayk": ["Los Bomba", "Sĕt i Spayk"],
	"A'ace": ["Al-Kil'a", "Sirv'aan"],
	"Tãul ys Feynt": ["Gwrist ys Bryn"],
	"Lo-ong Ralī": ["Ralī Chōd"],
	"Bompaçao": ["Primeira Bola"],
	"Rhėn Tempaol": ["Tempaol Han"],
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


## A whole person's name from this region, chosen by a number the caller has.
##
## **This replaced `"%s %d"`.** A founded club used to field Kiko 1 through Kiko
## 12, which is not twelve people; it is one person and a counter, and every
## screen that draws a roster drew it. The counter was doing real work -- it kept
## the names distinct -- so the replacement has to do that work too rather than
## merely look nicer.
##
## It does it by arithmetic instead of by a suffix. Eight given names and nine
## surnames are coprime, so the pair repeats after seventy-two and a twelve-voli
## roster is twelve distinct people. The gate measures that rather than trusting
## it, because 8 and 9 being coprime is a fact about this table and the table is
## editable.
##
## The order is the region's own. Two regions here name family-first, and the
## composed string is the only place that is decided -- everything downstream
## holds one name and sorts it, so nothing else has to know.
static func person_name(region_name: String, index: int) -> String:
	var resolved := canonical_name(region_name)
	var definition := definition(resolved)
	var given: Array = Array(definition.get("names", []))
	var family: Array = Array(definition.get("surnames", []))
	if given.is_empty():
		return "Voli %d" % (index + 1)
	var first := str(given[posmod(index, given.size())])
	if family.is_empty():
		return first
	var last := str(family[posmod(index, family.size())])
	return RegionLanguage.full_name(resolved, first, last)


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
## Two-word regions contract to whichever half is actually spoken: "Blôc du Larg"
## is *Larg* in a sentence, so Largen.
##
## Nothing derives from the people's naming tradition. That tradition tells you
## what a voli is called; the demonym tells you where they are from.
const DEMONYMS := {
	"Landavol": "Landavolan",
	"Spëddigh": "Spëddish",
	"Pāwa Hitō": "Pāwan",
	"Blôc du Larg": "Largen",
	"Xérvu": "Xérvyan",
	"Taktikã": "Taktikãn",
	"Ĭspayk": "Ĭspaykano",
	"A'ace": "A'aceni",
	"Tãul ys Feynt": "Feyntish",
	"Lo-ong Ralī": "Ralīn",
	"Bompaçao": "Bompaçan",
	"Rhėn Tempaol": "Tempaoli",
	"Kutré Lyn": "Kutrén",
	"Zaitgaist": "Zaitgaister",
}

## Also carries in-world renames, not only the pre-fiction placeholders. A save
## written before a region was renamed still holds the old string in every
## player's `home_region`, so dropping the entry silently reassigns those volis
## to Landavol via `canonical_name`'s fallback.
const LEGACY_REGIONS := {
	"East Asia": "Pāwa Hitō", "Southeast Asia": "Ĭspayk",
	"Europe": "Landavol", "North America": "Pāwa Hitō",
	"South America": "Taktikã",
	"Kutre den Lyn": "Kutré Lyn",
	## The shape sweep. Every one of these is the same failure Kutre den Lyn was
	## -- a name written in somebody else's hand -- found by asking what gesture
	## draws the mark rather than which language it came from. See
	## `RegionLanguage`.
	"Bloc du Larg": "Blôc du Larg",
	"Tu'ul ys Feynt": "Tãul ys Feynt",
	"Bompaşao": "Bompaçao",
	"Rhen Tempaol": "Rhėn Tempaol",
	"Lo-onğ Ralī": "Lo-ong Ralī",
	"Ispayk": "Ĭspayk",
}

## The six regions with their own development identity -- REGION_ADJACENCY
## and influence drift are scoped to exactly this list. Ĭspayk and A'ace are
## deliberately excluded from *that* system (they don't have a development
## tradition to spread or absorb; their identity comes from history and
## money, not geography), even though both now play in the Sixnet bracket
## itself -- see `SIXNET_PARTICIPANTS`.
const CORE_REGIONS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Blôc du Larg", "Xérvu", "Taktikã",
]

## Every region that actually competes in the Sixnet's 8 bracket slots.
## Ĭspayk and A'ace hold a fixed starting slot each (see
## `SixnetLeague.ISPAYK_FIXED_SLOT`/`AACE_FIXED_SLOT`) -- lower for Ĭspayk
## (fallen flagship, clawing back), upper for A'ace (bought its way straight
## to the top) -- but afterward are subject to the same promotion/relegation
## as everyone else; "always starts" is a starting condition, not a
## permanent pin. The remaining 6 slots go to `CORE_REGIONS`, one each.
const SIXNET_PARTICIPANTS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Blôc du Larg", "Xérvu", "Taktikã",
	"Ĭspayk", "A'ace",
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
	"Blôc du Larg": {
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
	"Ĭspayk": {
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
	"Blôc du Larg": {"fatigue_resistance": 0.88, "read_rate": 1.15},
	"Xérvu": {"fatigue_resistance": 1.10, "read_rate": 0.95},
	## Reads the game faster than anybody, and pays for it in the legs.
	"Taktikã": {"fatigue_resistance": 1.12, "read_rate": 1.55},
	"Ĭspayk": {"fatigue_resistance": 1.05, "read_rate": 0.80},
	## Assembled squads that never learned to read together.
	"A'ace": {"fatigue_resistance": 0.95, "read_rate": 0.72},
	"Tãul ys Feynt": {"fatigue_resistance": 1.05, "read_rate": 1.20},
	"Lo-ong Ralī": {"fatigue_resistance": 0.50, "read_rate": 1.00},
	"Bompaçao": {"fatigue_resistance": 0.90, "read_rate": 1.10},
	"Rhėn Tempaol": {"fatigue_resistance": 1.10, "read_rate": 1.05},
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
	"Landavol": ["Blôc du Larg", "Spëddigh", "Zaitgaist"],
	"Spëddigh": ["Landavol", "Taktikã", "Rhėn Tempaol"],
	"Pāwa Hitō": ["Xérvu", "Lo-ong Ralī"],
	"Blôc du Larg": ["Landavol", "Xérvu", "Bompaçao"],
	"Xérvu": ["Blôc du Larg", "Pāwa Hitō", "Taktikã", "Kutré Lyn"],
	"Taktikã": ["Spëddigh", "Xérvu", "Tãul ys Feynt"],
	"Tãul ys Feynt": ["Taktikã"],
	"Lo-ong Ralī": ["Pāwa Hitō"],
	"Bompaçao": ["Blôc du Larg"],
	"Rhėn Tempaol": ["Spëddigh"],
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
	"Tãul ys Feynt", "Lo-ong Ralī", "Bompaçao", "Rhėn Tempaol",
	"Kutré Lyn", "Zaitgaist",
]

## Influence drift covers core plus minor. Ĭspayk and A'ace stay out: their
## identities come from history and money rather than a local training
## tradition that could spread or be absorbed.
const DEVELOPMENT_REGIONS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Blôc du Larg", "Xérvu", "Taktikã",
	"Tãul ys Feynt", "Lo-ong Ralī", "Bompaçao", "Rhėn Tempaol",
	"Kutré Lyn", "Zaitgaist",
]

## Every region that raises and hosts players -- the eight Sixnet
## participants plus the minor tier. This is the population scope, and it is
## deliberately *not* SIXNET_PARTICIPANTS: minor regions are inhabited places
## that produce, keep and lose players, they simply never contest the bracket.
## Conflating the two is how the tier ends up existing in data and nowhere in
## the actual world.
const INHABITED_REGIONS: Array[String] = [
	"Landavol", "Spëddigh", "Pāwa Hitō", "Blôc du Larg", "Xérvu", "Taktikã",
	"Ĭspayk", "A'ace",
	"Tãul ys Feynt", "Lo-ong Ralī", "Bompaçao", "Rhėn Tempaol",
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
## The spread is deliberate. Lo-ong Ralī is an isolated mountain tradition and
## the hardest to reach; Kutré Lyn is well-connected inland and could plausibly
## be swallowed outright; Zaitgaist has nothing to resist with, which is the
## point of it. Regions absent here resist normally.
const REGION_TRADITION_RESISTANCE := {
	"Lo-ong Ralī": 1.4,
	"Tãul ys Feynt": 1.0,
	"Rhėn Tempaol": 0.9,
	"Bompaçao": 0.8,
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
## **All fourteen, and the eight is now a tier rather than a gate.** This read
## "the eight Sixnet participants, because a minor region runs no programme at
## this level -- places you sign volis from rather than places you manage", and
## `CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §3 says in as many words that the
## comment is now half true and asks for it to be rewritten here: a minor region
## still runs no academy, which is the *point* of it, but that absence is the
## difficulty of managing there rather than the disqualification from it.
##
## Your region not being in the Sixnet means your best volis are watched by
## academies that are not yours, and the thing pulling them away is the one
## thing you cannot outbid. That is a harder save, not an impossible one.
##
## Majors first, then minors, each sorted -- so the opening screen reads as two
## tiers without the screen having to know which is which.
##
## **Renamed from `playable_names`, which was answering two different questions
## with one list.** "Where can I manage" and "who can I play" are not the same
## set and were being served by the same eight names, so the six minor regions
## were unreachable as opponents despite every one of them having a club in
## `CLUB_NAMES` and a full identity in `DEFINITIONS`. A list used as the answer
## to two questions is right for at most one of them.
static func manageable_names() -> Array[String]:
	var result: Array[String] = []
	result.append_array(major_names())
	result.append_array(minor_names())
	return result


## Whether this region runs a programme at the level the game is about.
##
## The Sixnet participants are the majors. Everything the save's opening choice
## needs hangs off this one question -- how many clubs there are to choose
## between, whether founding your own is on the table, and whether your volis
## are candidates for an academy that is yours.
static func is_major(region_name: String) -> bool:
	return canonical_name(region_name) in SIXNET_PARTICIPANTS


## ## Asking the tier before the region
##
## Fourteen tiles in one grid made the tier a *suffix* -- a "· minor" appended to
## six of the names -- which is the wrong shape for the choice being made. The
## difference between a major region and a minor one is the largest single fact
## about a save: how many clubs there are, whether founding is on the table,
## whether your best volis are watched by academies that are not yours. That is a
## question, and a question answered by reading a badge on a tile is a question
## the interface declined to ask.
##
## So the tier is asked first and the region second, and these two lists are what
## the second question is drawn from. Sorted, because a picker with a stable
## order is a picker somebody can learn.
const TIER_MAJOR := &"major"
const TIER_MINOR := &"minor"


static func major_names() -> Array[String]:
	var majors: Array[String] = SIXNET_PARTICIPANTS.duplicate()
	majors.sort()
	return majors


static func minor_names() -> Array[String]:
	var minors: Array[String] = MINOR_REGIONS.duplicate()
	minors.sort()
	return minors


## The regions of one tier. Unknown tiers give the majors rather than nothing:
## an empty second step is a dead end, and a save file is not a trusted source.
static func names_in_tier(tier: StringName) -> Array[String]:
	return minor_names() if tier == TIER_MINOR else major_names()


## Which tier a region belongs to, so a picker restoring a saved choice can open
## on the right page instead of resetting it.
static func tier_of(region_name: String) -> StringName:
	return TIER_MAJOR if is_major(region_name) else TIER_MINOR


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
