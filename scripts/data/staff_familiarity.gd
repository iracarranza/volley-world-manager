class_name StaffFamiliarity
extends RefCounted

## What a staff member has got good at, one thing at a time.
##
## The chef says *"I improved my use of Landavoli paste"* and that sentence has
## to be true of something. This is the something: a number per staff member per
## **subject** — a paste for the chef, a region for the scout, a body for the
## physio — that climbs by doing the thing and decays by not.
##
## ## It is the same shape as `PairFamiliarity`, on purpose
##
## Keyed the same way, on the same 0–100 scale, with the same
## climbs-fast-decays-slow asymmetry. A second familiarity system with its own
## curve would be two answers to one question, and the setter-and-hitter version
## is already the one everything else is read against.
##
## ## What it buys, and what it must not
##
## **Less paste for the same effect**, not more effect for the same paste. That
## distinction is the whole design: a familiar chef is *efficient*, and an
## unfamiliar one is wasteful rather than incompetent. Which means a new chef can
## cook anything from week one and simply costs more doing it, and the manager
## who keeps a chef through a region change is rewarded without the one who
## hires a new one being punished.
##
## And it must not become an inventory. §13's rule is that nobody counts sacks
## of anything: the club has a *flow*, not a stockpile. So efficiency moves the
## weekly cost of a line, never a quantity in a bin. Running short stays an
## event — a lean season, a line that did not arrive — rather than a thing a
## manager budgets against every week.

## Where a staff member starts with something they have never worked with.
##
## Not zero. A trained chef handed an unfamiliar paste is a professional reading
## a new ingredient, not somebody who has never cooked — and a floor of zero
## would make the first week with any new line feel like a punishment for
## running it, which is the same mistake the larder-wide comfort share made.
const BASELINE: float = 28.0
## A week of working with the same subject.
const WEEK_GAIN: float = 4.2
## And a week without it. Slower than the gain, so a chef who rotates three
## pastes keeps all three rather than losing two to keep one.
const WEEK_DECAY: float = 1.1
const CEILING: float = 100.0

## What the extremes are worth, as a share of the paste a week needs.
##
## A stranger to an ingredient spends a fifth more of it; somebody who has cooked
## it for two seasons spends a quarter less. Deliberately a narrow band: the
## chef's rating sets *how many* pastes they can hold, which is the big lever,
## and familiarity is the slow one underneath it. Two big levers on one person
## is a staff member who is simply good or bad.
const WASTE_AT_NOTHING: float = 1.20
const THRIFT_AT_MASTERY: float = 0.76


static func key(staff_id: int, subject: String) -> String:
	return "%d:%s" % [staff_id, subject]


static func of(table: Dictionary, staff_id: int, subject: String) -> float:
	return float(table.get(key(staff_id, subject), BASELINE))


## A week of using this subject, and a week of not using everything else.
##
## Both halves in one call, because a decay that is applied somewhere else is a
## decay somebody forgets to apply — and the failure would be silent, since a
## familiarity that only ever climbs looks exactly like a chef who is learning.
static func record_week(
	table: Dictionary, staff_id: int, subjects: Array
) -> void:
	var used := {}
	for subject in subjects:
		used[str(subject)] = true
		var at := key(staff_id, str(subject))
		table[at] = minf(float(table.get(at, BASELINE)) + WEEK_GAIN, CEILING)
	var prefix := "%d:" % staff_id
	for entry in table:
		var at := str(entry)
		if not at.begins_with(prefix):
			continue
		if used.has(at.substr(prefix.length())):
			continue
		table[at] = maxf(float(table[at]) - WEEK_DECAY, 0.0)


## How much of a week's paste this chef spends on this one, as a multiplier.
static func thrift(table: Dictionary, staff_id: int, subject: String) -> float:
	var learned := clampf(of(table, staff_id, subject) / CEILING, 0.0, 1.0)
	return lerpf(WASTE_AT_NOTHING, THRIFT_AT_MASTERY, learned)


## What a chef's whole week costs, against what the lines alone would cost.
##
## The multiplier lands on the supply bill rather than on the food, which is what
## keeps §13's flow intact: the club still does not hold stock, it simply buys
## less of what its chef knows how to use.
static func weekly_thrift(
	table: Dictionary, staff_id: int, subjects: Array
) -> float:
	if subjects.is_empty():
		return 1.0
	var total := 0.0
	for subject in subjects:
		total += thrift(table, staff_id, str(subject))
	return total / float(subjects.size())


## Whether this week is worth the chef mentioning.
##
## The threshold a report is written at, so the log is a record of things that
## changed rather than a weekly receipt. A staff member who reports every week
## is a staff member nobody reads.
const WORTH_SAYING: float = 8.0


static func crossed(before: float, after: float) -> bool:
	return floorf(after / WORTH_SAYING) > floorf(before / WORTH_SAYING)
