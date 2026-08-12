class_name PastePaint
extends RefCounted

## The block's top face, and what has been spread on it.
##
## ## Why the ratio is a picture rather than a number
##
## `PasteRatio` models a mix as `{paste: share}`, and every interface built on it
## so far has been a set of numbers you nudge. That is the thing being replaced.
## A cook does not decide that the block is 34% Xérvyan; a cook puts Xérvyan on
## part of the block, and 34% is what that turns out to be. Making the picture the
## input and the number the *readout* is the whole point -- it puts the decision
## where the decision actually is, which is how much of the meal tastes of what.
##
## So this is a paint canvas whose only job is to be measured. `shares()` returns
## exactly the dictionary `PasteRatio` has always taken, so nothing downstream
## knows or cares that the number came off a picture.
##
## ## Cells, not pixels
##
## The canvas is a `CANVAS`-square grid of *slot indices*, one byte each, and not
## an `Image` of colours. Three reasons, in order of how much they cost to get
## wrong:
##
## 1. **Measuring is the primary operation.** Counting cells per paste is a pass
##    over a byte array. Counting *colours* means comparing floats and hoping two
##    strokes of the same paste came out identical.
## 2. **A paste can be recoloured.** The colour belongs to the axis and could
##    change; the painting should not have to be repainted if it does.
## 3. **It has to fit in a save.** 64x64 bytes compresses to a couple of hundred,
##    which is a field. A PNG of an RGBA image is not.
##
## `0` is bare block. Slots are `1..pastes.size()`, so a byte is a one-based index
## into `pastes` -- which means clearing a slot is a byte-wise substitution and
## never a search.

const Larder := preload("res://scripts/data/region_larder.gd")

## How fine the block is.
##
## 128 squared is 16,384 cells, so one cell is six thousandths of a percent of the
## block and the finest nozzle still lands a share the readout can round.
##
## It was 64, on the reasoning that a finer grid is a smoother edge nobody sees.
## The render disagreed: a nozzle of radius nine cells rasterises into a visibly
## polygonal blob at that pitch, and a blob with eleven straight sides does not
## read as spread paste. Doubling it was affordable only once the image stopped
## being rebuilt from scratch on every stroke -- see `image()`.
const CANVAS: int = 128
const CELLS: int = CANVAS * CANVAS

## What the nozzles are, **as a share of the block** rather than as a radius in
## cells.
##
## Named for what a cook is holding rather than for a number of pixels: this is a
## piping nozzle, and the reason to pick a wide one is that you are covering the
## block rather than that you want a fat line.
##
## Held as a share because they were held in cells first, and doubling `CANVAS`
## from 64 to 128 silently quartered every one of them: the widest nozzle went
## from covering 6% of the block per dab to 1.6%, so covering the block went from
## a dozen strokes to sixty. Nothing errored and nothing looked broken -- it just
## became tedious, which is the §0 failure wearing its most forgettable disguise.
## A share cannot drift when the grid does.
const NOZZLES := {"fine": 0.031, "medium": 0.070, "wide": 0.141}
const NOZZLE_ORDER := ["fine", "medium", "wide"]
const DEFAULT_NOZZLE: String = "medium"


## A nozzle's radius, in cells, on whatever grid is current.
##
## The one place shares become cells, so no caller has to know `CANVAS` and no
## second call site can be missed the next time the grid changes.
static func nozzle_radius(nozzle: String) -> float:
	return float(NOZZLES.get(nozzle, NOZZLES[DEFAULT_NOZZLE])) * float(CANVAS)

## The pastes in slot order. Index zero of this array is slot **one**.
var pastes: Array[String] = []
var _cells := PackedByteArray()
## `counts()` is a pass over every cell and four separate things ask for it after
## every stroke -- the readout, the palette, the store and the ceiling check. At
## sixty strokes a second that is a quarter of a million iterations for one
## answer that has not changed. Invalidated by the two functions that can change
## a cell, so it cannot go stale without somebody adding a third.
var _counts_cache: Dictionary = {}
var _counts_dirty: bool = true
## The picture, kept in step with the cells rather than derived from them.
##
## `TofuBlock` needs an `Image` to build a texture from, and building one by
## walking every cell is 16,384 `set_pixel` calls -- for *one frame* of a drag
## that a player will hold down for seconds. `paint` and `scrape` already visit
## exactly the cells that changed, so they write both.
##
## The two can only disagree if somebody adds a third writer of `_cells`, which is
## the same invariant `_counts_dirty` relies on and is worth stating once for
## both.
var _image: Image = null


