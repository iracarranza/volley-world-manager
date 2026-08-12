class_name PasteStore
extends RefCounted

## How much paste there is, which until now there was not.
##
## ## The question this settles
##
## Paste has been modelled as a **flow**: a supply line is running or it is not,
## familiarity moves what a week costs, and no quantity of anything ever sits in a
## bin. That is a defensible model and it makes one thing impossible -- running
## out. A manager could spread the rarest paste in the world across the whole
## block every week for a season and the only consequence was a number in a cost
## column.
##
## Painting the block makes the stock model the only honest one. If the picture is
## the input then the paste has to be a *material*, and a material you can put on
## a block is a material you can be short of. So a source delivers a quantity each
## week, painting spends it, and what is left is on the palette where a cook would
## see it.
##
## ## The unit is one block
##
## One unit of paste covers the block once. Everything is in those terms, which
## makes the whole system readable without a second scale: a store of `0.45` will
## cover a bit under half the block, and it says so on the gauge.
##
## The block itself scales *consumption*, not delivery -- `FoodBlock.takes_paste`
## is how thirsty the stock is, and a Chutum Üch at 1.35 drinks a third more paste
## to cover the same area. That is the existing number doing the job it was
## written for, rather than a second one meaning nearly the same thing.

const Larder := preload("res://scripts/data/region_larder.gd")
const FoodBlockData := preload("res://scripts/data/food_block.gd")

## What arrives each week from the club's own region, and from a line.
##
## Home is short of a full block on purpose. A manager who never opened a supply
## line cannot cover the meal with one flavour and has to choose *which three
## quarters* of it taste of home -- which is the decision the whole screen is for,
## and it exists from the first week rather than after a purchase.
##
## Two lines and a home larder come to 1.65, comfortably over a block. That is
## also on purpose: the point of a line is that it buys you the freedom to spend,
## not that it keeps you from starving.
const HOME_DELIVERY: float = 0.75
const LINE_DELIVERY: float = 0.45

## A lean week delivers less and a rich one more.
##
## The same `CONDITION_NOURISHMENT` multipliers the meal already uses, applied to
## the quantity instead of to the quality -- which is what makes a lean season
## something a manager has to plan around rather than something they read about
## afterwards. One table, so a paste cannot be lean in the pot and abundant in the
## bin.
static func delivered(
	home_region: String, supply_lines: Array, week: int = 1
) -> Dictionary:
	var out := {}
	_deliver(out, home_region, HOME_DELIVERY, week)
	for line in supply_lines:
		_deliver(out, str(line), LINE_DELIVERY, week)
	return out


static func _deliver(
	into: Dictionary, region: String, amount: float, week: int
) -> void:
	if region.is_empty() or not Larder.has_larder(region):
		return
	var paste := Larder.paste_name(region)
	var scaled := amount * Larder.nourishment_of(region, week)
	## Summed rather than overwritten. A line back to your own region is a real
	## thing a manager might buy -- it is how you get enough of the flavour your
	## squad grew up on to cover a whole block.
	into[paste] = float(into.get(paste, 0.0)) + scaled


## What is left after what has been spread.
##
## Never below zero, and the clamp is load bearing rather than defensive: a
## negative remainder would draw as a gauge running backwards, and the painter
## reads this to decide whether a stroke may land at all.
static func remaining(
	delivered_now: Dictionary, spent: Dictionary, block: String
) -> Dictionary:
	var thirst := FoodBlockData.takes_paste(block)
	var out := {}
	for paste in delivered_now:
		out[str(paste)] = maxf(
			float(delivered_now[paste]) - float(spent.get(paste, 0.0)) * thirst, 0.0
		)
	## A paste that was spread and is no longer delivered still has to appear, at
	## zero. Dropping it would let a cancelled supply line quietly erase the
	## evidence that its paste is on this week's block.
	for paste in spent:
		if not out.has(str(paste)):
			out[str(paste)] = 0.0
	return out


## How much of the block this store will still cover.
##
## The inverse of `remaining`, and the number the painter actually needs: a store
## is in units of paste and a nozzle spends *area*, so a thirsty block turns a
## healthy store into a small amount of block.
static func spreadable(units: float, block: String) -> float:
	return units / maxf(FoodBlockData.takes_paste(block), 0.01)


## What a painting has spent, from the picture itself.
##
## Derived rather than accumulated. A running total incremented per stroke drifts
## the moment anything else touches the canvas -- a scrape, a load, a cleared
## slot -- and drift in a store is a manager who cannot work out where their paste
## went. The picture is the record; this only reads it.
static func spent_on(paint: PastePaint) -> Dictionary:
	var out := {}
	var counted := paint.counts()
	for paste in counted:
		out[str(paste)] = float(counted[paste]) / float(PastePaint.CELLS)
	return out
