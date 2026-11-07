extends SceneTree
## Generates starter sprites (side view, XYMYX facing right).
## Usage: godot --headless --path . -s tools/make_sprites.gd
## Output: tools/generated/xymyx_walk.png, art/xymyx_sit.png, art/desk_laptop.png
## and 8× previews on a grey background in tools/preview/.

const S := 48          # figure frame 48×48
const DESK := Vector2i(61, 48)

# Palette
const OUT := Color("#d6d9ee")   # light rim (required for dark desktops)
const BODY := Color("#121218")  # glossy black
const SHINE := Color("#4b4b63") # highlight on top
const RIM := Color("#2c2c3a")   # highlight at the front
const JOINT := Color("#7a7a92")
const JOINT_HI := Color("#a8a8c0")
const MECH := Color("#3a3a48")
const EYE := Color.WHITE
const GLOW := Color("#a8e0ff")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/generated"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/preview"))
	_sheet("xymyx_walk", [_walk(0), _walk(1), _walk(2), _walk(3)])
	_sheet("xymyx_sit", [_sit(0), _sit(1)])
	_sheet("desk_laptop", [_desk()])
	print("Sprites written to res://tools/generated/ (art/ stays untouched)")
	quit()


# --- XYMYX ------------------------------------------------------------------

func _walk(f: int) -> Image:
	var bob := 1 if f % 2 == 1 else 0
	var hip := Vector2i(24, 28 - bob)
	var sh := Vector2i(24, 16 - bob)
	var step_a := [Vector2i(27, 36), Vector2i(30, 45)]
	var step_b := [Vector2i(21, 36), Vector2i(18, 45)]
	var pass_a := [Vector2i(25, 36 - bob), Vector2i(24, 45)]
	var pass_b := [Vector2i(26, 35 - bob), Vector2i(23, 42)]
	var front: Array = [step_a, pass_a, step_b, pass_b][f]
	var back: Array = [step_b, pass_b, step_a, pass_a][f]
	var hand_f: Vector2i = [Vector2i(19, 28), Vector2i(24, 29), Vector2i(30, 27), Vector2i(24, 29)][f] - Vector2i(0, bob)
	var hand_b: Vector2i = [Vector2i(30, 27), Vector2i(24, 29), Vector2i(19, 28), Vector2i(24, 29)][f] - Vector2i(0, bob)
	var arm_sh := sh + Vector2i(0, 1)

	var img := _blank(Vector2i(S, S))
	_layer(img, _arm(arm_sh, hand_b), true)
	_layer(img, _leg(hip, back[0], back[1]), false)
	_layer(img, _body(hip, sh), false)
	_layer(img, _leg(hip, front[0], front[1]), false)
	_layer(img, _arm(arm_sh, hand_f), true)
	_face(img, sh)
	return img


## Sitting on the chair in the desk sprite, hands on the laptop keyboard.
func _sit(f: int) -> Image:
	var hip := Vector2i(22, 30)
	var sh := Vector2i(23, 18)
	var hand := Vector2i(36, 25 - f)
	var img := _blank(Vector2i(S, S))
	_layer(img, _arm(sh + Vector2i(0, 1), hand + Vector2i(-2, f)), true)
	_layer(img, _leg(hip, Vector2i(30, 30), Vector2i(31, 45)), false)
	_layer(img, _body(hip, sh), false)
	_layer(img, _arm(sh + Vector2i(0, 1), hand), true)
	_face(img, sh)
	return img


