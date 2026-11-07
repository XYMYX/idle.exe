class_name PixelFont
extends RefCounted
## Winzige 3×5-Pixelschrift (M ist 5 breit). Weiss mit schwarzem Rand,
## damit sie auf hellen und dunklen Desktops lesbar ist.

const HEIGHT := 5
const SPACING := 1

const GLYPHS := {
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", ".##", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
	".": [".", ".", ".", ".", "#"],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
	"B": ["##.", "#.#", "##.", "#.#", "##."],
	"T": ["###", ".#.", ".#.", ".#.", ".#."],
	"e": ["...", ".##", "###", "#..", ".##"],
	"+": ["...", ".#.", "###", ".#.", "..."],
	"-": ["...", "...", "###", "...", "..."],
	" ": ["..", "..", "..", "..", ".."],
}


static func text_width(text: String) -> int:
	var w := 0
	for ch in text:
		var g: Array = GLYPHS.get(ch, [])
		if not g.is_empty():
			w += String(g[0]).length() + SPACING
	return maxi(0, w - SPACING)


## Zeichnet text mit linker oberer Ecke bei pos (in Spielpixeln).
static func draw_text(ci: CanvasItem, text: String, pos: Vector2) -> void:
	for layer in 2:  # 0 = schwarzer Rand, 1 = weisse Schrift
		var x := pos.x
		for ch in text:
			var g: Array = GLYPHS.get(ch, [])
			if g.is_empty():
				continue
			for row in HEIGHT:
				var line := String(g[row])
				for col in line.length():
					if line[col] != "#":
						continue
					var p := Vector2(x + col, pos.y + row)
					if layer == 0:
						ci.draw_rect(Rect2(p - Vector2.ONE, Vector2(3, 3)), Color.BLACK)
					else:
						ci.draw_rect(Rect2(p, Vector2.ONE), Color.WHITE)
			x += String(g[0]).length() + SPACING
