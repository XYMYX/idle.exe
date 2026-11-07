class_name BigNum
extends RefCounted
## Kurzformen für grosse Zahlen: 999, 1.23K, 45.6M, 789B, 1.2T, danach 1.2e15.
## Intern sind Zahlen float (64 Bit, bis ca. 1e308), das reicht für ein Idle-Game.

const SUFFIXES := ["", "K", "M", "B", "T"]


static func format(x: float) -> String:
	if x < 1000.0:
		return str(int(floor(maxf(x, 0.0))))
	var tier := int(floor(log(x) / log(1000.0)))
	var v := x / pow(1000.0, tier)
	if v >= 1000.0:  # Rundungsfehler von log()
		tier += 1
		v /= 1000.0
	if tier < SUFFIXES.size():
		return _short(v) + SUFFIXES[tier]
	var e10 := int(floor(log(x) / log(10.0)))
	var m := x / pow(10.0, e10)
	if m >= 10.0:  # Rundungsfehler von log()
		e10 += 1
		m /= 10.0
	return "%.1fe%d" % [_floor_to(m, 10.0), e10]


## Für Raten wie 1.5/s: unter 1000 mit einer Nachkommastelle.
static func format_rate(x: float) -> String:
	if x < 1000.0:
		return "%.1f" % x
	return format(x)


## Geld im Schweizer Format: 12.5, 24'500, ab 1 Mio. Kurzform (1.23M).
static func format_chf(x: float) -> String:
	if x < 100.0 and x != floorf(x):
		return "%.1f" % _floor_to(x, 10.0)
	if x >= 1.0e6:
		return format(x)
	var s := str(int(floor(maxf(x, 0.0))))
	var out := ""
	while s.length() > 3:
		out = "'" + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## Immer abrunden, damit nie mehr angezeigt wird, als man hat.
static func _short(v: float) -> String:
	if v >= 100.0:
		return str(int(floor(v)))
	if v >= 10.0:
		return "%.1f" % _floor_to(v, 10.0)
	return "%.2f" % _floor_to(v, 100.0)


## Abrunden auf 1/step, mit kleiner Toleranz gegen float-Fehler (4.56 * 100 = 455.999…).
static func _floor_to(v: float, step: float) -> float:
	return floor(v * step + 1e-6) / step
