class_name Fx
## Общие приёмы рисования в духе Ori: мягкое свечение и гладкие формы без углов.

static var _glow: GradientTexture2D


## Круглое мягкое пятно света: яркое в центре и прозрачное к краю.
static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(0.5, 0.0)
		_glow.width = 128
		_glow.height = 128
	return _glow


static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(glow_texture(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


static func ellipse(center: Vector2, radii: Vector2, rot := 0.0, points := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * i / points
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
	return pts


## Капля: круглая с одной стороны и заострённая с другой (тело, хвост, рожки).
static func teardrop(base: Vector2, tip: Vector2, radius: float, points := 20) -> PackedVector2Array:
	var dir := (tip - base).normalized()
	var side := dir.orthogonal()
	var pts := PackedVector2Array()
	for i in points + 1:
		var a := PI * 0.5 + PI * i / points
		pts.append(base + (dir * cos(a) + side * sin(a)) * radius)
	pts.append(tip)
	return pts


## Плавная лента по точкам: широкая в начале, тонкая в конце (хоботок, шлейф).
static func ribbon(pts: Array[Vector2], w0: float, w1: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in pts.size():
		var t := float(i) / maxf(pts.size() - 1, 1)
		var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := d.orthogonal() * lerpf(w0, w1, t) * 0.5
		left.append(pts[i] + n)
		right.append(pts[i] - n)
	right.reverse()
	left.append_array(right)
	return left
