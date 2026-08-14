class_name RegionLanguage
extends RefCounted

## What a region's name looks like, as shape rather than as language.
##
## `STYLE_AND_SETTING.md` §Naming conventions gives every region an English
## volleyball pun respelled with foreign-looking marks, and asks a minor region
## to share its major neighbour's spelling. That rule was written down, never
## applied, and audited by hand -- which is how `Kutre den Lyn` shipped carrying
## Bloc du Larg's connector while sitting next to Xérvu, announcing kinship with
## the wrong region.
##
## ## Why the rule could not be enforced as written
##
## It compared *languages*. `ş` is Turkish and `ç` is French, so Bompaşao beside
## a French neighbour read as a mismatch -- and Bloc du Larg carries no mark at
## all, so the literal reading said Bompaşao should be bare, which is not what
## anybody wanted. A rule that cannot answer its own audit table is not a rule.
##
## **The unit is the gesture, not the language.** `ç` and `ş` are the same
## thing: a tail hung below the letter. They come from unrelated languages and a
## player does not know or care, because what a player perceives is the *shape*.
## Sorting marks by the movement that draws them gives a vocabulary that is
## visible without knowing any writing system, and checkable without knowing any
## grammar.
##
## ## Three relations, and only three
##
## - **Same gesture** -- the same mark. `Xérvu` and `Kutré Lyn`.
## - **Same family** -- different marks drawn with the same movement. Two dots
##   above and one dot above; a wave above and a cup above. `Spëddigh` and
##   `Rhėn Tempaol`.
## - **Opposed** -- the same mark mirrored across the letter. A roof above and a
##   hook below. Used once, deliberately: `Blôc du Larg` and `Bompaçao` are a
##   metropole and a coastal colony that defines itself against it, and the
##   opposition says that where kinship would have said the wrong thing.
##
## Anything else is a stranger, and a minor region may not be a stranger to its
## own neighbour.
##
## ## The marks are bounded by what can actually be drawn
##
## Every mark below is complete in **Cherry Bomb One**, which is the heading face
## and the fallback under `body_font.tres`. Families that face only partly covers
## are deliberately absent: the underdot (`ḍḥṇṛṣṭ`, 2 of 8), the stroke-through
## (`đħłøŧ`, 5 of 7) and the letterform substitutions (`þðŋ`, 3 of 5). A mark
## that renders as a hollow box is worse than no mark, and this is the file that
## has to know it.

## The families, and the marks each one is drawn with.
##
## Keyed by gesture; the value is every letter in the game's Latin range that
## carries it. A name is checked by asking which gestures its letters belong to,
## so a letter missing from this table is a letter no region may use.
const GESTURES := {
	## No mark at all, which is a gesture in its own right and not an absence of
	## one. Landavol is the deliberate no-lean region and Zaitgaist has never
	## developed a style; both being bare is the two of them agreeing.
	&"bare": "",
	&"diaeresis": "äëïöüÿÄËÏÖÜŸ",
	&"overdot": "ċėġżĊĖĠŻ",
	&"macron": "āēīōūĀĒĪŌŪ",
	&"circumflex": "âêîôûŵŷÂÊÎÔÛŴŶ",
	&"caron": "čšžřěňľďČŠŽŘĚŇĽĎ",
	&"acute": "áéíóúýńśćźŕĺÁÉÍÓÚÝŃŚĆŹŔĹ",
	&"grave": "àèìòùỳÀÈÌÒÙỲ",
	&"tilde": "ãẽĩõũñÃẼĨÕŨÑ",
	&"breve": "ăĕğĭŏŭĂĔĞĬŎŬ",
	&"cedilla": "çşţķļņģŗÇŞŢĶĻŅĢŖ",
	&"ogonek": "ąęįųĄĘĮŲ",
	&"ring": "åůÅŮ",
	## Not a mark on a letter but a hole between two. A'ace is the region with no
	## history to write down, so its signature is the gap where one would go.
	&"gap": "'ʼ",
}

## Which movement draws each gesture. Two gestures in one family are siblings:
## visibly related, not identical.
const FAMILIES := {
	&"bare": &"bare",
	&"diaeresis": &"above_dots",
	&"overdot": &"above_dots",
	&"macron": &"above_bar",
	&"circumflex": &"above_roof",
	&"caron": &"above_roof",
	&"acute": &"above_stroke",
	&"grave": &"above_stroke",
	&"tilde": &"above_curve",
	&"breve": &"above_curve",
	&"cedilla": &"below_tail",
	&"ogonek": &"below_tail",
	&"ring": &"above_ring",
	&"gap": &"gap",
}

## The same mark, mirrored across the letter.
##
## Deliberately sparse. Opposition is a *stronger* statement than kinship -- it
## says these two places know each other and have chosen to look unlike -- so it
## is worth exactly as much as it is rare. One pair uses it.
const OPPOSES := {
	&"circumflex": &"cedilla",
	&"cedilla": &"circumflex",
}

