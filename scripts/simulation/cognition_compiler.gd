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
		if int(event.event_type) != RallyEventModel.EventType.SET:
			continue
		_compile_second_contact(result, index, cues)
	return TimelineModel.finalize(cues)


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
		_compile_sightlines(events, set_index, attack_event, block_event, cues)
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
		committed.attention_position = Vector2(entry.at)
		committed.certainty = closed
		committed.urgency = 0.95
		committed.priority = PRIORITY_COMMITTED
		committed.audience = &"observable"
		cues.append(committed)


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
	events: Array,
	set_index: int,
	attack_event: Resource,
	block_event: Resource,
	cues: Array,
) -> void:
	if block_event == null:
		return
	var trajectory: Dictionary = attack_event.metadata.get("outgoing_trajectory", {})
	if trajectory.is_empty():
		return
	var defence := _next_of_type(
		events, set_index, RallyEventModel.EventType.DEFENSE
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
	var window := SightlineModel.occlusion_window(
		observer, trajectory, block_event
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
	lost.visibility = visibility
	## Certainty falls with how much of the flight went missing, which is the
	## quantity the geometry actually measured rather than a second guess at it.
	lost.certainty = clampf(
		1.0 - float(window.get("hidden_fraction", 0.0)) * 1.4, 0.0, 1.0
	)
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
