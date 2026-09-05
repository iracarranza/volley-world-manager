# Region save differentiation and locked taglines

Status: design authority for the region-selection copy and the current save-fantasy split. The heavier follow-up — proving that every regional fantasy creates a distinct management loop — is intentionally still open.

## Major regions

### Landavol

**Locked tagline**

> Landavolan training is intentionally broad, allowing their volis to specialize into anything -- or everything, if they want.

Save fantasy: no prescribed win condition. Landavol has the scale and breadth to become what the manager makes of it rather than forcing a particular regional solution.

### Spëddigh

**Locked tagline**

> The close-knit and compact Spëddish get under the ball and turn broken plays into attacks before the opponent can react; their system is to make a system unnecessary.

Save fantasy: transition latency and improvisational speed — turning unexpected touches into attacks before structure can catch up.

### Pāwa Hitō

**Locked tagline**

> Hitōuen conditioning halls mold relentless attackers and tireless defenders, turning each rally into an exhausting nightmare.

Save fantasy: sustained physical commitment through long rallies and matches rather than a monopoly on raw power.

### Blôc du Larg

**Locked tagline**

> Largôis culture prizes blocking structure above all else, becoming oppressors of the spiker and protectors of the receiver.

Save fantasy: structure at the net and protection of the floor behind it.

### Xérvu

**Locked tagline**

> Ancient and new rhythms reverberate through Xérvyan courts -- a combination of individualism and deep respect for routine creates devastating, unpredictable serves.

Save fantasy: serve identity rooted in repetition, individual expression, variation and aggression.

### Taktikã

**Locked tagline**

> Taktikãni volleyball demands cerebral players who strip the game down to its roots; every pattern is information, every rally another piece of the answer.

Save fantasy: reading patterns, accumulating information and solving opponents.

### Ĭspayk

**Locked tagline**

> The cradle of the set-and-spike has lost ground to the modernization of the sport, but veteran and new Ĭspaykanos alike keep perfecting their signature attack.

Save fantasy: a historic flagship trying to recover ground while continuing to refine the attack it gave the world.

### A'ace

**Locked tagline**

> A'ace'ni volleyball may as well have been born yesterday, but the power of program funding defies history. The world's premier volis dictate their tactics season to season.

Save fantasy: money and imported talent replace inherited tradition; the roster itself determines the style from season to season.

## Minor regions

The six minor regions are not intended to be "major region, but weaker." Each is missing a different piece of the machinery that lets a major remain major, and its volleyball culture is an adaptation to that missing piece.

### Tãul ys Feynt — talent pool / physical abundance

**Locked tagline**

> Tãul ys Feynt's village programs draw from a small player pool and routinely face larger players from regions with far greater depth. Their answer has been a tradition of feints, tools and careful use of the block rather than trying to overpower it.

Save fantasy: compensate for a physically and numerically disadvantaged talent pool by manipulating the block rather than beating it physically.

### Lo-ong Ralī — access / connection

**Locked tagline**

> Lo-ong Ralī's highland communities lie days from the nearest major volleyball centres, leaving their game to develop largely among themselves. The altitude and familiarity of local competition produced a tradition built around endurance, anticipation and keeping rallies alive.

Save fantasy: sustain a remote volleyball ecosystem whose local game is durable but poorly connected to the wider volleyball world.

### Bompaçao — institutions

**Locked tagline**

> Bompaçao's broad grassroots volleyball culture has long outgrown its limited institutions. Jagged, uneven concrete courts demand balance and a reliable first touch just to play the game.

Save fantasy: turn widespread participation and an existing grassroots culture into elite institutional strength.

### Rhėn Tempaol — historical autonomy / breadth

**Locked tagline**

> Rhėn Tempaol inherited Spëddigh's desire for speed, but colonial magnification created an obsession with a lightning-fast attack at the expense of a more competitive system.

Save fantasy: work with a narrow colonial inheritance that magnified one Spëddish principle beyond the broader system that produced it.

### Kutré Lyn — retention

**Locked save-level premise**

Kutré's problem is retention, not a special technical-attacker export rule. Its small technical-school system loses talented volis generally; shallow supporting quality means hitters cannot assume the final ball will arrive cleanly, so the surviving program produces attackers with several solutions from the same approach.

**Tagline direction**

> Kutré Lyn's few technical schools continually lose promising volis across the border to Xérvu. Those who remain enter a narrow and unforgiving program built around a simple reality: the final ball will rarely arrive cleanly. Kutrén hitters learn several attacks from the same approach because they cannot afford to need the right set.

The migration system should create the Xérvu drain through ordinary geography, not through a Kutré-only rule or an Xérvu preference for Kutrén attackers.

### Zaitgaist — continuity / native tradition

**Locked tagline**

> Zaitgaist is too small to maintain a volleyball tradition; its minuscule programs simply emulate the winning teams. Each generation adds another style for coaches to attempt to reconcile and turn into a winning formula.

Save fantasy: reconcile inherited styles from successive cohorts; if Zaitgaist itself wins the Sixnet, the championship synthesis becomes the next cohort's formative reference rather than another foreign model.

## Migration / geography decisions already settled

- Do not add a Kutré-specific migration modifier. Preserve its existing departure probability.
- Geography belongs in destination weighting, not in the decision that a voli leaves.
- `REGION_ADJACENCY` remains the development/influence graph and must not become the migration-distance authority.
- Physical/access geography needs a separate region-level authority. Geography owns distances; migration owns the coefficients that translate those distances into career friction.
- Initial population generation measures from `home_region` to destination. Future live transfers measure from current `club_region` to destination. `home_region` remains cultural origin and is never mutated to simulate movement.
- Zaitgaist is an enclave, so the gameplay quantity should be called regional/access distance rather than treating every connection as a literal panel seam.
- A'ace and Ĭspayk remain intentionally absent from the development adjacency system. Their physical/transport accessibility still needs to be authored without normalizing them into cultural neighbours.
- Do not lock a production accessibility curve yet. A provisional probe may use a curve such as `1.00 / 0.62 / 0.34 / 0.17 / 0.08`, but the invariant is more important: geography should materially change destination shares while leaving total departure rates essentially unchanged.

## Open work

The major open design task is to validate that each regional fantasy produces a genuinely distinct recurring management loop rather than only different player attributes, tactical tendencies or prose. That task is intentionally deferred for now.

A smaller copy/data follow-up is to reconcile any approved historical adjective forms in the prose with the repo's canonical `DEMONYMS` table where the runtime gate requires exact canonical forms, without changing the approved regional concepts.
