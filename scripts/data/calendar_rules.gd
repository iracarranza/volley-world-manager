class_name VolleyballCalendarRules
extends RefCounted

const MONTHS: Array[String] = [
	"March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December", "January", "February",
]
const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]


static func state_for_week(absolute_week: int) -> Dictionary:
	var zero_based := maxi(absolute_week - 1, 0)
	var week_of_year := zero_based % 48 + 1
	var month_index := floori(float(week_of_year - 1) / 4.0)
	return {"absolute_week": absolute_week,
		"year": floori(float(zero_based) / 48.0) + 1,
		"week_of_year": week_of_year, "month": MONTHS[month_index],
		"week_of_month": (week_of_year - 1) % 4 + 1,
		"season": SEASONS[floori(float(month_index) / 3.0)]}


static func display_date(absolute_week: int) -> String:
	var state := state_for_week(absolute_week)
	return "%s · Week %d · Year %d" % [state.month, state.week_of_month, state.year]
