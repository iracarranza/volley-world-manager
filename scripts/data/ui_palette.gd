class_name UIPalette
extends RefCounted

## Presentation tokens shared by Control themes, custom drawing, and 3D playback.
## Static resources duplicate a small subset of these values; the test suite
## verifies that those copies remain synchronized.
const DARK := {
	"canvas": Color("08131f"),
	"canvas_alt": Color("0d2130"),
	"surface": Color("10283a"),
	"surface_raised": Color("17384b"),
	"surface_inset": Color("07101a"),
	"surface_hover": Color("214d5d"),
	"ink": Color("f5f0dc"),
	"ink_muted": Color("a9bdc6"),
	"ink_faint": Color("6f8995"),
	"stroke": Color("34596a"),
	"stroke_strong": Color("5e8590"),
	"accent": Color("f2c84b"),
	"accent_ink": Color("17202a"),
	"accent_alt": Color("55c9c1"),
	"danger": Color("ff6b5f"),
	"positive": Color("75d99b"),
	"scrim": Color(0.01, 0.025, 0.04, 0.88),
	"court_floor": Color("101b27"),
	"court_surface": Color("d97a45"),
	"court_line": Color("fff2c7"),
	"court_net": Color(0.90, 0.96, 0.95, 0.64),
	"court_post": Color("267b84"),
}

const LIGHT := {
	"canvas": Color("efe7d3"),
	"canvas_alt": Color("d9e2d2"),
	"surface": Color("fffaf0"),
	"surface_raised": Color("f4eedf"),
	"surface_inset": Color("e4dfd2"),
	"surface_hover": Color("d7ead9"),
	"ink": Color("173d35"),
	"ink_muted": Color("4e6b64"),
	"ink_faint": Color("768b83"),
	"stroke": Color("9db6a9"),
	"stroke_strong": Color("537b6c"),
	"accent": Color("d94b3d"),
	"accent_ink": Color("fff9e9"),
	"accent_alt": Color("167f79"),
	"danger": Color("bd302d"),
	"positive": Color("247a50"),
	"scrim": Color(0.08, 0.11, 0.10, 0.72),
	"court_floor": Color("d8d1c0"),
	"court_surface": Color("df8151"),
	"court_line": Color("fff8df"),
	"court_net": Color(0.13, 0.29, 0.28, 0.58),
	"court_post": Color("176f72"),
}

## What a grade is written in.
##
## Two tables, and it has to be two. These are the only colours in the interface
## that are *data* rather than decoration -- the number says what it is by what
## it is written in -- so they cannot be theme tokens, and for a long time they
## were one table used in both themes on the reasoning that a grade means the
## same thing on either page.
##
## Which is true of the meaning and false of the pigment. The dark table is five
## bright inks for a dark page, and C is `f2f4f7` -- as near white as makes no
## difference. Put that on cream paper and the most common grade on the roster,
## the one every average attribute carries, is invisible. Not hard to read:
## absent. A player's whole middle band read as a column of blank space.
##
## So the light table is the same five *hues* taken down to values that survive
## being written on paper, and C stops being "no colour" and becomes the page's
## own muted ink -- which is what average should look like anyway.
const GRADE_COLORS := {
	"S": Color("ffd84d"),
	"A": Color("58d68d"),
	"B": Color("5dade2"),
	"C": Color("f2f4f7"),
	"D": Color("ff6b6b"),
}

const GRADE_COLORS_LIGHT := {
	"S": Color("9a6b06"),
	"A": Color("1f7a4d"),
	"B": Color("1f5f96"),
	"C": Color("4e6b64"),
	"D": Color("b1332f"),
}


static func color(token: StringName, light_mode: bool = false) -> Color:
	var palette: Dictionary = LIGHT if light_mode else DARK
	return Color(palette.get(token, Color.MAGENTA))


static func grade_color(tier: String, light_mode: bool = false) -> Color:
	var table: Dictionary = GRADE_COLORS_LIGHT if light_mode else GRADE_COLORS
	return Color(table.get(tier, table.C))


static func grade_color_hex(tier: String, light_mode: bool = false) -> String:
	return grade_color(tier, light_mode).to_html(false)


static func control_is_light(control: Control) -> bool:
	return control.get_theme_color("font_color", "Label").get_luminance() < 0.45
