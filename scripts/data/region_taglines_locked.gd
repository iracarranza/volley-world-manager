class_name RegionTaglinesLocked
extends RefCounted

## Approved region-selection copy from the save-file differentiation pass.
##
## This is a source-of-truth staging file, not yet wired over
## VolleyballRegions.DEFINITIONS. `regions.gd` still owns runtime display until
## the monolithic table is reconciled safely. Kutré Lyn is intentionally omitted
## because its latest wording is still a direction rather than an explicit lock.
const TAGLINES := {
	"Landavol": "Landavolan training is intentionally broad, allowing their volis to specialize into anything -- or everything, if they want.",
	"Spëddigh": "The close-knit and compact Spëddish get under the ball and turn broken plays into attacks before the opponent can react; their system is to make a system unnecessary.",
	"Pāwa Hitō": "Hitōuen conditioning halls mold relentless attackers and tireless defenders, turning each rally into an exhausting nightmare.",
	"Blôc du Larg": "Largôis culture prizes blocking structure above all else, becoming oppressors of the spiker and protectors of the receiver.",
	"Xérvu": "Ancient and new rhythms reverberate through Xérvyan courts -- a combination of individualism and deep respect for routine creates devastating, unpredictable serves.",
	"Taktikã": "Taktikãni volleyball demands cerebral players who strip the game down to its roots; every pattern is information, every rally another piece of the answer.",
	"Ĭspayk": "The cradle of the set-and-spike has lost ground to the modernization of the sport, but veteran and new Ĭspaykanos alike keep perfecting their signature attack.",
	"A'ace": "A'ace'ni volleyball may as well have been born yesterday, but the power of program funding defies history. The world's premier volis dictate their tactics season to season.",
	"Tãul ys Feynt": "Tãul ys Feynt's village programs draw from a small player pool and routinely face larger players from regions with far greater depth. Their answer has been a tradition of feints, tools and careful use of the block rather than trying to overpower it.",
	"Lo-ong Ralī": "Lo-ong Ralī's highland communities lie days from the nearest major volleyball centres, leaving their game to develop largely among themselves. The altitude and familiarity of local competition produced a tradition built around endurance, anticipation and keeping rallies alive.",
	"Bompaçao": "Bompaçao's broad grassroots volleyball culture has long outgrown its limited institutions. Jagged, uneven concrete courts demand balance and a reliable first touch just to play the game.",
	"Rhėn Tempaol": "Rhėn Tempaol inherited Spëddigh's desire for speed, but colonial magnification created an obsession with a lightning-fast attack at the expense of a more competitive system.",
	"Zaitgaist": "Zaitgaist is too small to maintain a volleyball tradition; its minuscule programs simply emulate the winning teams. Each generation adds another style for coaches to attempt to reconcile and turn into a winning formula.",
}

const KUTRE_LYN_CANDIDATE := "Kutré Lyn's few technical schools continually lose promising volis across the border to Xérvu. Those who remain enter a narrow and unforgiving program built around a simple reality: the final ball will rarely arrive cleanly. Kutrén hitters learn several attacks from the same approach because they cannot afford to need the right set."
