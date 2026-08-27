class_name RegionProfiles
extends RefCounted

## Canonical region inputs for player generation/development. Region definitions
## live here; PlayerGenerator only composes them.

const REGION_HEIGHT_BIAS := {
	"Pāwa Hitō": 3.0, "Spëddigh": -2.0, "Blôc du Larg": 3.0, "Landavol": 0.0,
	"Xérvu": 1.0, "Taktikã": -1.0, "Ĭspayk": 4.0, "A'ace": 1.0,
	"Tãul ys Feynt": -3.0,
	"Lo-ong Ralī": -5.0,
	"Bompaçao": -2.0,
	"Rhėn Tempaol": -1.0,
	"Kutré Lyn": 0.0,
	"Zaitgaist": 0.0,
}

const REGION_MASS_BIAS := {
	"Pāwa Hitō": 4.0, "Spëddigh": -3.0, "Blôc du Larg": 2.0, "Landavol": 0.0,
	"Xérvu": 0.0, "Taktikã": -1.0, "Ĭspayk": 5.0, "A'ace": 1.0,
	"Tãul ys Feynt": -4.0,
	"Lo-ong Ralī": -5.0,
	"Bompaçao": -1.0,
	"Rhėn Tempaol": -3.0,
	"Kutré Lyn": -2.0,
	"Zaitgaist": 0.0,
}

const REGION_WINGSPAN_BIAS := {
	"Pāwa Hitō": 2.0, "Spëddigh": -2.0, "Blôc du Larg": 4.0, "Landavol": 0.0,
	"Xérvu": 2.0, "Taktikã": 0.0, "Ĭspayk": 3.0, "A'ace": 1.0,
	"Tãul ys Feynt": -2.0,
	"Lo-ong Ralī": -3.0,
	"Bompaçao": 0.0,
	"Rhėn Tempaol": -1.0,
	"Kutré Lyn": 0.0,
	"Zaitgaist": 0.0,
}

const REGION_SPECIALTY := {
	## **A battery, not a swing.** Pāwa Hitō's power is a *consequence* and the
	## list is deliberately short to say so: they are large volis who are still
	## going in the fifth set, and the damage they do is done to defenders who are
	## not. Nothing here is an attacking attribute, because the attacking comes
	## from `fatigue_resistance` 0.55 holding them at full output while everybody
	## else labours, and from a frame that was raised to match the fiction.
	##
	## `approach_timing` and `attack_accuracy` were dropped from here rather than
	## from Ĭspayk: those are a spike being *perfected*, which is Ĭspayk's whole
	## claim, and having them in both was the single worst overlap in the table --
	## the two regions the design most needed to separate shared two attributes.
	"Pāwa Hitō": ["stamina", "transition_speed", "explosiveness"],
	"Spëddigh": ["work_rate", "acceleration", "lateral_speed", "tempo_control", "reception_balance"],
	## **A wall and the floor behind it, not a side that out-thinks you.**
	##
	## `court_vision` and `tactical_discipline` spelled this region as *analysis*
	## -- a side that studies you and adjusts -- and that was never what the wall
	## is for. A Largôis block does not need to guess right, because it is long
	## enough and quick enough to get a hand on the shot it guessed wrong about.
	## `anticipation` stays removed for a separate reason: it is 0.30 of dig
	## capability and 0.34 of a blocker's read, so holding it made the blocking
	## tradition the best digging tradition too.
	##
	## The cut before this one reached for
	## `lateral_speed` and `explosiveness`, which are Spëddigh's and Pāwa Hitō's,
	## so the region built on coverage was expressed in two other regions'
	## vocabulary. Size is now carried by the physique bias instead of by
	## `jump_reach` -- a different channel from Ĭspayk's air presence, which is
	## what lets both regions be tall without being the same claim -- and the
	## attributes say the thing the fiction actually says: they touch what you
	## hit, and what gets past the wall is still dug.
	"Blôc du Larg": ["block_timing", "reception_stability", "dig_control",
		"ball_control"],
	"Landavol": [],
	"Xérvu": ["serve_power", "serve_technique", "serve_placement", "serve_consistency",
		"serve_aggression", "serve_variation"],
	"Taktikã": ["decision_making", "composure", "tactical_discipline",
		"adaptability", "unpredictability"],
	## **One polished swing, fed as often as possible.** Ĭspayk is not Pāwa Hitō
	## with a bigger frame: Pāwa's claim is *repetition* -- the sixth attack of a
	## rally as good as the first -- and Ĭspayk's is a single terminal contact so
	## well drilled that it goes through a block rather than around one. The
	## bomba is a technique, not an engine.
	##
	## So `shot_variety` goes, and it is the point of the change rather than a
	## trim: a side that can hit six different shots is not predictable, and being
	## predictable is what Ĭspayk is supposed to *cost*. What replaces it is more
	## of the same swing -- `approach_timing` and `attack_accuracy` are the
	## polish, `attack_power` and `arm_speed` the terminal contact. A defence that
	## has seen it enough times knows exactly where it is going, which is what
	## makes the region beatable by the traditions built on reading.
	##
	## `block_timing` is dropped for a different reason: it sat in three regions
	## at once, so the blocking tradition, the bomba tradition and the bought
	## squad all claimed it and none of them owned it.
	"Ĭspayk": ["attack_power", "arm_speed", "jump_reach", "approach_timing",
		"attack_accuracy"],
	## **Bought terminal ability, and nothing that makes a team of it.**
	##
	## A'ace does not develop volis, it assembles them, and what it shops for is
	## exactly what shows on a highlight: somebody who ends points, wants the
	## ball, and is already good now. `attack_power` and `block_timing` are the
	## two point-ending contacts in the sport and both stay. `leadership` joins
	## them because A'ace recruits for it as openly as for the swing -- a squad of
	## strangers is bought a captain rather than growing one.
	##
	## What it cannot buy is a shared idea of how to play, and that is priced as a
	## real cost rather than a smaller bonus: see `REGION_TACTICAL_PENALTY`, which
	## takes `tactical_discipline`, `decision_making` and `court_vision` off
	## anybody A'ace raised. The fiction is a region with no historical volleyball
	## presence, so its own academies teach the swing and not the game -- and a
	## strong team that is not coached into strong decisions does not find the
	## situations its terminal players are bought for.
	"A'ace": ["attack_power", "block_timing", "leadership"],

	## Minor regions: two or three attributes, not four to six. The tier's
	## whole proposition is a narrow, deep tradition rather than a broad one,
	## and two of these fill gaps no major region claims -- `reception`, the
	## core passing technique (Spëddigh owns balance and pace resistance but
	## never reception itself), and `attack_accuracy`, claimed by nobody at all
	## despite being primary for three of the five roles.
	"Tãul ys Feynt": ["feinting", "tooling", "finesse"],
	## The long-rally tradition, which was worse at digging than the blocking
	## tradition. `dig_control` is only 0.22 of dig capability and
	## `reception_stability` enters a dig solely through the body penalty, so two
	## of its three attributes barely reached the floor. `anticipation` is 0.30
	## and is the one Blôc du Larg gives up, which takes this region from 0.22 of
	## the dig model to 0.52 without poaching `reception` -- Bompaçao's claim,
	## and the only attribute that outweighs it.
	"Lo-ong Ralī": ["stamina", "dig_control", "anticipation"],
	"Bompaçao": ["reception", "reception_balance", "ball_control"],
	"Rhėn Tempaol": ["approach_timing", "arm_speed", "transition_speed"],
	"Kutré Lyn": ["attack_accuracy", "shot_variety", "court_vision"],
	## Zaitgaist has no tradition of its own. Its specialty comes entirely from
	## `region_overlay`, rewritten each season to mirror whoever last won the
	## Sixnet -- see `SixnetLeague.apply_influence_drift()`.
	"Zaitgaist": [],
}

