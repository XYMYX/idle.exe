class_name BigNum
extends RefCounted
## Short forms for big numbers: 999, 1.23K, 45.6M, 789B, 1.2T, then 1.2e15.
## Numbers are floats internally (64 bit, up to ~1e308), which is enough for an idle game.

const SUFFIXES := ["", "K", "M", "B", "T"]


static func format(x: float) -> String:
	if x < 1000.0:
		return str(int(floor(maxf(x, 0.0))))
	var tier := int(floor(log(x) / log(1000.0)))
	var v := x / pow(1000.0, tier)
	if v >= 1000.0:  # rounding error of log()
		tier += 1
		v /= 1000.0
	if tier < SUFFIXES.size():
		return _short(v) + SUFFIXES[tier]
	var e10 := int(floor(log(x) / log(10.0)))
	var m := x / pow(10.0, e10)
	if m >= 10.0:  # rounding error of log()
		e10 += 1
		m /= 10.0
	return "%.1fe%d" % [_floor_to(m, 10.0), e10]


## For rates like 1.5/s: below 1000 with one decimal.
static func format_rate(x: float) -> String:
	if x < 1000.0:
		return "%.1f" % x
	return format(x)


## Money: 12.5, 24'500 (German/Swiss) or 24,500 (English), short form from 1 million (1.23M).
static func format_chf(x: float) -> String:
	if x < 100.0 and x != floorf(x):
		return "%.1f" % _floor_to(x, 10.0)
	if x >= 1.0e6:
		return format(x)
	var sep := "'" if TranslationServer.get_locale().begins_with("de") else ","
	var s := str(int(floor(maxf(x, 0.0))))
	var out := ""
	while s.length() > 3:
		out = sep + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## Always round down so we never show more than the player has.
static func _short(v: float) -> String:
	if v >= 100.0:
		return str(int(floor(v)))
	if v >= 10.0:
		return "%.1f" % _floor_to(v, 10.0)
	return "%.2f" % _floor_to(v, 100.0)


## Round down to 1/step, with a small tolerance against float errors (4.56 * 100 = 455.999…).
static func _floor_to(v: float, step: float) -> float:
	return floor(v * step + 1e-6) / step