## The gesture each region signs its name with.
##
## The shape is chosen to say something about the volleyball, which is the whole
## reason a made-up orthography is worth having:
##
## | region | gesture | what the shape is |
## |---|---|---|
## | Spëddigh | two dots | quick, tight, doubled -- like its consonants |
## | Rhėn Tempaol | one dot | a colony's half-inheritance of two |
## | Pāwa Hitō | a bar | held, sustained, deep into the rally |
## | Lo-ong Ralī | a bar | the same endurance at altitude |
## | Blôc du Larg | a roof | the wall at the net |
## | Bompaçao | a hook below | getting *under* the ball; the first contact |
## | Xérvu | a stroke | the serve |
## | Kutré Lyn | a stroke | the same hand, finer |
## | Taktikã | a wave | the read |
## | Tãul ys Feynt | a wave | reading, with less to read with |
## | Ĭspayk | a cup | on the epenthetic i itself -- the mark *is* the pun |
## | A'ace | a gap | a hole where a history should be |
const REGION_GESTURE := {
	"Landavol": &"bare",
	"Zaitgaist": &"bare",
	"Spëddigh": &"diaeresis",
	"Rhėn Tempaol": &"overdot",
	"Pāwa Hitō": &"macron",
	"Lo-ong Ralī": &"macron",
	"Blôc du Larg": &"circumflex",
	"Bompaçao": &"cedilla",
	"Xérvu": &"acute",
	"Kutré Lyn": &"acute",
	"Taktikã": &"tilde",
	"Tãul ys Feynt": &"tilde",
	"Ĭspayk": &"breve",
	"A'ace": &"gap",
}

## The regions that say the family name first.
##
## Both are drawn from traditions that really do, and the honest thing is to
## follow them -- but the reason this is a table rather than a comment is that
## the alternative was worse in a specific way. A per-region display order
## computed at draw time means every roster column, every sorted list and every
## fixture line has to know the convention, and the first screen that forgets is
## the one that shows a Pāwan under G for their given name while their teammates
## sort by family. Composing the string once, at generation, means there is only
## ever one name and nothing downstream has an order to get wrong.
const FAMILY_FIRST := {
	"Pāwa Hitō": true,
	"Rhėn Tempaol": true,
}

## The half of a two-word region that gets spoken, and that the demonym is built
## from. Nobody says "Blôc du Larg" in a sentence about a person; they say Larg.
const CONTRACTIONS := {
	"Blôc du Larg": "Larg",
	"Tãul ys Feynt": "Feynt",
	"Rhėn Tempaol": "Tempaol",
	"Lo-ong Ralī": "Ralī",
	"Pāwa Hitō": "Pāwa",
	"Kutré Lyn": "Kutré",
}


static func gesture_of(region_name: String) -> StringName:
	return REGION_GESTURE.get(region_name, &"bare")


static func family_of(gesture: StringName) -> StringName:
	return FAMILIES.get(gesture, &"bare")


## Every marked letter a region is allowed to write, which is its own gesture's
## and nothing else's.
static func letters_for(region_name: String) -> String:
	return str(GESTURES.get(gesture_of(region_name), ""))


## Whether two regions are close enough to sit next to each other on the map.
##
## The three relations in the header, in order of strength. Same gesture is the
## closest, opposition the most deliberate, and a shared family the ordinary
## case a neighbour usually wants.
static func kinship(first: String, second: String) -> StringName:
	var a := gesture_of(first)
	var b := gesture_of(second)
	if a == b:
		return &"same_gesture"
	if OPPOSES.get(a, &"") == b:
		return &"opposed"
	if family_of(a) == family_of(b):
		return &"same_family"
	return &"stranger"


## Marks in a piece of text that belong to some other region.
##
## Returns the offending characters rather than a bool, because a gate that says
## only "this name is wrong" leaves somebody grepping fourteen names for a
## character they cannot see. Letters with no mark at all are ignored -- the
## alphabet is shared and only the marks are owned.
static func stray_marks(text: String, region_name: String) -> String:
	var permitted := letters_for(region_name)
	var strays := ""
	for character in text:
		if character in permitted:
			continue
		for gesture in GESTURES:
			if gesture == gesture_of(region_name):
				continue
			if character in str(GESTURES[gesture]) and not character in strays:
				strays += character
	return strays


## What a region's name shortens to when somebody says it out loud.
static func contraction(region_name: String) -> String:
	return str(CONTRACTIONS.get(region_name, region_name))


## A given name and a family name in the order that region says them.
##
## Called once per voli, at generation, and never again -- see `FAMILY_FIRST` for
## why the order is resolved here rather than at every place a name is drawn.
static func full_name(region_name: String, given: String, family: String) -> String:
	if bool(FAMILY_FIRST.get(region_name, false)):
		return "%s %s" % [family, given]
	return "%s %s" % [given, family]