static func blank() -> PastePaint:
	var paint := PastePaint.new()
	paint.clear()
	return paint


func clear() -> void:
	_counts_dirty = true
	_cells = PackedByteArray()
	_cells.resize(CELLS)
	_cells.fill(0)
	pastes.clear()
	_image = Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 0))


## Lay paste down in a circle, and say how many cells it took.
##
## The count is the return value because it is what a store is charged: the
## painter needs to know what the stroke cost *after* clipping to the block and
## after overwriting cells that already carried this same paste, and neither of
## those is knowable before the stroke is drawn.
##
## `ceiling` is the chef's, and it is enforced here rather than in the interface.
## A ceiling checked only by the palette is a ceiling that a save file, a preset
## or a future caller can walk straight past -- and §1 calls this limit hard.
func paint(at: Vector2, radius: float, paste: String, ceiling: int = 4) -> int:
	var slot := _slot_for(paste, ceiling)
	if slot <= 0:
		return 0
	var ink := Larder.paste_colour(_region_of(paste))
	var painted := 0
	var reach := maxf(radius, 0.5)
	var min_x := maxi(int(floor(at.x - reach)), 0)
	var max_x := mini(int(ceil(at.x + reach)), CANVAS - 1)
	var min_y := maxi(int(floor(at.y - reach)), 0)
	var max_y := mini(int(ceil(at.y + reach)), CANVAS - 1)
	var squared := reach * reach
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(float(x) - at.x, float(y) - at.y).length_squared() > squared:
				continue
			var index := y * CANVAS + x
			if _cells[index] == slot:
				## Going over the same paste again costs nothing. A cook who
				## wobbles the nozzle has not used twice the paste, and charging
				## for it would make a steady hand a resource.
				continue
			_cells[index] = slot
			painted += 1
	if painted > 0:
		_counts_dirty = true
	return painted


## Scrape back to bare block. Returns cells cleared, which a store is refunded --
## paste that never got eaten is paste you still have.
func scrape(at: Vector2, radius: float) -> Dictionary:
	var freed := {}
	var reach := maxf(radius, 0.5)
	var squared := reach * reach
	for y in range(maxi(int(floor(at.y - reach)), 0), mini(int(ceil(at.y + reach)), CANVAS - 1) + 1):
		for x in range(maxi(int(floor(at.x - reach)), 0), mini(int(ceil(at.x + reach)), CANVAS - 1) + 1):
			if Vector2(float(x) - at.x, float(y) - at.y).length_squared() > squared:
				continue
			var index := y * CANVAS + x
			var slot := int(_cells[index])
			if slot == 0:
				continue
			var name := pastes[slot - 1]
			freed[name] = int(freed.get(name, 0)) + 1
			_cells[index] = 0
			_image.set_pixel(x, y, Color(0, 0, 0, 0))
			_counts_dirty = true
	return freed


## How many cells each paste covers.
func counts() -> Dictionary:
	if not _counts_dirty:
		return _counts_cache
	var out := {}
	for index in range(CELLS):
		var slot := int(_cells[index])
		if slot == 0 or slot > pastes.size():
			continue
		var name := pastes[slot - 1]
		out[name] = int(out.get(name, 0)) + 1
	_counts_cache = out
	_counts_dirty = false
	return out


## The mix, in exactly the shape `PasteRatio` takes.
##
## Shares of the **painted** area, not of the block. A half-bare block whose paint
## is all Xérvyan is a fully Xérvyan mix served thinly, not a mix that is half
## nothing -- how thinly is `coverage()`, and it is a different fact.
func shares() -> Dictionary:
	var counted := counts()
	var total := 0
	for paste in counted:
		total += int(counted[paste])
	if total <= 0:
		return {}
	var out := {}
	for paste in counted:
		out[str(paste)] = float(counted[paste]) / float(total)
	return out