## Head, neck, torso. Returns: {mask, joints}
func _body(hip: Vector2i, sh: Vector2i) -> Dictionary:
	var m := {}
	var top := sh.y - 12
	var c := sh.x
	# Head: smooth sphere, tilted slightly forward
	for y in range(top, top + 10):
		for x in range(c - 5, c + 7):
			var dx := (x - (c + 0.7)) / 4.7
			var dy := (y - (top + 4.6)) / 5.0
			if dx * dx + dy * dy <= 1.0:
				m[Vector2i(x, y)] = BODY
	# chin/jaw at the front
	m[Vector2i(c + 3, top + 9)] = BODY
	# Neck: visible mechanics (cables/pistons)
	for y in range(top + 9, sh.y + 1):
		m[Vector2i(c - 1, y)] = MECH
		m[Vector2i(c, y)] = JOINT
		m[Vector2i(c + 1, y)] = MECH
	# Torso: broad chest, narrow waist, hips
	for y in range(sh.y, hip.y + 1):
		var x0 := c - 3
		var x1 := c + 3
		if y >= sh.y + 1 and y <= sh.y + 5:
			x1 = c + 4  # chest
		elif y >= sh.y + 7 and y < hip.y - 1:
			x0 = c - 2  # waist
			x1 = c + 2
		for x in range(x0, x1 + 1):
			m[Vector2i(x, y)] = BODY
	# seam in the middle of the chest (subtle)
	for y in range(sh.y + 1, sh.y + 7):
		m[Vector2i(c + 2, y)] = RIM
	return {"mask": m, "joints": []}


func _arm(sh: Vector2i, hand: Vector2i) -> Dictionary:
	var elbow := Vector2i(roundi(lerpf(sh.x, hand.x, 0.5)) + 1, roundi(lerpf(sh.y, hand.y, 0.55)))
	var m := {}
	_stroke(m, [sh, elbow, hand], 1)
	m[hand + Vector2i(1, 0)] = BODY  # hand
	m[hand + Vector2i(1, 1)] = BODY
	return {"mask": m, "joints": [sh, elbow]}


func _leg(hip: Vector2i, knee: Vector2i, foot: Vector2i) -> Dictionary:
	var m := {}
	_stroke(m, [hip, knee, foot], 1)
	for dx in range(-1, 4):  # foot pointing forward
		m[foot + Vector2i(dx, 1)] = BODY
	return {"mask": m, "joints": [knee, foot + Vector2i(-1, -1)]}


func _face(img: Image, sh: Vector2i) -> void:
	var top := sh.y - 12
	var eye := Vector2i(sh.x + 3, top + 4)
	img.set_pixelv(eye, EYE)
	img.set_pixelv(eye + Vector2i(1, 0), EYE)
	img.set_pixelv(eye + Vector2i(2, 0), GLOW)  # glow towards the front
	img.set_pixelv(eye + Vector2i(0, 1), GLOW)


## Paints one layer: light rim, fill, highlight top/front, joint discs.
## soft = no rim over already painted parts (arms in front of the body).
func _layer(img: Image, part: Dictionary, soft: bool) -> void:
	var m: Dictionary = part["mask"]
	for p: Vector2i in m:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if m.has(q) or not _inside(img, q):
				continue
			if soft and img.get_pixelv(q).a > 0.0:
				continue
			img.set_pixelv(q, OUT)
	for p: Vector2i in m:
		if not _inside(img, p):
			continue
		var col: Color = m[p]
		if col == BODY:
			if not m.has(p + Vector2i(0, -1)):
				col = SHINE
			elif not m.has(p + Vector2i(1, 0)):
				col = RIM
		img.set_pixelv(p, col)
	for j: Vector2i in part["joints"]:
		_px(img, j, JOINT)
		_px(img, j + Vector2i(1, 0), JOINT_HI)


func _stroke(m: Dictionary, pts: Array, r: int) -> void:
	for i in pts.size() - 1:
		for p in _line(pts[i], pts[i + 1]):
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if absi(dx) + absi(dy) <= r:
						m[p + Vector2i(dx, dy)] = BODY


# --- Desk with the starter setup ---------------------------------------------

