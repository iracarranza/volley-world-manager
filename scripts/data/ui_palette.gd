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

const GRADE_COLORS := {
	"S": Color("ffd84d"),
	"A": Color("58d68d"),
	"B": Color("5dade2"),
	"C": Color("f2f4f7"),
	"D": Color("ff6b6b"),
}


static func color(token: StringName, light_mode: bool = false) -> Color:
	var palette: Dictionary = LIGHT if light_mode else DARK
	return Color(palette.get(token, Color.MAGENTA))


static func grade_color(tier: String) -> Color:
	return Color(GRADE_COLORS.get(tier, GRADE_COLORS.C))


static func grade_color_hex(tier: String) -> String:
	return grade_color(tier).to_html(false)


static func control_is_light(control: Control) -> bool:
	return control.get_theme_color("font_color", "Label").get_luminance() < 0.45
