class_name ForestBackground
extends Node2D
## Фон в духе Ori: небо-градиент, три слоя силуэтов деревьев с параллаксом,
## полосы тумана, лучи света и летающие светлячки. Всё рисуется кодом;
## позже слои можно заменить нарисованными художником картинками.

const LAYERS := [
	# scroll — насколько слой отстаёт от камеры, color — цвет силуэтов (дальше — светлее)
	{"scroll": 0.15, "color": Color("2F6E7E"), "trees": 9, "width": Vector2(18, 34), "z": -30},
	{"scroll": 0.35, "color": Color("1E4D5F"), "trees": 7, "width": Vector2(28, 50), "z": -20},
	{"scroll": 0.6, "color": Color("12313F"), "trees": 5, "width": Vector2(40, 70), "z": -10},
]
const REPEAT := 1400.0

var level_size := Vector2(3072, 704)


func _ready() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	var sky := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color("0A2236"))
	g.set_color(1, Color("7CC2C0"))
	g.add_point(0.55, Color("1F5A6E"))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	sky.texture = tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_layer.add_child(sky)

	for i in LAYERS.size():
		var spec: Dictionary = LAYERS[i]
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(spec.scroll, spec.scroll * 0.5 + 0.5)
		p.repeat_size = Vector2(REPEAT, 0)
		p.repeat_times = 4
		p.z_index = spec.z
		add_child(p)
		var trees := _TreeLayer.new()
		trees.spec = spec
		trees.seed_value = 17 + i * 31
		p.add_child(trees)

	# Светлячки по всему уровню.
	var motes := CPUParticles2D.new()
	motes.amount = 90
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = level_size * 0.5
	motes.position = level_size * 0.5
	motes.direction = Vector2.UP
	motes.spread = 180.0
	motes.gravity = Vector2(0, -4)
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 14.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.5
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 1.0, 0.9, 0.0))
	fade.add_point(0.5, Color(0.85, 1.0, 0.9, 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(0.85, 1.0, 0.9, 0.0))
	motes.color_ramp = fade
	motes.z_index = -5
	add_child(motes)


class _TreeLayer extends Node2D:
	var spec: Dictionary
	var seed_value := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var col: Color = spec.color
		var ground := 760.0
		# Лучи света сверху.
		for i in 2:
			var x := rng.randf_range(100, ForestBackground.REPEAT - 100)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, -600), Vector2(x + 60, -600), Vector2(x + 260, ground), Vector2(x + 120, ground),
			]), Color(1.0, 0.95, 0.75, 0.035))
		var n: int = spec.trees
		for i in n:
			var x := (i + rng.randf_range(0.1, 0.9)) * ForestBackground.REPEAT / n
			var w := rng.randf_range(spec.width.x, spec.width.y)
			var lean := rng.randf_range(-0.08, 0.08)
			var top := rng.randf_range(-700, -300)
			# Ствол сужается кверху, у земли расходятся корни.
			var trunk := PackedVector2Array([
				Vector2(x - w * 1.6, ground), Vector2(x - w * 0.5, ground - 60),
				Vector2(x - w * 0.35 + (ground - top) * lean, top),
				Vector2(x + w * 0.35 + (ground - top) * lean, top),
				Vector2(x + w * 0.5, ground - 60), Vector2(x + w * 1.6, ground),
			])
			draw_colored_polygon(trunk, col)
			# Крона из мягких кругов.
			var cx := x + (ground - top) * lean
			for k in 7:
				var r := rng.randf_range(w * 1.2, w * 2.4)
				draw_circle(Vector2(cx + rng.randf_range(-w * 2.5, w * 2.5), top + rng.randf_range(-40, 80)), r, col)
			# Свисающие лианы.
			for k in 3:
				var vx := cx + rng.randf_range(-w * 2.0, w * 2.0)
				var vy := top + rng.randf_range(40, 100)
				draw_line(Vector2(vx, vy), Vector2(vx + rng.randf_range(-6, 6), vy + rng.randf_range(80, 220)), col, 2.0, true)
		# Туман между слоями.
		for i in 4:
			Fx.glow(self, Vector2(i * ForestBackground.REPEAT / 4.0 + 150, ground - 120), 420.0, Color(0.7, 0.92, 0.95, 0.10))
