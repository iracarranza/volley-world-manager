class_name SystemFitBands
extends Control

## The windows a rally reads, drawn as windows -- one per voli, on one axis.
##
## A system-fit band is an ideal and a tolerance either side: a mean and a
## spread. Written out it is two numbers nobody compares. Drawn, the bar's
## *position* says what this voli naturally does and its *width* says how much
## room they have to be wrong, and both matter -- a setter releasing at 0.40s
## ± 0.14 and one releasing at 0.40s ± 0.05 play differently, and only the second
## can run a fast offence.
##
## Every row shares one axis, which is the point. Reading the bars against each
## other is what turns four numbers into "these two are tight and that one is
## not, so put that one on this session". The spread between volis runs 10% to
## 40% of the median, which is what makes the comparison legible at all.

const ROW_HEIGHT: float = 22.0
const ROW_GAP: float = 5.0
const NAME_WIDTH: float = 128.0
const VALUE_WIDTH: float = 96.0
const BAR_HEIGHT: float = 10.0
const HEADER_HEIGHT: float = 18.0
## How much axis is drawn either side of the widest band, so no bar touches the
## end of its own track.
const AXIS_PADDING: float = 0.10

var rows: Array[Dictionary] = []
var unit: String = ""
var decimals: int = 2

var _band_color := Color(0.42, 0.72, 0.72, 0.85)
var _ink := Color(0.90, 0.92, 0.95, 0.88)
var _muted := Color(0.62, 0.66, 0.74, 0.70)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Painted by hand; the style pass would give it an edge and a wash it does
	## not want.
	set_meta("ui_style_exempt", true)
	resized.connect(queue_redraw)


func set_palette(ink: Color, muted: Color, band: Color) -> void:
	_ink = ink
	_muted = muted
	_band_color = band
	queue_redraw()


func set_rows(value: Array[Dictionary], axis_unit: String, axis_decimals: int) -> void:
	rows = value
	unit = axis_unit
	decimals = axis_decimals
	custom_minimum_size = Vector2(
		360.0,
		HEADER_HEIGHT + maxf(float(rows.size()) * (ROW_HEIGHT + ROW_GAP), 0.0),
	)
	queue_redraw()


func _draw() -> void:
	if rows.is_empty() or size.x < NAME_WIDTH + VALUE_WIDTH + 60.0:
		return
	var font := get_theme_default_font()
	var font_size := maxi(get_theme_default_font_size() - 3, 9)
	var track_x := NAME_WIDTH
	var track_width := size.x - NAME_WIDTH - VALUE_WIDTH
	var span := _axis()

	## The ends of the shared axis, once, at the top. Every bar below is read
	## against these two numbers, so repeating them per row would be noise.
	draw_string(
		font, Vector2(track_x, 11.0), _format(span.x),
		HORIZONTAL_ALIGNMENT_LEFT, track_width * 0.5, font_size, Color(_muted, 0.8)
	)
	draw_string(
		font, Vector2(track_x + track_width * 0.5, 11.0), _format(span.y),
		HORIZONTAL_ALIGNMENT_RIGHT, track_width * 0.5, font_size, Color(_muted, 0.8)
	)

	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var top := HEADER_HEIGHT + float(index) * (ROW_HEIGHT + ROW_GAP)
		var bar_top := top + (ROW_HEIGHT - BAR_HEIGHT) * 0.5

		draw_string(
			font, Vector2(0.0, top + 14.0), str(row.get("name", "")),
			HORIZONTAL_ALIGNMENT_LEFT, NAME_WIDTH - 8.0, font_size, _ink
		)

		## The track, so a bar's position reads against something even when it is
		## narrow.
		draw_line(
			Vector2(track_x, bar_top + BAR_HEIGHT * 0.5),
			Vector2(track_x + track_width, bar_top + BAR_HEIGHT * 0.5),
			Color(_muted, 0.20), 1.0
		)

		var ideal := float(row.get("ideal", 0.0))
		var tolerance := float(row.get("tolerance", 0.0))
		var left := _to_track(ideal - tolerance, span, track_x, track_width)
		var right := _to_track(ideal + tolerance, span, track_x, track_width)
		var bar := Rect2(
			Vector2(left, bar_top), Vector2(maxf(right - left, 2.0), BAR_HEIGHT)
		)
		draw_rect(bar, Color(_band_color, 0.30))
		draw_rect(bar, _band_color, false, 1.0)
		## The ideal itself. A band without it says how much room there is and not
		## where the middle of it sits.
		var tick := _to_track(ideal, span, track_x, track_width)
		draw_line(
			Vector2(tick, bar_top - 1.0), Vector2(tick, bar_top + BAR_HEIGHT + 1.0),
			_ink, 1.5
		)

		draw_string(
			font, Vector2(track_x + track_width + 8.0, top + 14.0),
			"%s ± %s" % [_format(ideal), _format(tolerance)],
			HORIZONTAL_ALIGNMENT_LEFT, VALUE_WIDTH - 8.0, font_size, _muted
		)


## The shared axis: wide enough to hold every band, with air at both ends.
func _axis() -> Vector2:
	var low := INF
	var high := -INF
	for row in rows:
		var ideal := float(row.get("ideal", 0.0))
		var tolerance := float(row.get("tolerance", 0.0))
		low = minf(low, ideal - tolerance)
		high = maxf(high, ideal + tolerance)
	if not is_finite(low) or not is_finite(high):
		return Vector2(0.0, 1.0)
	var pad := maxf((high - low) * AXIS_PADDING, 0.01)
	## Never below zero. Every axis here is a distance or an interval, so a
	## negative end is not a value the reader can make sense of -- and the padding
	## took the floor a few thousandths under, which printed as "-0.00m".
	return Vector2(maxf(low - pad, 0.0), high + pad)


func _to_track(value: float, span: Vector2, track_x: float, track_width: float) -> float:
	var range_size := maxf(span.y - span.x, 0.0001)
	return track_x + clampf((value - span.x) / range_size, 0.0, 1.0) * track_width


func _format(value: float) -> String:
	return "%.*f%s" % [decimals, value, unit]
