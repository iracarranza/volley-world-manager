class_name VolleyballCalendarRules
extends RefCounted

const MONTHS: Array[String] = [
	"March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December", "January", "February",
]
const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]

## A week is seven days here, like everywhere else.
##
## The calendar counted weeks and nothing smaller, which was fine while a week
## was the only thing that happened -- the manager pressed Advance Week and the
## training was applied. It stopped being fine the moment the club had a session
## the manager could attend: you cannot turn up to a *week*.
const DAYS: Array[String] = [
	"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
]
const DAYS_PER_WEEK: int = 7


static func day_name(day_of_week: int) -> String:
	return DAYS[clampi(day_of_week, 1, DAYS_PER_WEEK) - 1]


static func state_for_week(absolute_week: int) -> Dictionary:
	var zero_based := maxi(absolute_week - 1, 0)
	var week_of_year := zero_based % 48 + 1
	var month_index := floori(float(week_of_year - 1) / 4.0)
	return {"absolute_week": absolute_week,
		"year": floori(float(zero_based) / 48.0) + 1,
		"week_of_year": week_of_year, "month": MONTHS[month_index],
		"week_of_month": (week_of_year - 1) % 4 + 1,
		"season": SEASONS[floori(float(month_index) / 3.0)]}


## The date as the journal writes it.
##
## `day_of_week` is optional so the twenty-one existing readers of this function
## keep working unchanged and print exactly what they printed before. A caller
## that knows what day it is says so and gets the day in the line.
static func display_date(absolute_week: int, day_of_week: int = 0) -> String:
	var state := state_for_week(absolute_week)
	if day_of_week <= 0:
		return "%s · Week %d · Year %d" % [
			state.month, state.week_of_month, state.year,
		]
	return "%s · %s · Week %d · Year %d" % [
		day_name(day_of_week), state.month, state.week_of_month, state.year,
	]
