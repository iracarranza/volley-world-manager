class_name CognitionCompiler
extends RefCounted

## Turns a resolved rally into the semantic cognition stream the presentation
## reads, at the resolver boundary and nowhere else.
##
## **Why a compiler rather than a renderer that reads events.** The evidence a
## cue needs is spread across `option_evaluation`, `primary_close_terms`,
## `setter_capability` and several `shadow_*` debug dictionaries whose shapes
## change whenever the system that emits them changes. A renderer that read them
## directly would be pinned to those shapes forever, and `docs/BACKLOG.md`
## records what that costs -- three separate presentation defects came from view
## code re-deriving a fact the resolver already held. Everything downstream of
## this file sees `PlayerCognitionCue` and nothing else.
##
## **The perception rule, which is the whole point.** A cue may contain only
## what its own player could perceive at the moment it starts. The resolver
## knows the attack lane before the blocker does; a blocker cue must therefore
## be built from what the blocker *did* -- where they closed to -- and from their
## own recognition delay, never from the lane the attack turned out to use.
## Authoritative truth grades an outcome only after the decision boundary it
## describes.

const CueModel := preload("res://scripts/models/player_cognition_cue.gd")
const TimelineModel := preload("res://scripts/simulation/cognition_timeline.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const SightlineModel := preload("res://scripts/simulation/player_sightline_system.gd")
const BallPresentationModel := preload("res://scripts/simulation/ball_presentation.gd")

## Priorities. A rally puts several true statements above one head at once and
## exactly one may be drawn, so the ladder is declared in one place rather than
## discovered from whichever cue happened to be appended last.
##
## Ordered by how much a viewer loses if it is the one dropped: a reaction to a
## finished action is the loudest thing a player does, a public call is the only
## cue another player can also see, and idle ball-tracking is the floor.
const PRIORITY_TRACKING: int = 0
const PRIORITY_SEARCHING: int = 10
const PRIORITY_RECOGNIZING: int = 20
const PRIORITY_DECIDING: int = 30
const PRIORITY_LOST_SIGHT: int = 40
const PRIORITY_COMMITTED: int = 50
const PRIORITY_CALLING: int = 60
const PRIORITY_REACTING: int = 70
## How long a wall wears its verdict.
##
## Sized against the window budget rather than picked: `run_window_budget_probe`
## puts a tenth of drawn flights under 0.42 s, and a mark that outlives the next
## contact is a mark still reporting the previous rally.
const BLOCK_VERDICT_SECONDS: float = 0.75

## How long a setter's eye rests on one option before moving to the next.
##
## Not a tuning knob so much as a legibility floor: the whole scan has to fit
## between the pass and the set, which the pass-height work measured at 0.63 s to
## 1.25 s, and three options at less than this are indistinguishable from a
## flicker. When the window is too short for every option the scan is truncated
## rather than compressed, because a setter who genuinely had no time did not
## look at every hitter either.
const OPTION_GLANCE_SECONDS: float = 0.16
## The setter has decided before they touch the ball. Contact is the execution,
## not the choice.
const SETTER_COMMIT_LEAD_SECONDS: float = 0.14
## A called ball is called on the approach, not at contact.
const HITTER_CALL_LEAD_SECONDS: float = 0.45
const HITTER_CALL_DURATION_SECONDS: float = 0.40
## How long before contact a server has chosen their target. A serve is the one
## contact in the sport taken entirely at the player's own pace, so the aim is
## settled well before the toss.
const SERVE_AIM_SECONDS: float = 0.70
## What misjudging an option costs the setter's confidence in it.
##
## `misread` is a **signed noise magnitude**, not a flag -- `stable_noise *
## (1 - judgment) * 0.22` -- and the first version of this file read it as a
## boolean. `bool()` of any non-zero float is true, so every option came out
## misread: measured, 182 of 182 across 120 rallies, and the badge would have
## shown every setter equally unsure of everything. A field that is always on
## carries no information, which is the §0 failure in the form the compiler is
## most exposed to.
##
## Read as a magnitude the term has a real range. Judgment sits at 0.855 for the
## slice's setter, so |misread| tops out at 1.0 * 0.145 * 0.22 = 0.032, and this
## multiplier turns a worst-case misjudgment into about a tenth of certainty --
## enough to separate two options, not enough to swamp the judgment it modifies.
const MISREAD_CERTAINTY_COST: float = 3.0


static func compile(result: Resource) -> Array:
	if result == null:
		return []
	var cues: Array = []
	var events: Array = result.events
	for index in range(events.size()):
		var event: Resource = events[index]
		match int(event.event_type):
			RallyEventModel.EventType.SERVE:
				_compile_serve(event, cues)
			RallyEventModel.EventType.RECEPTION:
				_compile_reception(events, index, cues)
			RallyEventModel.EventType.SET:
				_compile_second_contact(result, index, cues)
	_compile_ambient(result, events, cues)
	return TimelineModel.finalize(cues)


## Priority for the ambient layer. Below `PRIORITY_TRACKING`, so an ambient cue
## loses every overlap it is ever in -- which is the whole point of it. It is
## what a voli is doing when nothing more interesting is true of them, and the
## moment something is, that should win.
const PRIORITY_AMBIENT: int = -10

## How long an ambient glyph holds full strength before fading.
##
## An intention is formed at the start of a flight and is then simply being
## carried out, so the ink belongs at the front of the leg. Without this the
## court carries twelve glyphs at full strength for the whole rally and the
## markers that currently mean something -- `lost_sight` at 24 appearances in
## 47,000 cue-samples -- stop reading at all. See `docs/design/COGNITICONS.md`,
## "the risk this ask creates".
const AMBIENT_DWELL_SECONDS: float = 0.26


## One cue per off-ball voli per flight, from the reason their phase map already
## recorded.
##
## **This exists because the resolver decides *why* and then publishes only
## *where*.** Each phase map in `rally_simulator` branches on a real thing -- the
## serve-receive formation sorts passers from stagers from short cover,
## `_cover_phase_map` reads `attack_coverage_responsibility` -- and until those
## maps carried an `out_intents` dictionary alongside their coordinates, this
## layer would have had to infer an intention back out of a position, which is
## guessing about something already known.
##
## The cue spans the flight the targets describe: from the contact before it to
## the contact carrying them, because that is exactly the leg playback draws with
## those positions. Anything else would put the icon and the legs on different
## clocks.
## What the actor of a contact is doing, for the flight that ends at it.
##
## The one voli a phase map never mentions is the one playing the ball -- they
## are moved by their own `movement_target`, not by a shape -- so without this
## the busiest person on court is the only one with nothing above their head.
static func _actor_intent(event_type: int) -> StringName:
	match event_type:
		RallyEventModel.EventType.SERVE:
			return &"serving"
		RallyEventModel.EventType.RECEPTION:
			return &"receiving"
		RallyEventModel.EventType.SET:
			return &"setting"
		RallyEventModel.EventType.ATTACK:
			return &"approaching"
		RallyEventModel.EventType.BLOCK:
			return &"blocking"
		## A coverer is playing a ball up off the floor under pressure, which is
		## the posture this names. That they are on the attacking side is a fact
		## about the rally, not about what their body is doing.
		RallyEventModel.EventType.DIG, RallyEventModel.EventType.ATTACK_COVERAGE:
			return &"defending"
	return &"watching"


static func _compile_ambient(result: Resource, events: Array, cues: Array) -> void:
	## Who is on court, which the events alone cannot say. The resolver records
	## both sixes at the top of every rally for its own reasons; this is the
	## cheapest true answer available and it needs no new publication.
	var rosters := {
		&"home": result.initial_home_positions,
		&"opponent": result.initial_opponent_positions,
	}
	for index in range(events.size()):
		var event: Resource = events[index]
		var previous := _previous_contact(events, index)
		var to_time := float(event.metadata.get("event_time", 0.0))
		var from_time := to_time
		if previous != null:
			from_time = float(previous.metadata.get("event_time", 0.0))
		elif int(event.event_type) == RallyEventModel.EventType.SERVE:
			## The one contact with nothing in front of it. The rest of the cue
			## stream already starts before the serve -- `_compile_serve` opens
			## `SERVE_AIM_SECONDS` early -- so without this the pre-serve window
			## is the one moment eleven volis are blank, which is exactly the
			## kind of edge a continuity figure hides in: it measured 5.82 of six
			## rather than six, and the missing 3% was all in one place.
			from_time = maxf(to_time - SERVE_AIM_SECONDS, 0.0)
		else:
			continue
		if to_time - from_time < CueModel.MINIMUM_DURATION_SECONDS:
			continue
		var actor_id := int(event.actor_id)
		for side in [&"home", &"opponent"]:
			var published: Dictionary = event.metadata.get(
				"%s_phase_intents" % side, {}
			)
			## Every voli on this side, not only the ones a shape placed.
			##
			## **`watching` is why the vocabulary has a term for nothing in
			## particular.** The alternative to filling the gap is either a blank
			## voli -- which is the 0.75-of-six the layer started at -- or an
			## invented intention, which is the drifting-volis defect moved onto
			## the icons. Saying "watching" is the only one of the three that is
			## both continuous and true.
			var intents := {}
			for raw_player_id in rosters.get(side, {}):
				intents[int(raw_player_id)] = {
					"intent": &"watching", "progress": 0.0,
				}
			if actor_id >= 0 and intents.has(actor_id):
				intents[actor_id] = {
					"intent": _actor_intent(int(event.event_type)),
					"progress": 0.0,
				}
			for raw_player_id in published:
				intents[int(raw_player_id)] = published[raw_player_id]
			for raw_player_id in intents:
				var entry: Dictionary = intents[raw_player_id]
				var cue := CueModel.create(
					int(raw_player_id), side, event.sequence,
					from_time, to_time, &"committed", &"during",
				)
				cue.intent = StringName(str(entry.get("intent", "watching")))
				cue.progress = clampf(float(entry.get("progress", 0.0)), 0.0, 1.0)
				cue.attention_kind = &"ball"
				## Tracking, not staring: an off-ball voli follows the ball while
				## they run. The glyph fades on its own, so the hold describes the
				## eyes and the dwell describes the ink.
				cue.attention_hold = &"track"
				cue.dwell_seconds = minf(
					AMBIENT_DWELL_SECONDS, maxf(to_time - from_time, 0.0)
				)
				## An intention is not a belief about an outcome, so it carries no
				## confidence. Certainty on an ambient cue would be the renderer's
				## invitation to draw a voli looking sure about a rally they have
				## not seen yet.
				cue.certainty = 0.0
				cue.urgency = 0.0
				cue.audience = &"observable"
				cue.priority = PRIORITY_AMBIENT
				cues.append(cue)


## The server picking a target, where one was actually picked.
##
## Gated on the aim evidence existing rather than emitted for every serve: a
## serve whose target the resolver did not record is a serve whose intent this
## layer does not know, and inventing a look at a zone would be exactly the kind
## of decorative cue the whole design is trying not to be.
##
## `target_radius_meters` is the server's chosen *specificity* -- how small a
## patch they aimed at, decided before execution scatter -- so it reads directly
## as how sure the cue should look.
##
## **This gate read `target_radius_m` and the resolver has always written
## `target_radius_meters`, so no serve cue has ever been emitted -- on any
## serve, on either side, since this was written.** The guard did its job
## perfectly and the key it guarded on did not exist, which is a reader with no
## writer and is silent by construction. It surfaced only when the new `intent`
## vocabulary was measured over 200 rallies and `serving` came back at zero
## against every other intent being populated, which is the argument for closed
## vocabularies whose mix gets measured.
static func _compile_serve(serve_event: Resource, cues: Array) -> void:
	var metadata: Dictionary = serve_event.metadata
	if not metadata.has("target_radius_meters"):
		return
	var server_id := int(serve_event.actor_id)
	if server_id < 0:
		return
	var contact_time := float(metadata.get("event_time", 0.0))
	var starts_at := maxf(contact_time - SERVE_AIM_SECONDS, 0.0)
	var cue := CueModel.create(
		server_id, StringName(str(metadata.get("side", "home"))),
		serve_event.sequence, starts_at, contact_time, &"deciding", &"before",
	)
	cue.attention_kind = &"position"
	cue.intent = &"serving"
	cue.as_held(true)
	cue.attention_position = Vector2(serve_event.end_position)
	## A tight aim is a confident one. The radius runs 1.80 m for a server
	## picking a half of the court down to 0.22 m for one picking a seam, so it
	## is inverted onto certainty across its own stated range rather than a
	## guessed one.
	var radius := float(metadata.get("target_radius_meters", 1.0))
	cue.certainty = clampf(inverse_lerp(1.80, 0.22, radius), 0.0, 1.0)
	cue.urgency = 0.35
	cue.audience = &"observable"
	cue.priority = PRIORITY_DECIDING
	cues.append(cue)


## The passer claiming the ball, and whether they were ever going to reach it.
##
## `arrival_margin` is the whole cue: positive means they were waiting for it,
## negative means the serve beat them there. That is a real read -- it is the
## same quantity the vocabulary names a Platform dime and a Shank from -- so this
## is a place a cue is earned rather than added for coverage.
static func _compile_reception(
	events: Array, reception_index: int, cues: Array
) -> void:
	var reception: Resource = events[reception_index]
	var metadata: Dictionary = reception.metadata
	if not metadata.has("arrival_margin") and not metadata.has("arrival"):
		return
	var receiver_id := int(reception.actor_id)
	if receiver_id < 0:
		return
	var contact_time := float(metadata.get("event_time", 0.0))
	var serve_time := 0.0
	for index in range(reception_index - 1, -1, -1):
		var candidate: Resource = events[index]
		if int(candidate.event_type) == RallyEventModel.EventType.SERVE:
			serve_time = float(candidate.metadata.get("event_time", 0.0))
			break
	if contact_time - serve_time < CueModel.MINIMUM_DURATION_SECONDS:
		return
	var margin := float(metadata.get("arrival_margin", 0.0))
	var cue := CueModel.create(
		receiver_id, StringName(str(metadata.get("side", "home"))),
		reception.sequence, serve_time, contact_time,
		&"committed" if margin >= 0.0 else &"reacting", &"before",
	)
	cue.attention_kind = &"ball"
	cue.intent = &"receiving"
	cue.as_held()
	## Comfort, on the margin's own scale: a quarter of a second early is a
	## passer in position, and anything negative is one still travelling.
	cue.certainty = clampf(inverse_lerp(-0.25, 0.25, margin), 0.0, 1.0)
	cue.urgency = clampf(1.0 - cue.certainty, 0.15, 1.0)
	if margin < -0.05:
		cue.punctuation = "!"
	cue.audience = &"observable"
	cue.priority = PRIORITY_COMMITTED if margin >= 0.0 else PRIORITY_REACTING
	cues.append(cue)


## The set -> attack -> block slice, compiled from one SET event outward.
static func _compile_second_contact(
	result: Resource, set_index: int, cues: Array
) -> void:
	var events: Array = result.events
	var set_event: Resource = events[set_index]
	var metadata: Dictionary = set_event.metadata
	var side := StringName(str(metadata.get("side", "home")))
	var set_time := float(metadata.get("event_time", 0.0))
	var previous := _previous_contact(events, set_index)
	## The setter's window is the pass they are watching arrive. `SET_DECISION`
	## is deliberately not a playback beat, so the thinking has to live here or
	## it has nowhere to live at all.
	var window_start := float(previous.metadata.get("event_time", 0.0)) \
		if previous != null else maxf(set_time - 0.9, 0.0)
	var evaluation := _option_evaluation(events, set_index)
	_compile_setter_scan(set_event, evaluation, side, window_start, set_time, cues)

	var attack_event := _next_of_type(
		events, set_index, RallyEventModel.EventType.ATTACK
	)
	if attack_event != null:
		_compile_hitter_call(
			set_event, attack_event, evaluation, side, set_time, cues
		)
	var block_event := _next_of_type(
		events, set_index, RallyEventModel.EventType.BLOCK
	)
	if block_event != null:
		_compile_block_read(set_event, block_event, set_time, cues)
	if attack_event != null:
		_compile_sightlines(
			result, events, set_index, attack_event, block_event, cues
		)
		_compile_reactions(result, events, set_index, attack_event, cues)


## The setter's eyes move among the options they actually evaluated.
##
## `option_evaluation.options` is the setter's own scored list -- it contains a
## `misread` flag and a per-option `judgment`, which is exactly the evidence that
## makes this perception rather than narration. The order is the resolver's
## score order, so the eye lands on the best option last and the badge reads as
## a decision being reached rather than a list being recited.
## Where the setter's own option list lives, which is not one place.
##
## The home side publishes `option_evaluation` on its `SET_DECISION` event and
## the opponent publishes it on the `SET` event itself. That asymmetry is real
## and is recorded in `docs/BACKLOG.md`; reading both here is the cheap half of
## the fix, and doing it in the compiler means neither renderer ever learns that
## the two sides disagree.
##
## Searching backwards only as far as the previous contact, so a set never
## inherits the option list of the possession before it.
static func _option_evaluation(events: Array, set_index: int) -> Dictionary:
	var on_set: Dictionary = (events[set_index] as Resource).metadata.get(
		"option_evaluation", {}
	)
	if not on_set.is_empty():
		return on_set
	for candidate_index in range(set_index - 1, -1, -1):
		var candidate: Resource = events[candidate_index]
		if int(candidate.event_type) == RallyEventModel.EventType.SET_DECISION:
			return candidate.metadata.get("option_evaluation", {})
		if int(candidate.event_type) != RallyEventModel.EventType.POINT:
			break
	return {}


static func _compile_setter_scan(
	set_event: Resource,
	evaluation: Dictionary,
	side: StringName,
	window_start: float,
	set_time: float,
	cues: Array,
) -> void:
	var setter_id := int(set_event.actor_id)
	if setter_id < 0:
		return
	var options: Array = evaluation.get("options", [])
	var commit_at := maxf(set_time - SETTER_COMMIT_LEAD_SECONDS, window_start)
	var scan_window := maxf(commit_at - window_start, 0.0)
	if options.is_empty() or scan_window < CueModel.MINIMUM_DURATION_SECONDS:
		## No options recorded, or no time to look at them. The setter is still
		## doing something -- watching the ball come -- and saying so is more
		## honest than an empty head.
		var watching := CueModel.create(
			setter_id, side, set_event.sequence, window_start, set_time,
			&"searching", &"before",
		)
		watching.attention_kind = &"ball"
		watching.intent = &"setting"
		watching.as_held()
		watching.certainty = 0.4
		watching.urgency = 0.6
		watching.priority = PRIORITY_TRACKING
		watching.audience = &"observable"
		cues.append(watching)
		return

	## Worst option first so the scan ends on the ball they choose. The stored
	## order is best-first, so this walks it backwards.
	var glanced: Array = []
	for index in range(options.size() - 1, -1, -1):
		glanced.append(options[index])
	var affordable := int(floor(scan_window / OPTION_GLANCE_SECONDS))
	if affordable < 1:
		affordable = 1
	## Truncated from the front, keeping the last looks. A setter short of time
	## does not scan faster, they scan less -- and what they skip is the option
	## they were least interested in.
	if glanced.size() > affordable:
		glanced = glanced.slice(glanced.size() - affordable)
	var glance_length := scan_window / float(glanced.size())
	for index in range(glanced.size()):
		var option: Dictionary = glanced[index]
		var starts_at := window_start + glance_length * float(index)
		var cue := CueModel.create(
			setter_id, side, set_event.sequence,
			starts_at, starts_at + glance_length, &"searching", &"before",
		)
		cue.attention_kind = &"hitter"
		cue.intent = &"setting"
		## A setter reading four hitters does not stare at each of them. Each
		## option is a look that is answered and released, which is exactly
		## what a glance is for.
		cue.as_glance()
		cue.attention_player_id = int(option.get("player_id", -1))
		## The setter's own read of this option, not the option's real value.
		cue.certainty = clampf(
			float(option.get("judgment", 0.5))
				- absf(float(option.get("misread", 0.0))) * MISREAD_CERTAINTY_COST,
			0.0, 1.0,
		)
		cue.urgency = clampf(float(option.get("lateness", 0.0)) + 0.45, 0.0, 1.0)
		## A weighing is not visible from the stands. The tactical board may show
		## it because the board is a coaching instrument; the gym camera may not.
		cue.audience = &"private"
		cue.priority = PRIORITY_SEARCHING
		cues.append(cue)

	var chosen := int(evaluation.get("chosen_player_id", -1))
	var decision := CueModel.create(
		setter_id, side, set_event.sequence, commit_at, set_time,
		&"deciding", &"before",
	)
	decision.attention_kind = &"hitter" if chosen >= 0 else &"ball"
	decision.intent = &"setting"
	decision.as_held()
	decision.attention_player_id = chosen
	decision.certainty = _decision_confidence(options)
	decision.urgency = 0.75
	decision.punctuation = "!" if decision.certainty >= 0.66 else "?"
	decision.audience = &"observable"
	decision.priority = PRIORITY_DECIDING
	cues.append(decision)


## How sure the setter was, from the gap between their top two options.
##
## A setter with one obviously-best ball is decisive; one choosing between two
## equal balls is not, whatever either is worth. This is the quantity the review
## packet asked to have measured before anything leaned on it, so it is derived
## from the scores rather than from a constant, and a single-option list is
## maximally certain by construction rather than by assumption.
static func _decision_confidence(options: Array) -> float:
	if options.size() < 2:
		return 0.85
	var best := float((options[0] as Dictionary).get("score", 0.0))
	var runner_up := float((options[1] as Dictionary).get("score", 0.0))
	var gap := maxf(best - runner_up, 0.0)
	return clampf(0.42 + gap * 1.8, 0.0, 1.0)


## The hitter who was chosen, and could actually get there, calls for it.
##
## Public: this is the one cue another player is meant to be able to see, which
## is what makes it a *call* rather than a thought. The gate on `lateness`
## matters -- a hitter who cannot reach their approach does not call for the
## ball, and showing them shouting for it would be the clearest possible sign
## the layer is decorative.
static func _compile_hitter_call(
	set_event: Resource,
	attack_event: Resource,
	evaluation: Dictionary,
	side: StringName,
	set_time: float,
	cues: Array,
) -> void:
	var hitter_id := int(attack_event.actor_id)
	if hitter_id < 0:
		return
	var chosen_option := _option_for(evaluation, hitter_id)
	var responsible := int(evaluation.get("chosen_player_id", -1)) == hitter_id
	var lateness := float(chosen_option.get("lateness", 0.0))
	var available := lateness <= 0.0
	if not responsible or not available:
		return
	var starts_at := maxf(set_time - HITTER_CALL_LEAD_SECONDS, 0.0)
	var cue := CueModel.create(
		hitter_id, side, attack_event.sequence,
		starts_at, starts_at + HITTER_CALL_DURATION_SECONDS,
		&"calling", &"before",
	)
	cue.attention_kind = &"setter"
	cue.intent = &"preparing_attack"
	## A hitter calling looks at the setter and keeps looking: the call is not
	## answered until the ball leaves the hands.
	cue.as_held(true)
	cue.attention_player_id = int(set_event.actor_id)
	cue.certainty = clampf(float(chosen_option.get("judgment", 0.6)), 0.0, 1.0)
	cue.urgency = 0.9
	cue.punctuation = "!!"
	cue.affect = &"confident"
	cue.affect_intensity = 0.6
	cue.audience = &"public"
	cue.priority = PRIORITY_CALLING
	cues.append(cue)


## Each blocker recognises the play at their own moment, and commits to where
## they went.
##
## The staggering is real rather than staged: `reaction_delay` is
## `lerp(0.34, 0.12, anticipation)` per blocker and already lives in that
## blocker's own close terms, so two blockers on one wall recognise up to 0.22 s
## apart purely from the attribute.
##
## The believed lane is `closed_net_x` -- where that blocker actually travelled
## to. Using the attack's lane would be truth leakage; using where they *went*
## is the opposite, because a blocker who read it wrong went to the wrong place
## and the cue then points at the wrong place, which is the entire behaviour
## worth showing.
static func _compile_block_read(
	set_event: Resource,
	block_event: Resource,
	set_time: float,
	cues: Array,
) -> void:
	var metadata: Dictionary = block_event.metadata
	var side := StringName(str(metadata.get("side", "home")))
	var contact_time := float(metadata.get("event_time", set_time + 0.6))
	var blockers: Array = [
		{
			"id": int(block_event.actor_id),
			"terms": Dictionary(metadata.get("primary_close_terms", {})),
			"close": float(metadata.get("primary_close", 0.0)),
			## Where the wall actually stood. `primary_position` is published on
			## every block event on both sides and is the blocker's own travelled
			## position, which is why it can stand in for their belief.
			"at": Vector2(metadata.get("primary_position", Vector2(0.5, 0.5))),
		},
	]
	var assist_id := int(metadata.get("assist_id", -1))
	if assist_id >= 0:
		blockers.append({
			"id": assist_id,
			"terms": Dictionary(metadata.get("assist_close_terms", {})),
			"close": float(metadata.get("assist_close", 0.0)),
			"at": Vector2(metadata.get("assist_position", Vector2(0.5, 0.5))),
		})
	## One verdict for the wall, not one per blocker. A block is a joint action
	## and its outcome is a joint outcome -- the assist did not have a different
	## rally from the primary, and giving them separate answers would show two
	## volis on the same wall disagreeing about what just happened to them.
	var verdict := BlockVerdict.of(
		str(metadata.get("block_intent", "Balanced")),
		str(metadata.get("outcome", "")),
		str(metadata.get("block_hands", "neutral")),
		str(metadata.get("block_miss_reason", "")),
	)
	for entry in blockers:
		var blocker_id := int(entry.id)
		if blocker_id < 0:
			continue
		var terms: Dictionary = entry.terms
		var reaction := float(terms.get("reaction_delay", 0.22))
		var recognises_at := set_time + reaction
		## Before their own recognition the blocker is reading the setter, not
		## the hitter. Two blockers on one wall therefore attend to different
		## things at the same instant, which is the first thing the acceptance
		## sequence asks to see.
		var reading := CueModel.create(
			blocker_id, side, block_event.sequence,
			maxf(set_time - 0.30, 0.0), recognises_at, &"searching", &"before",
		)
		reading.attention_kind = &"setter"
		reading.intent = &"blocking"
		## Trained on the setter and not released -- the vigil the glance is
		## defined against.
		reading.as_held(true)
		reading.attention_player_id = int(set_event.actor_id)
		reading.certainty = 0.35
		reading.urgency = 0.55
		reading.priority = PRIORITY_SEARCHING
		reading.audience = &"observable"
		cues.append(reading)

		var closed := clampf(float(entry.close), 0.0, 1.0)
		var recognising := CueModel.create(
			blocker_id, side, block_event.sequence,
			recognises_at, minf(recognises_at + 0.26, contact_time),
			&"recognizing", &"before",
		)
		recognising.attention_kind = &"position"
		recognising.intent = &"blocking"
		recognising.as_held()
		recognising.attention_position = Vector2(entry.at)
		recognising.certainty = closed
		recognising.urgency = 0.8
		recognising.punctuation = "!" if closed >= 0.7 else "?"
		recognising.priority = PRIORITY_RECOGNIZING
		recognising.audience = &"observable"
		cues.append(recognising)

		var committed := CueModel.create(
			blocker_id, side, block_event.sequence,
			minf(recognises_at + 0.26, contact_time), contact_time,
			&"committed", &"during",
		)
		committed.attention_kind = &"position"
		committed.intent = &"blocking"
		committed.as_held(true)
		committed.attention_position = Vector2(entry.at)
		committed.certainty = closed
		committed.urgency = 0.95
		committed.priority = PRIORITY_COMMITTED
		committed.audience = &"observable"
		cues.append(committed)

		## **And what the wall earned**, which is the one thing the block layer
		## could not say before.
		##
		## A shield does not break because the ball got past it. It breaks when
		## the block meant to *stop* the ball and was wrong about where it was
		## going -- kill hands, beaten around the edge. A funnel that channelled
		## the swing into a waiting digger did exactly what it set out to, and a
		## blocker who was in the right place and got hit over the top was
		## out-jumped rather than out-read. `BlockVerdict` holds that judgement;
		## this only carries it into the cue vocabulary.
		##
		## Emitted only when there is something to say. A neutral verdict is the
		## ordinary case and already has a mark -- the plain shield the
		## `committed` cue above is drawing -- so adding a cue to assert it would
		## be 62% of blocks spending a slot on "as expected".
		if verdict != "plain":
			var resolved := CueModel.create(
				blocker_id, side, block_event.sequence,
				contact_time, contact_time + BLOCK_VERDICT_SECONDS,
				&"reacting", &"after",
			)
			resolved.attention_kind = &"ball"
			## Still `blocking`, so what breaks is the wall rather than some
			## generic reaction mark. The variant is the whole statement here.
			resolved.intent = &"blocking"
			resolved.as_held()
			resolved.affect = BlockVerdict.affect_for(verdict)
			resolved.affect_intensity = clampf(closed, 0.0, 1.0)
			resolved.certainty = 1.0
			resolved.trend = 0.5 if verdict == "ascendant" else -0.5
			resolved.outcome_name = str(metadata.get("outcome", ""))
			resolved.priority = PRIORITY_REACTING
			resolved.audience = &"observable"
			cues.append(resolved)


static func _option_for(evaluation: Dictionary, player_id: int) -> Dictionary:
	for raw_option in Array(evaluation.get("options", [])):
		var option: Dictionary = raw_option
		if int(option.get("player_id", -1)) == player_id:
			return option
	return {}


static func _previous_contact(events: Array, index: int) -> Resource:
	for candidate_index in range(index - 1, -1, -1):
		var candidate: Resource = events[candidate_index]
		var event_type := int(candidate.event_type)
		if event_type != RallyEventModel.EventType.SET_DECISION \
				and event_type != RallyEventModel.EventType.POINT:
			return candidate
	return null


## The next event of a type, stopping at the next second contact so a set never
## reaches past its own three-contact possession into the following one.
static func _next_of_type(events: Array, index: int, event_type: int) -> Resource:
	for candidate_index in range(index + 1, events.size()):
		var candidate: Resource = events[candidate_index]
		if int(candidate.event_type) == event_type:
			return candidate
		if int(candidate.event_type) == RallyEventModel.EventType.SET \
				or int(candidate.event_type) == RallyEventModel.EventType.POINT:
			break
	return null


## The event that touched the ball next, which is where a drawn flight stops.
##
## Kept next to its one caller rather than shared: `match_screen` walks the same
## events with an index it already has, and a second copy of that walk in a
## general helper would be a second thing to keep in step.
static func _next_contact(events: Array, after: Resource) -> Resource:
	var seen := false
	for candidate in events:
		if candidate == after:
			seen = true
			continue
		if not seen:
			continue
		if int(candidate.actor_id) >= 0:
			return candidate
	return null


## What the defenders behind the wall could actually see of the swing.
##
## Geometry, not a block bonus: `PlayerSightlineSystem` casts each defender's own
## ray at the sampled ball against the blockers who actually closed, so two
## defenders standing behind one wall get different answers. That is the whole
## reason this is worth showing -- a viewer can see *why* the dig was late.
##
## Emitted as perception rather than as a rendering flag. `visibility` is a field
## on the cue; the badge decides that an occluded eye is closed and a partially
## obscured one is narrowed, and neither renderer ever sees a ray.
static func _compile_sightlines(
	result: Resource,
	events: Array,
	set_index: int,
	attack_event: Resource,
	block_event: Resource,
	cues: Array,
) -> void:
	if block_event == null:
		return
	## **A block that touched the ball is not a block that hid it.** When the wall
	## makes contact the swing's flight *ends* at the hands, so its last samples
	## are behind them by construction and every blocked swing would be scored as
	## a defender losing sight -- measured, 87.5% through the flight was the
	## median moment the wall was credited with taking the ball, which is another
	## way of saying "at the block". What the defender then plays is the
	## deflection, a different flight, one the wall is behind rather than in front
	## of. There is a BLOCK event to narrate that, and nothing for this cue to
	## say.
	if bool(block_event.success):
		return
	var raw: Dictionary = attack_event.metadata.get("outgoing_trajectory", {})
	if raw.is_empty():
		return
	## **The drawn flight, not the resolver's stub.** A raw `outgoing_trajectory`
	## carries `start_height_meters` and `end_height_meters` at 1.0 -- not because
	## the ball is a metre off the floor at both ends but because
	## `_ball_trajectory` never passes either one to `BallTrajectory.create` and
	## 1.0 is that argument's default. Every trajectory in the game is like this;
	## the heights only become real in `BallPresentation.display_trajectory`,
	## which reads them off the two bodies that touched the ball.
	##
	## Which matters here more than anywhere, because the whole occlusion test is
	## a question about height: does the ray to the ball pass over the blocker's
	## hands or under them. Asked of a flat one-metre ball it was being asked
	## about a ball that does not exist, and a spike passing *above* the wall --
	## the one case where a defender plainly can see it -- could not answer
	## differently from one passing through it.
	##
	## Terminating at the next contact comes free with the same call and is also
	## correct: a swing that gets dug ends at the digger, not at the floor it was
	## aimed at, and the time a defender had is measured against the flight they
	## actually played. Blocks are already excluded above, so the contact this
	## finds is the dig itself.
	var trajectory := BallPresentationModel.display_trajectory(
		attack_event, _next_contact(events, attack_event), raw,
		result.player_physical_profiles,
	)
	## **Floor dig only, and it used to be able to find the wrong contact.** This
	## is the occlusion test -- whether the defender could see the swing past the
	## blocker's hands -- and it needs the voli watching from *behind the block*.
	## Attack coverage stands on the hitter's side with no wall between them and
	## the ball, so a coverage contact arriving first would have been used as the
	## observer for a sightline that does not exist. The comment above already
	## said "the contact this finds is the dig itself"; now the type says it too.
	var defence := _next_of_type(
		events, set_index, RallyEventModel.EventType.DIG
	)
	if defence == null:
		return
	var defender_id := int(defence.actor_id)
	if defender_id < 0:
		return
	## Where they stood when the swing happened, not where the dig ended up.
	## `movement_start` is the position the resolver moved them *from*, which is
	## the only one that was true while the ball was in the air.
	var observer := Vector2(defence.metadata.get(
		"movement_start", defence.start_position
	))
	## Both heights from the two bodies involved, because both were placeholders.
	## The eye height parameter has existed since the system was written and no
	## caller ever filled it, so every defender in the game watched from 1.72 m;
	## the blocker's reach was worse, since the event it was read from never
	## carried it. A tall middle now genuinely hides more of the court from a
	## short libero than from another middle, which is the difference the geometry
	## was supposed to be making all along.
	var profiles: Dictionary = result.player_physical_profiles
	var observer_profile: Dictionary = profiles.get(defender_id, {})
	var window := SightlineModel.occlusion_window(
		observer, trajectory, block_event,
		{
			## Eyes sit a hand's width below the crown, and the profile carries the
			## crown. Any player-independent number here would have been the 1.72 m
			## this replaces.
			"eye_height_meters": float(observer_profile.get("height_cm", 188.0))
				/ 100.0 - 0.10,
		},
		BallPresentationModel.contact_height(block_event, profiles),
	)
	var visibility := SightlineModel.visibility_for(window)
	if visibility == &"visible":
		return
	var side := StringName(str(defence.metadata.get("side", "opponent")))
	var hidden_from := float(window.get("starts_at", 0.0))
	var reacquired := float(window.get("reacquired_at", hidden_from + 0.1))
	var lost := CueModel.create(
		defender_id, side, attack_event.sequence,
		hidden_from, reacquired, &"lost_sight", &"during",
	)
	lost.attention_kind = &"ball"
	lost.intent = &"defending"
	lost.as_held()
	lost.visibility = visibility
	## Certainty falls with how little time the wall left them, on the same scale
	## `visibility_for` classifies with. It used to fall with the share of the
	## flight that went missing, which is a different quantity and disagreed with
	## the verdict drawn beside it: a swing could be marked occluded and confident
	## at once. One number, read once.
	lost.certainty = clampf(inverse_lerp(
		SightlineModel.QUICK_REACTION_SECONDS,
		SightlineModel.SLOW_REACTION_SECONDS,
		float(window.get("seen_for_seconds", 0.0)),
	), 0.0, 1.0)
	lost.urgency = 0.85
	lost.punctuation = "...?"
	lost.priority = PRIORITY_LOST_SIGHT
	lost.audience = &"observable"
	cues.append(lost)

	## Seeing it again is its own moment, and it is the one the dig is made from.
	var contact_time := float(defence.metadata.get("event_time", reacquired + 0.1))
	if contact_time <= reacquired:
		return
	var found := CueModel.create(
		defender_id, side, attack_event.sequence,
		reacquired, contact_time, &"reacting", &"during",
	)
	found.attention_kind = &"ball"
	found.intent = &"defending"
	found.as_held()
	found.visibility = &"visible"
	found.certainty = 0.6
	found.urgency = 1.0
	found.punctuation = "!"
	found.priority = PRIORITY_REACTING
	found.audience = &"observable"
	cues.append(found)


## What the decisive actor and the people around them feel about what just
## happened.
##
## **Ephemeral, and it changes nothing.** `match_confidence` remains the
## post-point system in `game_manager.gd`; nothing here writes to a player. A
## reaction is a replay artefact, which is exactly why it is allowed to read the
## authoritative outcome: it starts *after* the action it is reacting to, so
## there is no decision left for it to leak into.
##
## Pre-rally confidence and composure decide how far a player swings. A composed
## voli registers the same failure with a smaller face than a volatile one, which
## is the difference the attribute exists to make and which nothing in the
## presentation showed before.
static func _compile_reactions(
	result: Resource,
	events: Array,
	set_index: int,
	attack_event: Resource,
	cues: Array,
) -> void:
	var outcome := str(attack_event.metadata.get("action_outcome", ""))
	if outcome.is_empty() or not bool(attack_event.metadata.get("named_action", false)):
		return
	var notability := float(attack_event.metadata.get("action_notability", 0.0))
	var side := StringName(str(attack_event.metadata.get("side", "home")))
	var actor_id := int(attack_event.actor_id)
	if actor_id < 0:
		return
	var starts_at := float(attack_event.metadata.get("event_time", 0.0)) + 0.18
	var went_well := bool(attack_event.success) \
		and not bool(attack_event.metadata.get("attack_missed", false))
	var actor := CueModel.create(
		actor_id, side, attack_event.sequence,
		starts_at, starts_at + 0.9, &"reacting", &"after",
	)
	actor.attention_kind = &"none"
	actor.intent = &"watching"
	actor.as_held()
	actor.affect = &"pleased" if went_well else &"upset"
	actor.affect_intensity = clampf(notability, 0.0, 1.0)
	actor.trend = 0.6 if went_well else -0.6
	actor.certainty = 1.0
	actor.urgency = clampf(notability, 0.0, 1.0)
	actor.punctuation = "!" if went_well else "!?"
	actor.outcome_name = outcome
	actor.priority = PRIORITY_REACTING
	actor.audience = &"public"
	cues.append(actor)

	## The teammate who called for the ball and did not get to hit it, or the
	## setter who fed the swing, reads the same moment differently -- flatter,
	## and without the punctuation. A whole side reacting identically is what
	## makes a crowd of avatars look like one avatar.
	var set_event: Resource = events[set_index]
	var setter_id := int(set_event.actor_id)
	if setter_id < 0 or setter_id == actor_id:
		return
	var teammate := CueModel.create(
		setter_id, side, attack_event.sequence,
		starts_at + 0.10, starts_at + 0.80, &"reacting", &"after",
	)
	teammate.attention_kind = &"teammate"
	teammate.intent = &"watching"
	## Checking on somebody after a point is a look, not a vigil.
	teammate.as_glance(0.30)
	teammate.attention_player_id = actor_id
	teammate.affect = &"pleased" if went_well else &"sad"
	teammate.affect_intensity = clampf(notability * 0.6, 0.0, 1.0)
	teammate.trend = 0.3 if went_well else -0.3
	teammate.certainty = 0.9
	teammate.urgency = 0.4
	teammate.outcome_name = outcome
	teammate.priority = PRIORITY_REACTING - 5
	teammate.audience = &"observable"
	cues.append(teammate)