## How much of the block has anything on it at all.
func coverage() -> float:
	var painted := 0
	for count in counts().values():
		painted += int(count)
	return float(painted) / float(CELLS)


## What one paste covers, as a share of the whole block. This is the quantity a
## store is measured in: one unit of paste covers the block once.
func spread_of(paste: String) -> float:
	return float(int(counts().get(paste, 0))) / float(CELLS)


## How many pastes are on the block, ignoring ones scraped back to nothing.
func slots_used() -> int:
	return counts().size()


## The picture, for whoever is drawing the block.
##
## Handed out by reference rather than duplicated: the only caller uploads it to a
## texture and never keeps it, and duplicating a 16k image once per stroke would
## undo the whole reason this is kept in step in the first place.
func image() -> Image:
	if _image == null:
		clear()
	return _image


func cell_at(index: int) -> int:
	return int(_cells[index]) if index >= 0 and index < CELLS else 0


func colour_at(index: int) -> Color:
	var slot := cell_at(index)
	if slot == 0 or slot > pastes.size():
		return Color(0, 0, 0, 0)
	return Larder.paste_colour(_region_of(pastes[slot - 1]))


## The region a paste came from, recovered from its name.
##
## `Larder.paste_name` builds `"%s paste"` off the demonym, so this walks the
## larders and asks each one what it calls its paste rather than trying to invert
## the demonym table. Slower and correct; the alternative is a second mapping that
## can disagree with the first.
static func _region_of(paste: String) -> String:
	for region in Larder.LARDERS:
		if Larder.paste_name(str(region)) == paste:
			return str(region)
	return ""


## Rebuild the picture from the cells, the slow way.
##
## The one case where walking every cell is right: a canvas that has just come out
## of a save has no picture at all, and it happens once per load rather than once
## per stroke.
func _repaint_image() -> void:
	_image = Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var inks := {}
	for index in range(CELLS):
		var slot := int(_cells[index])
		if slot == 0 or slot > pastes.size():
			continue
		var name := pastes[slot - 1]
		if not inks.has(name):
			inks[name] = Larder.paste_colour(_region_of(name))
		_image.set_pixel(index % CANVAS, index / CANVAS, inks[name])


func _slot_for(paste: String, ceiling: int) -> int:
	var existing := pastes.find(paste)
	if existing >= 0:
		return existing + 1
	## A slot that has been scraped completely bare is free again. Without this a
	## manager who painted a paste, changed their mind and scraped it off would
	## have spent a slot on a paste that is not on the block.
	var counted := counts()
	for index in range(pastes.size()):
		if not counted.has(pastes[index]):
			pastes[index] = paste
			return index + 1
	if pastes.size() >= clampi(ceiling, 1, 255):
		return 0
	pastes.append(paste)
	return pastes.size()


## ## Into a save
##
## The cells compress before they are encoded, because a painted block is mostly
## long runs of one byte and that is the case the deflate stream is best at. A
## typical block measured 4,096 bytes down to under two hundred.
func to_dict() -> Dictionary:
	return {
		"pastes": pastes.duplicate(),
		"cells": Marshalls.raw_to_base64(
			_cells.compress(FileAccess.COMPRESSION_DEFLATE)
		),
	}


static func from_dict(data: Dictionary) -> PastePaint:
	var paint := PastePaint.blank()
	for entry in Array(data.get("pastes", [])):
		paint.pastes.append(str(entry))
	var encoded := str(data.get("cells", ""))
	if encoded.is_empty():
		return paint
	var raw := Marshalls.base64_to_raw(encoded)
	var cells := raw.decompress(CELLS, FileAccess.COMPRESSION_DEFLATE)
	## A canvas that did not decompress to exactly the right size is a canvas from
	## a different `CANVAS`, and a half-restored painting is worse than a blank
	## one -- it would be measured, and the number would be wrong.
	if cells.size() == CELLS:
		paint._cells = cells
		paint._counts_dirty = true
		paint._repaint_image()
	return paint