func _desk() -> Image:
	var img := _blank(DESK)
	# Chair (gaming chair, dark purple)
	var chair := Color("#2b1d3a")
	var chair_hi := Color("#4a3366")
	_rect(img, Rect2i(1, 14, 4, 17), chair)
	_rect(img, Rect2i(1, 14, 1, 17), chair_hi)
	_rect(img, Rect2i(1, 30, 14, 3), chair)
	_rect(img, Rect2i(1, 30, 14, 1), chair_hi)
	_rect(img, Rect2i(7, 33, 2, 10), Color("#222228"))
	_rect(img, Rect2i(2, 43, 12, 2), Color("#222228"))
	for x in [2, 13]:
		_rect(img, Rect2i(x - 1, 45, 2, 2), Color("#111114"))

	# Table (wood) with a purple LED strip
	var wood := Color("#6b4428")
	_rect(img, Rect2i(13, 31, 3, 16), Color("#4a2e1b"))
	_rect(img, Rect2i(55, 31, 3, 16), Color("#4a2e1b"))
	_rect(img, Rect2i(12, 28, 48, 3), wood)
	_rect(img, Rect2i(12, 28, 48, 1), Color("#8a5a36"))
	_rect(img, Rect2i(16, 31, 39, 1), Color("#9b4dff"))
	_rect(img, Rect2i(18, 32, 35, 1), Color("#4a2577"))

	# Old laptop: base with keys, screen with green code
	_rect(img, Rect2i(18, 26, 28, 2), Color("#3a3a46"))
	for x in range(19, 33, 2):
		_px(img, Vector2i(x, 26), Color("#6a6a7a"))
	_rect(img, Rect2i(31, 11, 14, 15), Color("#2a2a33"))
	_rect(img, Rect2i(32, 12, 12, 13), Color("#0b1a12"))
	var code := [[1, 6], [2, 8], [2, 5], [1, 9], [3, 6], [1, 4]]
	for i in code.size():
		var y: int = 13 + i * 2
		var x0: int = 32 + code[i][0]
		_rect(img, Rect2i(x0, y, code[i][1], 1), Color("#3cff7a") if i % 2 == 0 else Color("#2aa858"))
	_px(img, Vector2i(37, 23), Color("#3cff7a"))  # cursor

	# Cup with steam
	_rect(img, Rect2i(47, 23, 4, 5), Color("#e8e0d0"))
	_rect(img, Rect2i(47, 23, 4, 1), Color("#5a3a20"))
	_rect(img, Rect2i(51, 24, 1, 3), Color("#e8e0d0"))
	for p in [Vector2i(48, 21), Vector2i(49, 20), Vector2i(48, 19)]:
		_px(img, p, Color("#8a8a98"))

	# Plant
	_rect(img, Rect2i(54, 24, 5, 4), Color("#a0522d"))
	_rect(img, Rect2i(54, 24, 5, 1), Color("#c06a3a"))
	for p in [Vector2i(56, 23), Vector2i(56, 22), Vector2i(55, 21), Vector2i(57, 21), Vector2i(54, 20),
			Vector2i(58, 20), Vector2i(56, 19), Vector2i(53, 22), Vector2i(59, 22), Vector2i(55, 19)]:
		_px(img, p, Color("#3a8a3a"))
	for p in [Vector2i(56, 20), Vector2i(54, 21), Vector2i(58, 21)]:
		_px(img, p, Color("#5ab05a"))

	_outline(img)
	return img


## Light rim around everything visible (outside only).
func _outline(img: Image) -> void:
	var edge: Array[Vector2i] = []
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2i(x, y)
			if img.get_pixelv(p).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if _inside(img, q) and img.get_pixelv(q).a > 0.0 and img.get_pixelv(q) != OUT:
					edge.append(p)
					break
	for p in edge:
		img.set_pixelv(p, OUT)


# --- Helpers ----------------------------------------------------------------

func _blank(size: Vector2i) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _rect(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r, c)


func _px(img: Image, p: Vector2i, c: Color) -> void:
	if _inside(img, p):
		img.set_pixelv(p, c)


func _inside(img: Image, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height()


func _line(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := 0.0 if n == 0 else float(i) / n
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out


func _sheet(name: String, frames: Array) -> void:
	var fs: Vector2i = frames[0].get_size()
	var sheet := _blank(Vector2i(fs.x * frames.size(), fs.y))
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, fs), Vector2i(i * fs.x, 0))
	sheet.save_png(ProjectSettings.globalize_path("res://tools/generated/%s.png" % name))
	var big := _blank(sheet.get_size())
	big.fill(Color(0.35, 0.35, 0.35))
	big.blend_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
	big.resize(sheet.get_width() * 8, sheet.get_height() * 8, Image.INTERPOLATE_NEAREST)
	big.save_png(ProjectSettings.globalize_path("res://tools/preview/%s_preview8x.png" % name))
