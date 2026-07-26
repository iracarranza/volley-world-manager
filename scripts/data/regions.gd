class_name VolleyballRegions
extends RefCounted

const DEFINITIONS := {
	"Landavol": {"tagline": "Layered club traditions, adaptable systems and balanced player education.",
		"physical": 1, "technical": 2, "mental": 3, "names": ["Mila", "Luka", "Nora", "Ivo", "Toma", "Elin", "Sven", "Kaja"]},
	"Spëddigh": {"tagline": "Compact community gyms prize tempo, floor craft and rapid transition decisions.",
		"physical": 2, "technical": 3, "mental": 2, "names": ["Edda", "Siv", "Nils", "Veya", "Tekk", "Orri", "Fenn", "Lïv"]},
	"Pāwa Hitō": {"tagline": "Showcase academies favor assertive serving, explosive approaches and attacking ambition.",
		"physical": 4, "technical": 1, "mental": 1, "names": ["Aki", "Hana", "Ren", "Sora", "Yuna", "Kai", "Mio", "Taro"]},
	"Bloc du Larg": {"tagline": "Methodical halls teach net control, patient structure and collective discipline.",
		"physical": 2, "technical": 1, "mental": 4, "names": ["Luc", "Mire", "Noé", "Ciel", "Aude", "Remy", "Léon", "Véra"]},
}

const LEGACY_REGIONS := {
	"East Asia": "Pāwa Hitō", "Southeast Asia": "Spëddigh",
	"Europe": "Landavol", "North America": "Pāwa Hitō",
	"South America": "Spëddigh",
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
