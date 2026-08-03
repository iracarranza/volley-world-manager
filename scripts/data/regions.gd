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
	"Landavol": ["Bloc du Larg", "Spëddigh"],
	"Spëddigh": ["Landavol", "Taktikã"],
	"Pāwa Hitō": ["Xérvu"],
	"Bloc du Larg": ["Landavol", "Xérvu"],
	"Xérvu": ["Bloc du Larg", "Pāwa Hitō", "Taktikã"],
	"Taktikã": ["Spëddigh", "Xérvu"],
}


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
