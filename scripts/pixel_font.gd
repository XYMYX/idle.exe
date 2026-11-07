class_name PixelFont
extends RefCounted
## Tiny 3×5 pixel font (M is 5 wide). White with a black outline
## so it stays readable on light and dark desktops.

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
	"Z": ["###", "..#", ".#.", "#..", "###"],
	"!": ["#", "#", "#", ".", "#"],
	"?": ["###", "..#", ".##", "...", ".#."],
}


static func text_width(text: String) -> int:
	var w := 0
	for ch in text:
		var g: Array = GLYPHS.get(ch, [])
		if not g.is_empty():
			w += String(g[0]).length() + SPACING
	return maxi(0, w - SPACING)


## Draws text with its top-left corner at pos (in game pixels).
static func draw_text(ci: CanvasItem, text: String, pos: Vector2) -> void:
	for layer in 2:  # 0 = black outline, 1 = white text
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
