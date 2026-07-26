class_name VolleyballRegions
extends RefCounted

const DEFINITIONS := {
	"East Asia": {"tagline": "Technical leagues, disciplined systems and deep defensive talent.",
		"physical": 0, "technical": 5, "mental": 3, "names": ["Aki", "Hana", "Ren", "Sora", "Yuna", "Min", "Jae", "Rin"]},
	"Southeast Asia": {"tagline": "Fast, resilient volleyball with strong ball control and developing infrastructure.",
		"physical": -2, "technical": 4, "mental": 4, "names": ["Mali", "An", "Bao", "Dara", "Linh", "Nok", "Pim", "Vinh"]},
	"Europe": {"tagline": "Tactically varied competitions with balanced physical and technical development.",
		"physical": 3, "technical": 2, "mental": 2, "names": ["Mila", "Luka", "Nora", "Ivo", "Toma", "Elin", "Sven", "Kaja"]},
	"North America": {"tagline": "Athletic pipelines, university graduates and high-performance training.",
		"physical": 5, "technical": 0, "mental": 1, "names": ["Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Avery", "Cameron"]},
	"South America": {"tagline": "Expressive, aggressive volleyball with creative attackers and setters.",
		"physical": 2, "technical": 3, "mental": 2, "names": ["Luz", "Caio", "Bia", "Nico", "Iara", "Teo", "Sol", "Rafa"]},
}


static func names() -> Array[String]:
	var result: Array[String] = []
	for region_name in DEFINITIONS:
		result.append(str(region_name))
	result.sort()
	return result


static func definition(region_name: String) -> Dictionary:
	return Dictionary(DEFINITIONS.get(region_name, DEFINITIONS["Europe"])).duplicate(true)