const REGION_EGO_BIAS := {
	"Ĭspayk": 14.0, "Xérvu": 9.0, "Pāwa Hitō": 5.0, "A'ace": 6.0,
	"Spëddigh": 2.0, "Landavol": 0.0, "Blôc du Larg": -6.0, "Taktikã": -15.0,
	## Minor regions, listed rather than defaulted so a reader can see that the
	## silence is deliberate. The deception traditions back themselves; the
	## endurance and passing traditions are built on not needing to.
	"Tãul ys Feynt": 7.0,
	"Lo-ong Ralī": -9.0,
	"Bompaçao": -7.0,
	"Rhėn Tempaol": 3.0,
	"Kutré Lyn": 1.0,
	"Zaitgaist": 0.0,
}

const REGION_AGGRESSION_BIAS := {
	"Ĭspayk": 15.0, "Xérvu": 11.0, "Pāwa Hitō": 7.0, "A'ace": 4.0,
	"Spëddigh": 3.0, "Landavol": 0.0, "Blôc du Larg": -4.0, "Taktikã": -9.0,
	"Tãul ys Feynt": -3.0,
	"Lo-ong Ralī": -11.0,
	"Bompaçao": -8.0,
	"Rhėn Tempaol": 6.0,
	"Kutré Lyn": 2.0,
	"Zaitgaist": 0.0,
}

const REGION_CEILING_PENALTY := {
	## Quick and light, and it costs them at the net in both directions.
	"Spëddigh": {"attack_power": -10, "block_timing": -8},
	## They go through you. They have never needed to go around you, so the
	## deception attributes were never taught.
	"Pāwa Hitō": {"feinting": -11, "set_disguise": -9},
	## A structured side is a side that struggles when the structure breaks, and
	## a wall built on staying home does not learn to serve people off it.
	"Blôc du Larg": {"improvisation": -11, "serve_power": -9},
	## Six specialty attributes on serving, and a tradition that treats the first
	## contact as somebody else's problem.
	"Xérvu": {"reception": -11, "dig_control": -9},
	## The one region that will not win a physical contest, which is the point of
	## it -- and the reason its reading has to be worth something.
	"Taktikã": {"explosiveness": -12, "jump_reach": -10},
	## **The cost of the perfect swing is that it is the only swing.** Predictable
	## by construction and unable to change once read, which is exactly the
	## matchup Taktikã is built to win.
	"Ĭspayk": {"shot_variety": -12, "adaptability": -10},
	## Bought terminal ability with no shared idea of how to play.
	"A'ace": {
		"tactical_discipline": -12, "decision_making": -12, "court_vision": -9,
	},
}

static func specialty(region_name: String) -> Array:
	return Array(REGION_SPECIALTY.get(region_name, []))

static func physique(region_name: String) -> Dictionary:
	return {
		"height": float(REGION_HEIGHT_BIAS.get(region_name, 0.0)),
		"mass": float(REGION_MASS_BIAS.get(region_name, 0.0)),
		"wingspan": float(REGION_WINGSPAN_BIAS.get(region_name, 0.0)),
	}
