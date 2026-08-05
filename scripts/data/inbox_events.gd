class_name InboxEvents
extends RefCounted

## What arrives in the inbox, and what a voli says about it.
##
## An inbox event has **two voices, and they are not the same text.**
##
## The *report* is the manager's view: what happened, what it probably means,
## and what can be done about it. It names the mechanic and the cost of each
## option, because that is the decision being asked for.
##
## The *utterance* is the voli's view, and it is deliberately vaguer, softer and
## shorter -- "the team food isn't treating me so well" against "reports a
## potential allergy to Xérvyan paste". A voli does not know they have an
## allergy; they know they feel bad after dinner. Keeping the two apart is the
## whole unreliable-self-report design (`docs/design/CLUB_LIFE.md`) made
## visible in one card: the complaint is a *signal*, and the report is what your
## staff made of it.
##
## Writing one text and using it twice would collapse that. It would also make
## every voli sound like a dossier, which is the register this game is furthest
## from.
##
## Nothing here resolves. The options are laid out with their real costs so the
## shape of the decision can be judged before any of it is built.

## An option a manager can take. `cost` is the sentence that makes it a
## decision rather than a free choice -- every one of these has to hurt
## somewhere, or the card is a notification with buttons on it.
const ALLERGY_OPTIONS: Array = [
	{
		"label": "Cook them separately",
		"cost": "Spends a week of the chef's attention, and a little cohesion.",
	},
	{
		"label": "Send them to the physio",
		"cost": "Costs nothing now. You find out whether it is real, eventually.",
	},
	{
		"label": "Change the whole team's diet",
		"cost": "Fixes one voli and unsettles everyone whose favourite it was.",
	},
]

## The seeded inbox. Sample data, shown to judge the layout and the two voices.
##
## `speaker_slot` indexes the roster rather than naming a voli, because the
## roster is generated and a hardcoded name would belong to nobody.
const SAMPLE_EVENTS: Array = [
	{
		"id": "allergy_xervyan",
		"category": "Care",
		"subject": "Possible allergy at the table",
		"speaker_slot": 3,
		## The allergy card wants an Aubergine specifically -- the event is about
		## a voli's own body, so who is on the card is part of the content rather
		## than whichever roster slot happened to land here. Falls back to the
		## slot when nobody on the roster matches.
		"prefer_produce": "Aubergine",
		"expression": "worried",
		## What the voli says. Short, unsure, and about how they feel rather than
		## about what is happening to them.
		"utterance": "the team food isn't treating me so well...",
		## What your staff make of it. This is the text that names the mechanic.
		"report": "%s reports that they can no longer eat the Xérvyan paste in "
			+ "the team's meals -- a possible voli allergy. Nobody has confirmed "
			+ "it, including them.",
		"options": ALLERGY_OPTIONS,
	},
	{
		"id": "sponsor_offer",
		"category": "Sponsorship",
		"subject": "An organisation has approached a voli",
		"speaker_slot": 1,
		"expression": "devious",
		"utterance": "someone wants to put my face on a crate",
		"report": "Harbour Produce Co. have approached %s directly, not the "
			+ "club. They will pay while the terms hold: five consecutive "
			+ "fixtures played, starting or not.",
		"options": [
			{
				"label": "Let them take it",
				"cost": "Their minutes become a commitment you did not make.",
			},
			{
				"label": "Turn it down for them",
				"cost": "Free, and they will remember that you did.",
			},
		],
	},
	{
		"id": "physio_arms",
		"category": "Care",
		"subject": "A complaint about the physio",
		"speaker_slot": 5,
		"expression": "cross",
		"utterance": "our physio stretched my arms out too long",
		"report": "%s is unhappy after a session. In this world that is not "
			+ "necessarily a figure of speech -- arm length is a real property "
			+ "and the silhouette reads from it.",
		"options": [
			{
				"label": "Take it seriously",
				"cost": "A week of lighter work, and the physio hears about it.",
			},
			{
				"label": "Let it settle",
				"cost": "Free. It may settle. It may not.",
			},
		],
	},
]


static func events() -> Array:
	return SAMPLE_EVENTS.duplicate(true)


## The report with the voli's name in it. Kept here rather than at the call site
## so the format string and its one argument never drift apart.
static func report_text(event: Dictionary, speaker_name: String) -> String:
	return str(event.get("report", "%s")) % speaker_name
