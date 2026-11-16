class_name XiloDraw
extends RefCounted

## Biblioteca estática de desenho procedural de Xilogravura 2D (GDScript 2.0).
## Opera diretamente sobre CanvasItem._draw() usando primitivos nativos do Godot 4.7.


# ============================================================================
# 0. PRIMITIVAS DE APOIO & HACHURAS DE XILOGRAVURA
# ============================================================================

static func _ellipse_points(
	center: Vector2,
	rx: float,
	ry: float,
	rot: float = 0.0,
	segments: int = 24
) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(segments)
	var cos_r: float = cos(rot)
	var sin_r: float = sin(rot)
	for i: int in range(segments):
		var a: float = (float(i) / float(segments)) * TAU
		var lx: float = cos(a) * rx
		var ly: float = sin(a) * ry
		pts[i] = center + Vector2(lx * cos_r - ly * sin_r, lx * sin_r + ly * cos_r)
	return pts


static func draw_ellipse_filled(
	canvas: CanvasItem,
	center: Vector2,
	rx: float,
	ry: float,
	color: Color,
	rot: float = 0.0,
	segments: int = 24
) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var pts: PackedVector2Array = _ellipse_points(center, rx, ry, rot, segments)
	canvas.draw_colored_polygon(pts, color)


static func draw_ellipse_outline(
	canvas: CanvasItem,
	center: Vector2,
	rx: float,
	ry: float,
	color: Color,
	width: float = 1.5,
	rot: float = 0.0,
	segments: int = 24
) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var pts: PackedVector2Array = _ellipse_points(center, rx, ry, rot, segments)
	pts.append(pts[0])
	canvas.draw_polyline(pts, color, width, true)


static func draw_ellipse_xilo(
	canvas: CanvasItem,
	center: Vector2,
	rx: float,
	ry: float,
	fill_color: Color,
	stroke_color: Color = XiloPalette.BLACK,
	stroke_width: float = 1.5,
	rot: float = 0.0,
	segments: int = 24
) -> void:
	draw_ellipse_filled(canvas, center, rx, ry, fill_color, rot, segments)
	if stroke_width > 0.0:
		draw_ellipse_outline(canvas, center, rx, ry, stroke_color, stroke_width, rot, segments)


static func draw_circle_xilo(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	fill_color: Color,
	stroke_color: Color = XiloPalette.BLACK,
	stroke_width: float = 1.5
) -> void:
	canvas.draw_circle(center, radius, fill_color)
	if stroke_width > 0.0:
		canvas.draw_arc(center, radius, 0.0, TAU, 28, stroke_color, stroke_width, true)


static func draw_rect_xilo(
	canvas: CanvasItem,
	rect: Rect2,
	fill_color: Color,
	stroke_color: Color = XiloPalette.BLACK,
	stroke_width: float = 1.5
) -> void:
	canvas.draw_rect(rect, fill_color, true)
	if stroke_width > 0.0:
		canvas.draw_rect(rect, stroke_color, false, stroke_width)


static func _rounded_rect_points(rect: Rect2, radius: float, segments_per_corner: int = 4) -> PackedVector2Array:
	var r: float = minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	if r <= 0.5:
		return PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	var start_angles: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c_idx: int in range(4):
		var c: Vector2 = corners[c_idx]
		var a0: float = start_angles[c_idx]
		for s: int in range(segments_per_corner + 1):
			var a: float = a0 + (float(s) / float(segments_per_corner)) * (PI * 0.5)
			pts.append(c + Vector2(cos(a) * r, sin(a) * r))
	return pts


static func draw_rounded_rect_xilo(
	canvas: CanvasItem,
	rect: Rect2,
	radius: float,
	fill_color: Color,
	stroke_color: Color = XiloPalette.BLACK,
	stroke_width: float = 1.5
) -> void:
	var pts: PackedVector2Array = _rounded_rect_points(rect, radius)
	canvas.draw_colored_polygon(pts, fill_color)
	if stroke_width > 0.0:
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		canvas.draw_polyline(outline, stroke_color, stroke_width, true)


static func draw_quadratic_curve(
	canvas: CanvasItem,
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	color: Color,
	width: float = 2.0,
	steps: int = 14
) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(steps + 1)
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var omt: float = 1.0 - t
		pts[i] = omt * omt * p0 + 2.0 * omt * t * p1 + t * t * p2
	canvas.draw_polyline(pts, color, width, true)


static func draw_cubic_bezier(
	canvas: CanvasItem,
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	color: Color,
	width: float = 2.0,
	steps: int = 16
) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(steps + 1)
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var omt: float = 1.0 - t
		var omt2: float = omt * omt
		var t2: float = t * t
		pts[i] = omt2 * omt * p0 + 3.0 * omt2 * t * p1 + 3.0 * omt * t2 * p2 + t2 * t * p3
	canvas.draw_polyline(pts, color, width, true)


static func draw_star(
	canvas: CanvasItem,
	center: Vector2,
	outer_r: float,
	inner_r: float,
	color: Color,
	points: int = 5
) -> void:
	var poly: PackedVector2Array = PackedVector2Array()
	var total: int = points * 2
	poly.resize(total)
	for i: int in range(total):
		var r: float = outer_r if i % 2 == 0 else inner_r
		var a: float = -PI * 0.5 + (float(i) / float(total)) * TAU
		poly[i] = center + Vector2(cos(a) * r, sin(a) * r)
	canvas.draw_colored_polygon(poly, color)


static func draw_hachuras(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color = XiloPalette.WHITE_HATCH,
	spacing: float = 8.0,
	angle_deg: float = -45.0,
	line_width: float = 1.2,
	cross: bool = false
) -> void:
	var step: float = maxf(2.0, spacing)
	var dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var center: Vector2 = rect.get_center()
	var diag: float = rect.size.length()
	var half_diag: float = diag * 0.5
	var count: int = int(ceilf(diag / step))

	for i: int in range(-count, count + 1):
		var offset: Vector2 = normal * (float(i) * step)
		var p_a: Vector2 = center + offset - dir * half_diag
		var p_b: Vector2 = center + offset + dir * half_diag
		var clipped: Array[Vector2] = _clip_segment_to_rect(p_a, p_b, rect)
		if clipped.size() == 2:
			canvas.draw_line(clipped[0], clipped[1], color, line_width, true)

	if cross:
		draw_hachuras(canvas, rect, color, spacing, angle_deg + 90.0, line_width, false)


static func _clip_segment_to_rect(p0: Vector2, p1: Vector2, rect: Rect2) -> Array[Vector2]:
	var d: Vector2 = p1 - p0
	var t0: float = 0.0
	var t1: float = 1.0
	var checks: Array[Array] = [
		[-d.x, p0.x - rect.position.x],
		[d.x, rect.end.x - p0.x],
		[-d.y, p0.y - rect.position.y],
		[d.y, rect.end.y - p0.y],
	]
	for pair: Array in checks:
		var p: float = float(pair[0])
		var q: float = float(pair[1])
		if absf(p) < 0.00001:
			if q < 0.0:
				return []
		else:
			var r: float = q / p
			if p < 0.0:
				if r > t1:
					return []
				if r > t0:
					t0 = r
			else:
				if r < t0:
					return []
				if r < t1:
					t1 = r
	return [p0 + d * t0, p0 + d * t1]


# ============================================================================
# 1. BORDAS & MOLDURAS DE CORDEL
# ============================================================================

static func draw_moldura_cordel(
	canvas: CanvasItem,
	rect: Rect2,
	border_weight: float = 4.0,
	color: Color = XiloPalette.BLACK
) -> void:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y

	# Borda Externa Grossa
	canvas.draw_rect(rect, color, false, border_weight)
	# Borda Interna Fina
	if w > 16.0 and h > 16.0:
		canvas.draw_rect(Rect2(x + 6.0, y + 6.0, w - 12.0, h - 12.0), color, false, 1.5)

	# Cantoneiras Tradicionais de Xilo
	var cs: float = 14.0
	var corners: Array[Vector2] = [
		Vector2(x + 6.0, y + 6.0),
		Vector2(x + w - 6.0 - cs, y + 6.0),
		Vector2(x + 6.0, y + h - 6.0 - cs),
		Vector2(x + w - 6.0 - cs, y + h - 6.0 - cs),
	]
	for c: Vector2 in corners:
		canvas.draw_rect(Rect2(c.x, c.y, cs, cs), color, true)
		canvas.draw_rect(Rect2(c.x + 4.0, c.y + 4.0, cs - 8.0, cs - 8.0), XiloPalette.WHITE_HATCH, true)

	# Dentes-de-serra ornamentais nas bordas superior e inferior
	var dx: float = x + 30.0
	while dx < x + w - 30.0:
		var top_pts: PackedVector2Array = PackedVector2Array([
			Vector2(dx, y + 6.0),
			Vector2(dx + 6.0, y + 12.0),
			Vector2(dx + 12.0, y + 6.0),
		])
		var bot_pts: PackedVector2Array = PackedVector2Array([
			Vector2(dx, y + h - 6.0),
			Vector2(dx + 6.0, y + h - 12.0),
			Vector2(dx + 12.0, y + h - 6.0),
		])
		canvas.draw_polyline(top_pts, color, 1.5, true)
		canvas.draw_polyline(bot_pts, color, 1.5, true)
		dx += 12.0


# ============================================================================
# 2. PERSONAGENS & MONSTROS FOLCLÓRICOS
# ============================================================================

static func draw_coisinha(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(36.0, 48.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var is_moving: bool = bool(options.get("is_moving", false))
	var is_invuln: bool = bool(options.get("is_invulnerable", false))
	var facing: String = str(options.get("facing", "right"))
	var dir_x: float = -1.0 if facing == "left" else 1.0
	var alpha: float = float(options.get("alpha", 1.0))

	if is_invuln:
		var is_blinking: bool = int(floor(t * 14.0)) % 2 == 0
		alpha = 0.35 if is_blinking else 0.95

	var w: float = size.x
	var h: float = size.y
	var bob: float = sin(t * 12.0) * 2.0 if is_moving else sin(t * 3.0) * 0.8

	var col_black: Color = Color(XiloPalette.BLACK, alpha)
	var col_wood: Color = Color(XiloPalette.DARK_WOOD, alpha)
	var col_paper: Color = Color(XiloPalette.KRAFT_PAPER, alpha)
	var col_dark_paper: Color = Color(XiloPalette.KRAFT_DARK, alpha)
	var col_white: Color = Color(XiloPalette.WHITE_HATCH, alpha)
	var col_gold: Color = Color(XiloPalette.GOLD_ACCENT, alpha)
	var col_red: Color = Color(XiloPalette.RED_ACCENT, alpha)
	var col_shadow: Color = Color(0.0, 0.0, 0.0, 0.35 * alpha)

	# Sombra no chão
	draw_ellipse_filled(canvas, pos + Vector2(0.0, h * 0.45), w * 0.4, h * 0.15, col_shadow)

	# Corpo / Gibão de Couro
	draw_rect_xilo(
		canvas,
		Rect2(pos.x - w * 0.28, pos.y - h * 0.1 + bob, w * 0.56, h * 0.45),
		col_black,
		Color.TRANSPARENT,
		0.0
	)

	# Costuras brancas de xilo no gibão
	canvas.draw_line(pos + Vector2(0.0, -h * 0.1 + bob), pos + Vector2(0.0, h * 0.35 + bob), col_white, 1.5, true)
	canvas.draw_line(pos + Vector2(-w * 0.15, h * 0.05 + bob), pos + Vector2(w * 0.15, h * 0.05 + bob), col_white, 1.5, true)
	canvas.draw_line(pos + Vector2(-w * 0.18, h * 0.2 + bob), pos + Vector2(w * 0.18, h * 0.2 + bob), col_white, 1.5, true)

	# Cinto sertanejo
	draw_rect_xilo(
		canvas,
		Rect2(pos.x - w * 0.24, pos.y + h * 0.26 + bob, w * 0.48, h * 0.08),
		col_gold,
		col_black,
		1.0
	)

	# Pernas / Botas de couro
	var leg_offset: float = sin(t * 12.0) * 4.0 if is_moving else 0.0
	canvas.draw_rect(Rect2(pos.x - w * 0.22, pos.y + h * 0.35 + bob, w * 0.18, maxf(2.0, h * 0.2 - leg_offset)), col_wood, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.04, pos.y + h * 0.35 + bob, w * 0.18, maxf(2.0, h * 0.2 + leg_offset)), col_wood, true)
	canvas.draw_rect(Rect2(pos.x - w * 0.25, pos.y + h * 0.46 + bob - leg_offset, w * 0.22, h * 0.1), col_black, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.02, pos.y + h * 0.46 + bob + leg_offset, w * 0.22, h * 0.1), col_black, true)

	# Rosto de Xilogravura
	var head_c: Vector2 = pos + Vector2(0.0, -h * 0.18 + bob)
	draw_circle_xilo(canvas, head_c, w * 0.22, col_paper, col_black, 2.0)

	# Olhos atentos & Bigodinho sertanejo
	var eye_shift: float = dir_x * w * 0.02
	canvas.draw_rect(Rect2(pos.x - w * 0.1 + eye_shift, pos.y - h * 0.22 + bob, w * 0.06, h * 0.06), col_black, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.04 + eye_shift, pos.y - h * 0.22 + bob, w * 0.06, h * 0.06), col_black, true)
	draw_ellipse_filled(canvas, pos + Vector2(-w * 0.06 + eye_shift, -h * 0.13 + bob), w * 0.07, h * 0.03, col_black)
	draw_ellipse_filled(canvas, pos + Vector2(w * 0.06 + eye_shift, -h * 0.13 + bob), w * 0.07, h * 0.03, col_black)

	# Lenço Vermelho no pescoço
	var scarf: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-w * 0.12, -h * 0.08 + bob),
		pos + Vector2(w * 0.12, -h * 0.08 + bob),
		pos + Vector2(0.0, h * 0.02 + bob),
	])
	canvas.draw_colored_polygon(scarf, col_red)
	var scarf_line: PackedVector2Array = scarf.duplicate()
	scarf_line.append(scarf[0])
	canvas.draw_polyline(scarf_line, col_black, 1.2, true)

	# Chapéu de Couro Meia-Lua Sertanejo
	draw_ellipse_xilo(canvas, pos + Vector2(0.0, -h * 0.28 + bob), w * 0.52, h * 0.16, col_wood, col_black, 2.0)
	# Copa frontal alta (semicírculo)
	var crown_pts: PackedVector2Array = PackedVector2Array()
	var crown_c: Vector2 = pos + Vector2(0.0, -h * 0.30 + bob)
	for i: int in range(13):
		var a: float = PI + (float(i) / 12.0) * PI
		crown_pts.append(crown_c + Vector2(cos(a) * w * 0.30, sin(a) * w * 0.28))
	canvas.draw_colored_polygon(crown_pts, col_black)
	canvas.draw_polyline(crown_pts, col_dark_paper, 1.5, true)

	# Estrela Sertaneja Branca de Xilo no Chapéu
	draw_star(canvas, pos + Vector2(0.0, -h * 0.36 + bob), w * 0.11, w * 0.045, col_white, 5)


static func draw_bode(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(44.0, 36.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var is_moving: bool = bool(options.get("is_moving", false))
	var facing: String = str(options.get("facing", "right"))
	var sx: float = -1.0 if facing == "left" else 1.0
	var w: float = size.x
	var h: float = size.y
	var wiggle: float = sin(t * 10.0) * 3.0 if is_moving else sin(t * 2.0) * 1.0

	# Sombra
	draw_ellipse_filled(canvas, pos + Vector2(0.0, h * 0.4), w * 0.42, h * 0.12, XiloPalette.SHADOW_GROUND)

	# Corpo do Bode (bloco preto arredondado com contorno darkWood)
	var body_x: float = pos.x - w * 0.35 if sx > 0.0 else pos.x - w * 0.30
	var body_rect: Rect2 = Rect2(body_x, pos.y - h * 0.1 + wiggle * 0.3, w * 0.65, h * 0.45)
	draw_rounded_rect_xilo(canvas, body_rect, 8.0, XiloPalette.BLACK, XiloPalette.DARK_WOOD, 2.0)

	# Hachuras brancas no pelo
	var hi: float = -0.22
	while hi <= 0.18:
		canvas.draw_line(
			pos + Vector2(sx * w * hi, -h * 0.02 + wiggle * 0.3),
			pos + Vector2(sx * w * (hi - 0.05), h * 0.25 + wiggle * 0.3),
			XiloPalette.WHITE_HATCH,
			1.2,
			true
		)
		hi += 0.10

	# 4 Patas de madeira talhada
	var leg_1: float = sin(t * 10.0) * 4.0 if is_moving else 0.0
	var leg_2: float = -leg_1
	canvas.draw_rect(Rect2(pos.x + sx * (-w * 0.3) - (w * 0.04 if sx < 0.0 else 0.0), pos.y + h * 0.28 + leg_1, w * 0.08, h * 0.2), XiloPalette.BLACK, true)
	canvas.draw_rect(Rect2(pos.x + sx * (-w * 0.18) - (w * 0.04 if sx < 0.0 else 0.0), pos.y + h * 0.28 + leg_2, w * 0.08, h * 0.2), XiloPalette.BLACK, true)
	canvas.draw_rect(Rect2(pos.x + sx * (w * 0.12) - (w * 0.04 if sx < 0.0 else 0.0), pos.y + h * 0.28 + leg_2, w * 0.08, h * 0.2), XiloPalette.BLACK, true)
	canvas.draw_rect(Rect2(pos.x + sx * (w * 0.22) - (w * 0.04 if sx < 0.0 else 0.0), pos.y + h * 0.28 + leg_1, w * 0.08, h * 0.2), XiloPalette.BLACK, true)

	# Rabinho empinado
	var tail: PackedVector2Array = PackedVector2Array([
		pos + Vector2(sx * -w * 0.35, -h * 0.05 + wiggle),
		pos + Vector2(sx * -w * 0.45, -h * 0.18 + wiggle),
		pos + Vector2(sx * -w * 0.38, -h * 0.02 + wiggle),
	])
	canvas.draw_colored_polygon(tail, XiloPalette.BLACK)

	# Cabeça do Bode
	draw_ellipse_xilo(
		canvas,
		pos + Vector2(sx * w * 0.28, -h * 0.15 + wiggle),
		w * 0.18,
		h * 0.2,
		XiloPalette.BLACK,
		XiloPalette.WHITE_HATCH,
		1.0,
		sx * PI * 0.15
	)

	# Olho branco e pupila horizontal
	var eye_pos: Vector2 = pos + Vector2(sx * w * 0.32, -h * 0.2 + wiggle)
	canvas.draw_circle(eye_pos, w * 0.045, XiloPalette.WHITE_HATCH)
	canvas.draw_rect(Rect2(eye_pos.x - w * 0.02, eye_pos.y - w * 0.01, w * 0.04, w * 0.02), XiloPalette.BLACK, true)

	# Barbicha branca
	var beard: PackedVector2Array = PackedVector2Array([
		pos + Vector2(sx * w * 0.28, -h * 0.02 + wiggle),
		pos + Vector2(sx * w * 0.22, h * 0.15 + wiggle),
		pos + Vector2(sx * w * 0.35, wiggle),
	])
	canvas.draw_colored_polygon(beard, XiloPalette.WHITE_HATCH)

	# Chifres curvados
	draw_quadratic_curve(
		canvas,
		pos + Vector2(sx * w * 0.24, -h * 0.28 + wiggle),
		pos + Vector2(sx * w * 0.15, -h * 0.48 + wiggle),
		pos + Vector2(sx * -w * 0.02, -h * 0.35 + wiggle),
		XiloPalette.GOLD_ACCENT,
		3.5
	)
	draw_quadratic_curve(
		canvas,
		pos + Vector2(sx * w * 0.28, -h * 0.28 + wiggle),
		pos + Vector2(sx * w * 0.2, -h * 0.45 + wiggle),
		pos + Vector2(sx * w * 0.05, -h * 0.32 + wiggle),
		XiloPalette.BLACK,
		2.0
	)

	# Sininho / Guizo
	draw_circle_xilo(canvas, pos + Vector2(sx * w * 0.24, wiggle), w * 0.06, XiloPalette.GOLD_ACCENT, XiloPalette.BLACK, 1.0)


static func draw_chupa_cabra(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(60.0, 60.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var flap: float = sin(t * 8.0) * 0.2
	var w: float = size.x
	var h: float = size.y

	# Aura ameaçadora
	canvas.draw_circle(pos, w * 0.7, Color(0.725, 0.11, 0.11, 0.15))

	# Asas Membranosas
	var left_wing: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-w * 0.15, -h * 0.1),
		pos + Vector2(-w * 0.7, -h * 0.5 + flap * h),
		pos + Vector2(-w * 0.55, flap * h * 0.5),
		pos + Vector2(-w * 0.35, -h * 0.05),
	])
	var right_wing: PackedVector2Array = PackedVector2Array([
		pos + Vector2(w * 0.15, -h * 0.1),
		pos + Vector2(w * 0.7, -h * 0.5 + flap * h),
		pos + Vector2(w * 0.55, flap * h * 0.5),
		pos + Vector2(w * 0.35, -h * 0.05),
	])
	canvas.draw_colored_polygon(left_wing, XiloPalette.BLACK)
	canvas.draw_colored_polygon(right_wing, XiloPalette.BLACK)

	# Nervuras brancas das asas
	canvas.draw_line(pos + Vector2(-w * 0.15, -h * 0.1), pos + Vector2(-w * 0.7, -h * 0.5 + flap * h), XiloPalette.WHITE_HATCH, 1.2, true)
	canvas.draw_line(pos + Vector2(w * 0.15, -h * 0.1), pos + Vector2(w * 0.7, -h * 0.5 + flap * h), XiloPalette.WHITE_HATCH, 1.2, true)

	# Corpo Demoníaco
	draw_ellipse_xilo(canvas, pos, w * 0.26, h * 0.38, XiloPalette.BLACK, XiloPalette.RED_ACCENT, 1.5)

	# Espinhos dorsais
	var si: float = -0.3
	while si <= 0.31:
		var sp: PackedVector2Array = PackedVector2Array([
			pos + Vector2(0.0, h * si - h * 0.05),
			pos + Vector2(w * 0.12, h * si),
			pos + Vector2(0.0, h * si + h * 0.05),
		])
		canvas.draw_colored_polygon(sp, XiloPalette.RED_ACCENT)
		si += 0.15

	# Cabeça & Orelhas pontudas
	canvas.draw_circle(pos + Vector2(0.0, -h * 0.28), w * 0.24, XiloPalette.BLACK)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-w * 0.2, -h * 0.3),
		pos + Vector2(-w * 0.32, -h * 0.55),
		pos + Vector2(-w * 0.08, -h * 0.4),
	]), XiloPalette.BLACK)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(w * 0.2, -h * 0.3),
		pos + Vector2(w * 0.32, -h * 0.55),
		pos + Vector2(w * 0.08, -h * 0.4),
	]), XiloPalette.BLACK)

	# Olhos Rubros Brilhantes (com halo suave)
	var eye_l: Vector2 = pos + Vector2(-w * 0.1, -h * 0.3)
	var eye_r: Vector2 = pos + Vector2(w * 0.1, -h * 0.3)
	canvas.draw_circle(eye_l, w * 0.09, Color(0.86, 0.15, 0.15, 0.35))
	canvas.draw_circle(eye_r, w * 0.09, Color(0.86, 0.15, 0.15, 0.35))
	canvas.draw_circle(eye_l, w * 0.06, XiloPalette.RED_ACCENT)
	canvas.draw_circle(eye_r, w * 0.06, XiloPalette.RED_ACCENT)

	# Presas Longas e Afiadas
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-w * 0.08, -h * 0.22),
		pos + Vector2(-w * 0.05, -h * 0.1),
		pos + Vector2(-w * 0.02, -h * 0.22),
	]), XiloPalette.WHITE_HATCH)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(w * 0.02, -h * 0.22),
		pos + Vector2(w * 0.05, -h * 0.1),
		pos + Vector2(w * 0.08, -h * 0.22),
	]), XiloPalette.WHITE_HATCH)

	# Garras
	canvas.draw_rect(Rect2(pos.x - w * 0.2, pos.y + h * 0.35, w * 0.08, h * 0.08), XiloPalette.WHITE_HATCH, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.12, pos.y + h * 0.35, w * 0.08, h * 0.08), XiloPalette.WHITE_HATCH, true)


static func draw_cumade_fulozinha(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(48.0, 54.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var hair_wave: float = sin(t * 6.0) * 6.0
	var w: float = size.x
	var h: float = size.y
	var has_tint: bool = options.has("color_tint") and options["color_tint"] is Color and (options["color_tint"] as Color).a > 0.0
	var aura_color: Color = options["color_tint"] as Color if has_tint else Color(0.918, 0.702, 0.031, 0.18)

	# Brilho Místico
	canvas.draw_circle(pos, w * 0.65, aura_color)

	# Cabelos Longos e Chicoteantes
	draw_cubic_bezier(
		canvas,
		pos + Vector2(-w * 0.15, -h * 0.25),
		pos + Vector2(-w * 0.6 + hair_wave, 0.0),
		pos + Vector2(-w * 0.4 - hair_wave, h * 0.4),
		pos + Vector2(-w * 0.7 + hair_wave, h * 0.6),
		XiloPalette.BLACK,
		3.0
	)
	draw_cubic_bezier(
		canvas,
		pos + Vector2(w * 0.15, -h * 0.25),
		pos + Vector2(w * 0.6 - hair_wave, 0.0),
		pos + Vector2(w * 0.4 + hair_wave, h * 0.4),
		pos + Vector2(w * 0.7 - hair_wave, h * 0.6),
		XiloPalette.BLACK,
		3.0
	)

	# Vestido de Folhagens
	var dress_col: Color = XiloPalette.RED_ACCENT if has_tint else XiloPalette.GREEN_ACCENT
	var dress_pts: PackedVector2Array = PackedVector2Array([
		pos + Vector2(0.0, -h * 0.1),
		pos + Vector2(-w * 0.3, h * 0.35),
		pos + Vector2(0.0, h * 0.45),
		pos + Vector2(w * 0.3, h * 0.35),
	])
	canvas.draw_colored_polygon(dress_pts, dress_col)
	var dress_line: PackedVector2Array = dress_pts.duplicate()
	dress_line.append(dress_pts[0])
	canvas.draw_polyline(dress_line, XiloPalette.BLACK, 1.5, true)

	# Hachura floral no vestido
	canvas.draw_arc(pos + Vector2(0.0, h * 0.15), w * 0.1, 0.0, TAU, 18, XiloPalette.WHITE_HATCH, 1.0, true)

	# Rosto Delicado
	draw_circle_xilo(canvas, pos + Vector2(0.0, -h * 0.25), w * 0.2, XiloPalette.KRAFT_LIGHT, XiloPalette.BLACK, 1.5)

	# Olhos Luminosos
	var eye_col: Color = XiloPalette.RED_ACCENT if has_tint else XiloPalette.GOLD_ACCENT
	canvas.draw_circle(pos + Vector2(-w * 0.07, -h * 0.26), w * 0.04, eye_col)
	canvas.draw_circle(pos + Vector2(w * 0.07, -h * 0.26), w * 0.04, eye_col)

	# Flor de Mandacaru na cabeça
	canvas.draw_circle(pos + Vector2(w * 0.16, -h * 0.4), w * 0.08, XiloPalette.WHITE_HATCH)
	canvas.draw_circle(pos + Vector2(w * 0.16, -h * 0.4), w * 0.03, XiloPalette.GOLD_ACCENT)


static func draw_rasga_mortalha(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(56.0, 48.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var wing_flap: float = sin(t * 7.0) * 0.25
	var w: float = size.x
	var h: float = size.y

	# Asas Abertas em Voo Rasante
	var wings: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-w * 0.1, -h * 0.1),
		pos + Vector2(-w * 0.8, -h * 0.5 + wing_flap * h),
		pos + Vector2(-w * 0.65, h * 0.1 + wing_flap * h * 0.5),
		pos + Vector2(-w * 0.2, h * 0.15),
		pos + Vector2(w * 0.2, h * 0.15),
		pos + Vector2(w * 0.65, h * 0.1 + wing_flap * h * 0.5),
		pos + Vector2(w * 0.8, -h * 0.5 + wing_flap * h),
		pos + Vector2(w * 0.1, -h * 0.1),
	])
	canvas.draw_colored_polygon(wings, XiloPalette.BLACK)

	# Penas entalhadas (hachuras brancas em leque)
	var step: float = 0.3
	while step <= 0.76:
		canvas.draw_line(
			pos + Vector2(-w * 0.1, -h * 0.05),
			pos + Vector2(-w * step, -h * 0.35 + wing_flap * h + step * 10.0),
			XiloPalette.WHITE_HATCH,
			1.2,
			true
		)
		canvas.draw_line(
			pos + Vector2(w * 0.1, -h * 0.05),
			pos + Vector2(w * step, -h * 0.35 + wing_flap * h + step * 10.0),
			XiloPalette.WHITE_HATCH,
			1.2,
			true
		)
		step += 0.15

	# Corpo da Coruja
	draw_ellipse_xilo(canvas, pos, w * 0.22, h * 0.32, XiloPalette.DARK_WOOD, XiloPalette.BLACK, 2.0)

	# Penugem do Peito
	canvas.draw_arc(pos, w * 0.12, 0.2, PI - 0.2, 12, XiloPalette.WHITE_HATCH, 1.2, true)
	canvas.draw_arc(pos + Vector2(0.0, h * 0.1), w * 0.12, 0.2, PI - 0.2, 12, XiloPalette.WHITE_HATCH, 1.2, true)

	# Cabeça Redonda & Penachos
	canvas.draw_circle(pos + Vector2(0.0, -h * 0.25), w * 0.2, XiloPalette.BLACK)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-w * 0.18, -h * 0.3),
		pos + Vector2(-w * 0.24, -h * 0.48),
		pos + Vector2(-w * 0.08, -h * 0.36),
	]), XiloPalette.BLACK)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(w * 0.18, -h * 0.3),
		pos + Vector2(w * 0.24, -h * 0.48),
		pos + Vector2(w * 0.08, -h * 0.36),
	]), XiloPalette.BLACK)

	# Olhos Grandes Hipnóticos
	canvas.draw_circle(pos + Vector2(-w * 0.09, -h * 0.25), w * 0.075, XiloPalette.GOLD_ACCENT)
	canvas.draw_circle(pos + Vector2(w * 0.09, -h * 0.25), w * 0.075, XiloPalette.GOLD_ACCENT)
	canvas.draw_circle(pos + Vector2(-w * 0.09, -h * 0.25), w * 0.035, XiloPalette.BLACK)
	canvas.draw_circle(pos + Vector2(w * 0.09, -h * 0.25), w * 0.035, XiloPalette.BLACK)

	# Bico Curvo
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0.0, -h * 0.22),
		pos + Vector2(-w * 0.04, -h * 0.14),
		pos + Vector2(w * 0.04, -h * 0.14),
	]), XiloPalette.GOLD_ACCENT)


static func draw_fazendeiro(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(40.0, 48.0),
	_options: Dictionary = {}
) -> void:
	var w: float = size.x
	var h: float = size.y

	# Camisa Xadrez de Xilogravura
	draw_rect_xilo(
		canvas,
		Rect2(pos.x - w * 0.3, pos.y - h * 0.05, w * 0.6, h * 0.45),
		XiloPalette.GREEN_ACCENT,
		XiloPalette.BLACK,
		1.5
	)
	canvas.draw_line(pos + Vector2(-w * 0.1, -h * 0.05), pos + Vector2(-w * 0.1, h * 0.4), XiloPalette.WHITE_HATCH, 1.0, true)
	canvas.draw_line(pos + Vector2(w * 0.1, -h * 0.05), pos + Vector2(w * 0.1, h * 0.4), XiloPalette.WHITE_HATCH, 1.0, true)

	# Rosto & Bigode Farto
	draw_circle_xilo(canvas, pos + Vector2(0.0, -h * 0.2), w * 0.22, XiloPalette.KRAFT_PAPER, XiloPalette.BLACK, 1.5)
	draw_ellipse_xilo(canvas, pos + Vector2(0.0, -h * 0.13), w * 0.18, h * 0.06, XiloPalette.WHITE_HATCH, XiloPalette.BLACK, 1.0)

	# Chapéu de Palha
	draw_ellipse_xilo(canvas, pos + Vector2(0.0, -h * 0.32), w * 0.5, h * 0.14, XiloPalette.GOLD_ACCENT, XiloPalette.BLACK, 1.5)
	var crown_pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(11):
		var a: float = PI + (float(i) / 10.0) * PI
		crown_pts.append(pos + Vector2(cos(a) * w * 0.25, -h * 0.34 + sin(a) * w * 0.22))
	canvas.draw_colored_polygon(crown_pts, XiloPalette.DARK_WOOD)


static func draw_beato(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(40.0, 52.0),
	_options: Dictionary = {}
) -> void:
	var w: float = size.x
	var h: float = size.y

	# Batina Longa de Romeiro
	var robe: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-w * 0.2, -h * 0.1),
		pos + Vector2(-w * 0.35, h * 0.45),
		pos + Vector2(w * 0.35, h * 0.45),
		pos + Vector2(w * 0.2, -h * 0.1),
	])
	canvas.draw_colored_polygon(robe, XiloPalette.DARK_WOOD)
	var robe_line: PackedVector2Array = robe.duplicate()
	robe_line.append(robe[0])
	canvas.draw_polyline(robe_line, XiloPalette.BLACK, 2.0, true)

	# Cordão Franciscano
	canvas.draw_line(pos + Vector2(-w * 0.24, h * 0.12), pos + Vector2(w * 0.24, h * 0.12), XiloPalette.WHITE_HATCH, 2.0, true)
	canvas.draw_line(pos + Vector2(w * 0.1, h * 0.12), pos + Vector2(w * 0.12, h * 0.32), XiloPalette.WHITE_HATCH, 2.0, true)

	# Rosto & Barba Branca
	draw_circle_xilo(canvas, pos + Vector2(0.0, -h * 0.2), w * 0.2, XiloPalette.KRAFT_PAPER, XiloPalette.BLACK, 1.5)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-w * 0.15, -h * 0.18),
		pos + Vector2(0.0, h * 0.02),
		pos + Vector2(w * 0.15, -h * 0.18),
	]), XiloPalette.WHITE_HATCH)

	# Crucifixo no Peito
	canvas.draw_rect(Rect2(pos.x - w * 0.04, pos.y - h * 0.02, w * 0.08, h * 0.18), XiloPalette.GOLD_ACCENT, true)
	canvas.draw_rect(Rect2(pos.x - w * 0.1, pos.y + h * 0.02, w * 0.2, h * 0.06), XiloPalette.GOLD_ACCENT, true)

	# Auréola / Chapéu de Palha
	draw_ellipse_outline(canvas, pos + Vector2(0.0, -h * 0.38), w * 0.28, h * 0.08, XiloPalette.GOLD_ACCENT, 2.0)


static func draw_violeiro(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(44.0, 50.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var strum: float = sin(t * 8.0) * 3.0
	var w: float = size.x
	var h: float = size.y
	var shirt_col: Color = XiloPalette.BROWN_WOOD
	if options.has("color_tint") and options["color_tint"] is Color and (options["color_tint"] as Color).a > 0.0:
		shirt_col = options["color_tint"] as Color

	draw_ellipse_filled(canvas, pos + Vector2(0.0, h * 0.42), w * 0.4, h * 0.12, XiloPalette.SHADOW_GROUND)
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.28, pos.y - h * 0.08, w * 0.56, h * 0.45), shirt_col, XiloPalette.BLACK, 1.5)
	canvas.draw_rect(Rect2(pos.x - w * 0.22, pos.y + h * 0.35, w * 0.18, h * 0.15), XiloPalette.DARK_WOOD, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.04, pos.y + h * 0.35, w * 0.18, h * 0.15), XiloPalette.DARK_WOOD, true)

	# Rosto & Chapéu
	draw_circle_xilo(canvas, pos + Vector2(0.0, -h * 0.2), w * 0.2, XiloPalette.KRAFT_PAPER, XiloPalette.BLACK, 1.5)
	draw_ellipse_filled(canvas, pos + Vector2(0.0, -h * 0.12), w * 0.06, h * 0.04, XiloPalette.RED_ACCENT)
	draw_ellipse_xilo(canvas, pos + Vector2(0.0, -h * 0.32), w * 0.48, h * 0.14, XiloPalette.DARK_WOOD, XiloPalette.BLACK, 1.5)

	# Viola em 8 (inclinada)
	var v_origin: Vector2 = pos + Vector2(w * 0.1, h * 0.08)
	var v_rot: float = -PI * 0.2
	var rot_vec := func(v: Vector2) -> Vector2: return v_origin + v.rotated(v_rot)

	draw_circle_xilo(canvas, rot_vec.call(Vector2(0.0, h * 0.08)), w * 0.18, XiloPalette.CERAMICA_BARRO, XiloPalette.BLACK, 1.5)
	draw_circle_xilo(canvas, rot_vec.call(Vector2(0.0, -h * 0.05)), w * 0.14, XiloPalette.CERAMICA_BARRO, XiloPalette.BLACK, 1.5)
	canvas.draw_circle(v_origin, w * 0.05, XiloPalette.BLACK)
	canvas.draw_line(rot_vec.call(Vector2(0.0, -h * 0.32)), rot_vec.call(Vector2(0.0, -h * 0.04)), XiloPalette.DARK_WOOD, w * 0.08, false)
	canvas.draw_line(rot_vec.call(Vector2(-w * 0.02, -h * 0.3)), rot_vec.call(Vector2(-w * 0.02, h * 0.15)), XiloPalette.WHITE_HATCH, 1.0, true)
	canvas.draw_line(rot_vec.call(Vector2(w * 0.02, -h * 0.3)), rot_vec.call(Vector2(w * 0.02, h * 0.15)), XiloPalette.WHITE_HATCH, 1.0, true)

	# Braço dedilhando
	canvas.draw_line(pos + Vector2(-w * 0.15, 0.0), pos + Vector2(w * 0.05 + strum, h * 0.08), XiloPalette.KRAFT_PAPER, 4.0, true)


static func draw_morador_bebado(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(38.0, 48.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var sway_rad: float = deg_to_rad(sin(t * 4.0) * 6.0)
	var w: float = size.x
	var h: float = size.y
	var shirt_col: Color = XiloPalette.STONE_GREY
	if options.has("color_tint") and options["color_tint"] is Color and (options["color_tint"] as Color).a > 0.0:
		shirt_col = options["color_tint"] as Color

	var pt := func(v: Vector2) -> Vector2: return pos + v.rotated(sway_rad)

	draw_ellipse_filled(canvas, pt.call(Vector2(0.0, h * 0.42)), w * 0.38, h * 0.12, XiloPalette.SHADOW_GROUND, sway_rad)
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.26, pos.y - h * 0.08, w * 0.52, h * 0.45), shirt_col, XiloPalette.BLACK, 1.5)
	draw_circle_xilo(canvas, pt.call(Vector2(0.0, -h * 0.2)), w * 0.2, XiloPalette.KRAFT_PAPER, XiloPalette.BLACK, 1.5)

	# Bochechas coradas
	canvas.draw_circle(pt.call(Vector2(-w * 0.1, -h * 0.18)), w * 0.05, Color(0.937, 0.267, 0.267, 0.6))
	canvas.draw_circle(pt.call(Vector2(w * 0.1, -h * 0.18)), w * 0.05, Color(0.937, 0.267, 0.267, 0.6))

	# Chapéu torto
	draw_ellipse_xilo(canvas, pt.call(Vector2(0.0, -h * 0.32)), w * 0.44, h * 0.12, XiloPalette.GOLD_ACCENT, XiloPalette.BLACK, 1.5, sway_rad + 0.3)

	# Garrafa de cachaça
	draw_rect_xilo(canvas, Rect2(pos.x + w * 0.2, pos.y, w * 0.12, h * 0.22), XiloPalette.GARRAFA_VERDE, XiloPalette.BLACK, 1.0)
	canvas.draw_rect(Rect2(pos.x + w * 0.23, pos.y - h * 0.06, w * 0.06, h * 0.08), Color("#92400e"), true)


# ============================================================================
# 3. OS 4 ITENS DA XILOGRAVURA + BOTIJA
# ============================================================================

static func draw_item_carimbo(canvas: CanvasItem, pos: Vector2, s: float = 32.0) -> void:
	draw_rect_xilo(canvas, Rect2(pos.x - s * 0.4, pos.y - s * 0.2, s * 0.8, s * 0.5), XiloPalette.BROWN_WOOD, XiloPalette.BLACK, 2.0)
	canvas.draw_rect(Rect2(pos.x - s * 0.1, pos.y - s * 0.48, s * 0.2, s * 0.3), XiloPalette.DARK_WOOD, true)
	canvas.draw_circle(pos + Vector2(0.0, -s * 0.48), s * 0.14, XiloPalette.DARK_WOOD)
	canvas.draw_rect(Rect2(pos.x - s * 0.32, pos.y + s * 0.25, s * 0.64, s * 0.12), XiloPalette.GOLD_ACCENT, true)
	draw_star(canvas, pos + Vector2(0.0, s * 0.05), s * 0.16, s * 0.07, XiloPalette.WHITE_HATCH, 5)


static func draw_item_folha(canvas: CanvasItem, pos: Vector2, s: float = 32.0) -> void:
	var page: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-s * 0.35, -s * 0.45),
		pos + Vector2(s * 0.35, -s * 0.45),
		pos + Vector2(s * 0.38, s * 0.35),
		pos + Vector2(s * 0.2, s * 0.45),
		pos + Vector2(0.0, s * 0.38),
		pos + Vector2(-s * 0.2, s * 0.48),
		pos + Vector2(-s * 0.38, s * 0.35),
	])
	canvas.draw_colored_polygon(page, XiloPalette.KRAFT_PAPER)
	var outline: PackedVector2Array = page.duplicate()
	outline.append(page[0])
	canvas.draw_polyline(outline, XiloPalette.BLACK, 2.0, true)

	var ly: float = -0.25
	while ly <= 0.21:
		canvas.draw_line(pos + Vector2(-s * 0.25, s * ly), pos + Vector2(s * 0.25, s * ly), XiloPalette.BLACK, 1.5, true)
		ly += 0.12


static func draw_item_pena(canvas: CanvasItem, pos: Vector2, s: float = 32.0) -> void:
	var rot: float = -PI * 0.25
	var rot_p := func(v: Vector2) -> Vector2: return pos + v.rotated(rot)

	# Plumagem Roxa
	var barb: PackedVector2Array = PackedVector2Array([
		rot_p.call(Vector2(0.0, -s * 0.45)),
		rot_p.call(Vector2(-s * 0.22, -s * 0.1)),
		rot_p.call(Vector2(-s * 0.2, s * 0.2)),
		rot_p.call(Vector2(0.0, s * 0.3)),
		rot_p.call(Vector2(s * 0.2, s * 0.2)),
		rot_p.call(Vector2(s * 0.22, -s * 0.1)),
	])
	canvas.draw_colored_polygon(barb, XiloPalette.PURPLE_ACCENT)
	var barb_line: PackedVector2Array = barb.duplicate()
	barb_line.append(barb[0])
	canvas.draw_polyline(barb_line, XiloPalette.BLACK, 1.5, true)

	# Haste central
	canvas.draw_line(rot_p.call(Vector2(0.0, -s * 0.45)), rot_p.call(Vector2(0.0, s * 0.45)), XiloPalette.BLACK, 2.0, true)

	# Ranhuras de entalhe
	var py: float = -0.3
	while py <= 0.16:
		canvas.draw_line(rot_p.call(Vector2(0.0, s * py)), rot_p.call(Vector2(-s * 0.15, s * (py + 0.08))), XiloPalette.WHITE_HATCH, 1.0, true)
		canvas.draw_line(rot_p.call(Vector2(0.0, s * py)), rot_p.call(Vector2(s * 0.15, s * (py + 0.08))), XiloPalette.WHITE_HATCH, 1.0, true)
		py += 0.12


static func draw_item_tinta(canvas: CanvasItem, pos: Vector2, s: float = 32.0) -> void:
	draw_rounded_rect_xilo(
		canvas,
		Rect2(pos.x - s * 0.35, pos.y - s * 0.2, s * 0.7, s * 0.6),
		6.0,
		XiloPalette.BLACK,
		XiloPalette.GOLD_ACCENT,
		1.5
	)
	draw_rect_xilo(canvas, Rect2(pos.x - s * 0.15, pos.y - s * 0.38, s * 0.3, s * 0.2), XiloPalette.BROWN_WOOD, XiloPalette.BLACK, 1.0)
	canvas.draw_rect(Rect2(pos.x - s * 0.22, pos.y - s * 0.05, s * 0.44, s * 0.3), XiloPalette.KRAFT_PAPER, true)
	canvas.draw_circle(pos + Vector2(0.0, s * 0.1), s * 0.08, XiloPalette.BLACK)


static func draw_item_botija(canvas: CanvasItem, pos: Vector2, s: float = 36.0) -> void:
	draw_ellipse_xilo(canvas, pos + Vector2(0.0, s * 0.1), s * 0.38, s * 0.34, XiloPalette.CERAMICA_BARRO, XiloPalette.BLACK, 2.0)
	draw_rect_xilo(canvas, Rect2(pos.x - s * 0.2, pos.y - s * 0.32, s * 0.4, s * 0.16), XiloPalette.GOLD_ACCENT, XiloPalette.BLACK, 1.5)
	# Moedas de ouro reluzentes
	canvas.draw_circle(pos + Vector2(-s * 0.08, s * 0.08), s * 0.09, XiloPalette.OURO_BRILHO)
	canvas.draw_circle(pos + Vector2(s * 0.08, s * 0.12), s * 0.09, XiloPalette.OURO_BRILHO)
	canvas.draw_circle(pos + Vector2(0.0, s * 0.02), s * 0.08, XiloPalette.GOLD_ACCENT)


# ============================================================================
# 4. MOITAS (FECHADA HOMOGÊNEA / REVELADA), CACTO, FRUTA & PEDRA
# ============================================================================

static func draw_moita(
	canvas: CanvasItem,
	pos: Vector2,
	radius: float = 24.0,
	searched: bool = false
) -> void:
	# Moita fechada homogênea: visual idêntico para todas as moitas antes de vasculhar.
	draw_ellipse_filled(canvas, pos + Vector2(0.0, radius * 0.4), radius * 0.9, radius * 0.35, Color(0.0, 0.0, 0.0, 0.25))
	var bush_col: Color = XiloPalette.BUSH_SEARCHED if searched else XiloPalette.BUSH_GREEN
	var c1: Vector2 = pos + Vector2(-radius * 0.35, -radius * 0.1)
	var c2: Vector2 = pos + Vector2(radius * 0.35, -radius * 0.1)
	var c3: Vector2 = pos + Vector2(0.0, -radius * 0.35)

	canvas.draw_circle(c1, radius * 0.5, bush_col)
	canvas.draw_circle(c2, radius * 0.5, bush_col)
	canvas.draw_circle(c3, radius * 0.55, bush_col)

	canvas.draw_arc(c1, radius * 0.5, 0.0, TAU, 20, XiloPalette.BLACK, 2.5, true)
	canvas.draw_arc(c2, radius * 0.5, 0.0, TAU, 20, XiloPalette.BLACK, 2.5, true)
	canvas.draw_arc(c3, radius * 0.55, 0.0, TAU, 20, XiloPalette.BLACK, 2.5, true)

	# Espinhos em leque
	canvas.draw_line(pos + Vector2(0.0, -radius * 0.6), pos + Vector2(0.0, -radius * 0.2), XiloPalette.WHITE_HATCH, 1.2, true)
	canvas.draw_line(pos + Vector2(-radius * 0.3, -radius * 0.4), pos + Vector2(-radius * 0.1, -radius * 0.1), XiloPalette.WHITE_HATCH, 1.2, true)
	canvas.draw_line(pos + Vector2(radius * 0.3, -radius * 0.4), pos + Vector2(radius * 0.1, -radius * 0.1), XiloPalette.WHITE_HATCH, 1.2, true)

	# Florzinha amarela de cacto
	canvas.draw_circle(pos + Vector2(0.0, -radius * 0.55), radius * 0.15, XiloPalette.GOLD_ACCENT)


static func draw_moita_revelada(
	canvas: CanvasItem,
	pos: Vector2,
	radius: float = 24.0,
	revealed_kind: String = ""
) -> void:
	draw_moita(canvas, pos, radius, true)
	match revealed_kind.to_lower():
		"fruta":
			draw_fruta(canvas, pos + Vector2(-radius * 0.25, -radius * 0.2), radius * 0.18, XiloPalette.RED_ACCENT)
			draw_fruta(canvas, pos + Vector2(radius * 0.25, -radius * 0.22), radius * 0.18, XiloPalette.GOLD_ACCENT)
		"espinho", "cacto":
			canvas.draw_line(pos + Vector2(-radius * 0.35, -radius * 0.3), pos + Vector2(-radius * 0.55, -radius * 0.5), XiloPalette.RED_ACCENT, 2.0, true)
			canvas.draw_line(pos + Vector2(radius * 0.35, -radius * 0.3), pos + Vector2(radius * 0.55, -radius * 0.5), XiloPalette.RED_ACCENT, 2.0, true)
		"bode":
			draw_circle_xilo(canvas, pos + Vector2(0.0, -radius * 0.2), radius * 0.22, XiloPalette.GOLD_ACCENT, XiloPalette.BLACK, 1.2)
		"carimbo":
			draw_item_carimbo(canvas, pos + Vector2(0.0, -radius * 0.25), radius * 0.9)
		"folha":
			draw_item_folha(canvas, pos + Vector2(0.0, -radius * 0.25), radius * 0.9)
		"pena":
			draw_item_pena(canvas, pos + Vector2(0.0, -radius * 0.25), radius * 0.9)
		"tinta":
			draw_item_tinta(canvas, pos + Vector2(0.0, -radius * 0.25), radius * 0.9)


static func draw_fruta(
	canvas: CanvasItem,
	pos: Vector2,
	radius: float = 10.0,
	color: Color = XiloPalette.RED_ACCENT
) -> void:
	draw_circle_xilo(canvas, pos, radius, color, XiloPalette.BLACK, 1.2)
	canvas.draw_circle(pos + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.25, Color.WHITE)
	canvas.draw_line(pos + Vector2(0.0, -radius), pos + Vector2(radius * 0.3, -radius * 1.35), XiloPalette.GREEN_ACCENT, 2.0, true)


static func draw_moita_fruta_regional(
	canvas: CanvasItem,
	pos: Vector2,
	radius: float = 26.0,
	searched: bool = false
) -> void:
	draw_moita(canvas, pos, radius, searched)
	if not searched:
		draw_fruta(canvas, pos + Vector2(-radius * 0.3, -radius * 0.25), radius * 0.18, XiloPalette.RED_ACCENT)
		draw_fruta(canvas, pos + Vector2(radius * 0.28, -radius * 0.3), radius * 0.18, XiloPalette.GOLD_ACCENT)


static func draw_moita_cacto_espinhos(
	canvas: CanvasItem,
	pos: Vector2,
	radius: float = 26.0
) -> void:
	draw_ellipse_filled(canvas, pos + Vector2(0.0, radius * 0.4), radius * 0.85, radius * 0.3, XiloPalette.SHADOW_GROUND)
	var center: Vector2 = pos + Vector2(0.0, -radius * 0.2)
	draw_circle_xilo(canvas, center, radius * 0.65, XiloPalette.BUSH_THORN_GREEN, XiloPalette.BLACK, 2.5)
	for i: int in range(12):
		var a: float = float(i) * (TAU / 12.0)
		var p0: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.65
		var p1: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.95
		canvas.draw_line(p0, p1, XiloPalette.WHITE_HATCH, 2.0, true)
	# Triângulo de alerta
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius * 0.22),
		center + Vector2(-radius * 0.2, radius * 0.16),
		center + Vector2(radius * 0.2, radius * 0.16),
	]), XiloPalette.RED_ACCENT)


static func draw_cacto_mandacaru(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(48.0, 72.0)
) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_ellipse_filled(canvas, pos + Vector2(0.0, h * 0.45), w * 0.4, h * 0.12, XiloPalette.SHADOW_GROUND)
	# Tronco principal
	draw_rounded_rect_xilo(canvas, Rect2(pos.x - w * 0.15, pos.y - h * 0.45, w * 0.3, h * 0.9), 6.0, XiloPalette.BUSH_GREEN, XiloPalette.BLACK, 2.0)
	# Galho esquerdo
	draw_rounded_rect_xilo(canvas, Rect2(pos.x - w * 0.42, pos.y - h * 0.28, w * 0.28, h * 0.12), 4.0, XiloPalette.BUSH_GREEN, XiloPalette.BLACK, 2.0)
	draw_rounded_rect_xilo(canvas, Rect2(pos.x - w * 0.42, pos.y - h * 0.42, w * 0.14, h * 0.24), 4.0, XiloPalette.BUSH_GREEN, XiloPalette.BLACK, 2.0)
	# Galho direito
	draw_rounded_rect_xilo(canvas, Rect2(pos.x + w * 0.14, pos.y - h * 0.18, w * 0.28, h * 0.12), 4.0, XiloPalette.BUSH_GREEN, XiloPalette.BLACK, 2.0)
	draw_rounded_rect_xilo(canvas, Rect2(pos.x + w * 0.28, pos.y - h * 0.36, w * 0.14, h * 0.28), 4.0, XiloPalette.BUSH_GREEN, XiloPalette.BLACK, 2.0)

	# Espinhos brancos
	var py: float = -0.35
	while py <= 0.36:
		canvas.draw_line(pos + Vector2(-w * 0.15, h * py), pos + Vector2(-w * 0.22, h * (py - 0.02)), XiloPalette.WHITE_HATCH, 1.2, true)
		canvas.draw_line(pos + Vector2(w * 0.15, h * py), pos + Vector2(w * 0.22, h * (py - 0.02)), XiloPalette.WHITE_HATCH, 1.2, true)
		py += 0.12

	# Flor no topo
	canvas.draw_circle(pos + Vector2(0.0, -h * 0.46), w * 0.1, XiloPalette.WHITE_HATCH)
	canvas.draw_circle(pos + Vector2(0.0, -h * 0.46), w * 0.04, XiloPalette.GOLD_ACCENT)


static func draw_pedra(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(40.0, 32.0)
) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_ellipse_filled(canvas, pos + Vector2(0.0, h * 0.35), w * 0.48, h * 0.16, XiloPalette.SHADOW_GROUND)
	var rock: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-w * 0.45, h * 0.25),
		pos + Vector2(-w * 0.38, -h * 0.22),
		pos + Vector2(-w * 0.08, -h * 0.42),
		pos + Vector2(w * 0.32, -h * 0.28),
		pos + Vector2(w * 0.46, h * 0.2),
		pos + Vector2(w * 0.1, h * 0.34),
	])
	canvas.draw_colored_polygon(rock, XiloPalette.STONE_GREY)
	var outline: PackedVector2Array = rock.duplicate()
	outline.append(rock[0])
	canvas.draw_polyline(outline, XiloPalette.BLACK, 2.2, true)
	# Faceta escura e hachura de entalhe
	canvas.draw_line(pos + Vector2(-w * 0.08, -h * 0.42), pos + Vector2(0.0, h * 0.05), XiloPalette.STONE_DARK, 2.0, true)
	canvas.draw_line(pos + Vector2(0.0, h * 0.05), pos + Vector2(w * 0.42, h * 0.18), XiloPalette.STONE_DARK, 1.8, true)
	canvas.draw_line(pos + Vector2(-w * 0.25, -h * 0.1), pos + Vector2(-w * 0.12, h * 0.15), XiloPalette.WHITE_HATCH, 1.2, true)
	canvas.draw_line(pos + Vector2(-w * 0.15, -h * 0.15), pos + Vector2(-w * 0.02, h * 0.1), XiloPalette.WHITE_HATCH, 1.2, true)


# ============================================================================
# 5. CENÁRIOS: CASAS, IGREJA, CURRAL, CHÃOS, PRENSA, VARAL, PALCO, PLACA
# ============================================================================

static func draw_casa(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(96.0, 84.0),
	options: Dictionary = {}
) -> void:
	var w: float = size.x
	var h: float = size.y
	var wall_col: Color = XiloPalette.KRAFT_LIGHT
	if options.has("color_tint") and options["color_tint"] is Color and (options["color_tint"] as Color).a > 0.0:
		wall_col = options["color_tint"] as Color

	# Sombra
	canvas.draw_rect(Rect2(pos.x - w * 0.45 + 5.0, pos.y - h * 0.1 + 6.0, w * 0.9, h * 0.55), XiloPalette.SHADOW_GROUND, true)
	# Parede de taipa/alvenaria
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.45, pos.y - h * 0.1, w * 0.9, h * 0.55), wall_col, XiloPalette.BLACK, 2.5)

	# Telhado triangular de barro
	var roof: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-w * 0.54, -h * 0.08),
		pos + Vector2(0.0, -h * 0.52),
		pos + Vector2(w * 0.54, -h * 0.08),
	])
	canvas.draw_colored_polygon(roof, XiloPalette.CERAMICA_BARRO)
	var roof_line: PackedVector2Array = roof.duplicate()
	roof_line.append(roof[0])
	canvas.draw_polyline(roof_line, XiloPalette.BLACK, 2.5, true)

	# Hachuras das telhas
	for ri: int in range(1, 4):
		var frac: float = float(ri) / 4.0
		var y_r: float = lerpf(-h * 0.52, -h * 0.08, frac)
		var x_span: float = w * 0.5 * frac
		canvas.draw_line(pos + Vector2(-x_span, y_r), pos + Vector2(x_span, y_r), XiloPalette.BLACK, 1.2, true)

	# Porta de madeira
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.14, pos.y + h * 0.08, w * 0.24, h * 0.37), XiloPalette.BROWN_WOOD, XiloPalette.BLACK, 2.0)
	canvas.draw_circle(pos + Vector2(w * 0.05, pos.y - pos.y + h * 0.27), 2.0, XiloPalette.GOLD_ACCENT)

	# Janela rústica
	draw_rect_xilo(canvas, Rect2(pos.x + w * 0.16, pos.y + h * 0.06, w * 0.2, h * 0.2), XiloPalette.DARK_WOOD, XiloPalette.BLACK, 1.8)
	canvas.draw_line(pos + Vector2(w * 0.26, h * 0.06), pos + Vector2(w * 0.26, h * 0.26), XiloPalette.KRAFT_PAPER, 1.2, true)
	canvas.draw_line(pos + Vector2(w * 0.16, h * 0.16), pos + Vector2(w * 0.36, h * 0.16), XiloPalette.KRAFT_PAPER, 1.2, true)


static func draw_igreja(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(120.0, 140.0),
	_options: Dictionary = {}
) -> void:
	var w: float = size.x
	var h: float = size.y

	# Sombra
	canvas.draw_rect(Rect2(pos.x - w * 0.45 + 6.0, pos.y - h * 0.1 + 8.0, w * 0.9, h * 0.55), XiloPalette.SHADOW_GROUND, true)

	# Nave Principal
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.45, pos.y - h * 0.1, w * 0.9, h * 0.55), XiloPalette.KRAFT_LIGHT, XiloPalette.BLACK, 2.5)
	# Frontão triangular
	var frontao: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-w * 0.48, -h * 0.1),
		pos + Vector2(0.0, -h * 0.38),
		pos + Vector2(w * 0.48, -h * 0.1),
	])
	canvas.draw_colored_polygon(frontao, XiloPalette.KRAFT_PAPER)
	var fl: PackedVector2Array = frontao.duplicate()
	fl.append(frontao[0])
	canvas.draw_polyline(fl, XiloPalette.BLACK, 2.5, true)

	# Torre Sineira Central
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.16, pos.y - h * 0.45, w * 0.32, h * 0.36), XiloPalette.KRAFT_LIGHT, XiloPalette.BLACK, 2.2)
	var spire: PackedVector2Array = PackedVector2Array([
		pos + Vector2(-w * 0.18, -h * 0.45),
		pos + Vector2(0.0, -h * 0.62),
		pos + Vector2(w * 0.18, -h * 0.45),
	])
	canvas.draw_colored_polygon(spire, XiloPalette.CERAMICA_BARRO)
	var sl: PackedVector2Array = spire.duplicate()
	sl.append(spire[0])
	canvas.draw_polyline(sl, XiloPalette.BLACK, 2.2, true)

	# Cruz no topo
	canvas.draw_line(pos + Vector2(0.0, -h * 0.62), pos + Vector2(0.0, -h * 0.78), XiloPalette.BLACK, 3.0, true)
	canvas.draw_line(pos + Vector2(-w * 0.08, -h * 0.72), pos + Vector2(w * 0.08, -h * 0.72), XiloPalette.BLACK, 3.0, true)

	# Sino dourado na torre
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.08, pos.y - h * 0.36, w * 0.16, h * 0.16), XiloPalette.DARK_WOOD, XiloPalette.BLACK, 1.5)
	canvas.draw_circle(pos + Vector2(0.0, -h * 0.28), w * 0.05, XiloPalette.GOLD_ACCENT)

	# Porta principal em arco
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.12, pos.y + h * 0.1, w * 0.24, h * 0.35), XiloPalette.BROWN_WOOD, XiloPalette.BLACK, 2.0)
	draw_circle_xilo(canvas, pos + Vector2(0.0, h * 0.1), w * 0.12, XiloPalette.BROWN_WOOD, XiloPalette.BLACK, 2.0)
	draw_circle_xilo(canvas, pos + Vector2(0.0, -h * 0.06), w * 0.07, XiloPalette.GOLD_ACCENT, XiloPalette.BLACK, 1.5)


static func draw_curral(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(180.0, 120.0),
	_options: Dictionary = {}
) -> void:
	var w: float = size.x
	var h: float = size.y
	var r: Rect2 = Rect2(pos.x - w * 0.5, pos.y - h * 0.5, w, h)

	# Solo de terra batida interno
	canvas.draw_rect(r, XiloPalette.TERRA_BATIDA_BG, true)

	# Varas horizontais superior e inferior
	for offset_y: float in [0.0, 10.0]:
		canvas.draw_line(Vector2(r.position.x, r.position.y + offset_y), Vector2(r.end.x, r.position.y + offset_y), XiloPalette.BROWN_WOOD, 4.0, true)
		canvas.draw_line(Vector2(r.position.x, r.end.y - offset_y), Vector2(r.end.x, r.end.y - offset_y), XiloPalette.BROWN_WOOD, 4.0, true)

	# Varas verticais esquerda e direita
	for offset_x: float in [0.0, 8.0]:
		canvas.draw_line(Vector2(r.position.x + offset_x, r.position.y), Vector2(r.position.x + offset_x, r.end.y), XiloPalette.BROWN_WOOD, 4.0, true)
		canvas.draw_line(Vector2(r.end.x - offset_x, r.position.y), Vector2(r.end.x - offset_x, r.end.y), XiloPalette.BROWN_WOOD, 4.0, true)

	# Estacas fincadas no perímetro
	var px: float = r.position.x
	while px <= r.end.x + 1.0:
		draw_rect_xilo(canvas, Rect2(px - 4.0, r.position.y - 6.0, 8.0, 18.0), XiloPalette.DARK_WOOD, XiloPalette.BLACK, 1.5)
		draw_rect_xilo(canvas, Rect2(px - 4.0, r.end.y - 12.0, 8.0, 18.0), XiloPalette.DARK_WOOD, XiloPalette.BLACK, 1.5)
		px += 36.0

	var py: float = r.position.y + 30.0
	while py < r.end.y - 10.0:
		draw_rect_xilo(canvas, Rect2(r.position.x - 4.0, py - 6.0, 8.0, 14.0), XiloPalette.DARK_WOOD, XiloPalette.BLACK, 1.5)
		draw_rect_xilo(canvas, Rect2(r.end.x - 4.0, py - 6.0, 8.0, 14.0), XiloPalette.DARK_WOOD, XiloPalette.BLACK, 1.5)
		py += 30.0


static func draw_chao_terra_batida(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, XiloPalette.TERRA_BATIDA_BG, true)
	var gx: float = rect.position.x + 40.0
	while gx < rect.end.x:
		var gy: float = rect.position.y + 40.0
		while gy < rect.end.y:
			canvas.draw_line(Vector2(gx, gy), Vector2(gx + 25.0, gy + 15.0), XiloPalette.TERRA_BATIDA_CRACK, 1.5, true)
			canvas.draw_line(Vector2(gx + 25.0, gy + 15.0), Vector2(gx + 10.0, gy + 35.0), XiloPalette.TERRA_BATIDA_CRACK, 1.5, true)
			canvas.draw_line(Vector2(gx + 25.0, gy + 15.0), Vector2(gx + 40.0, gy + 10.0), XiloPalette.TERRA_BATIDA_CRACK, 1.5, true)
			gy += 80.0
		gx += 80.0

	var px: float = rect.position.x + 30.0
	while px < rect.end.x:
		var py: float = rect.position.y + 50.0
		while py < rect.end.y:
			draw_ellipse_filled(canvas, Vector2(px, py), 6.0, 4.0, XiloPalette.TERRA_BATIDA_STONE, 0.4, 12)
			py += 100.0
		px += 100.0


static func draw_chao_lajotas(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, XiloPalette.LAJOTA_BG, true)
	var tile_size: float = 60.0
	var rows: int = int(ceilf(rect.size.y / tile_size))
	var cols: int = int(ceilf(rect.size.x / tile_size)) + 1
	for row: int in range(rows):
		var shift: float = float(row % 2) * (tile_size * 0.5)
		for col: int in range(-1, cols):
			var tx: float = rect.position.x + float(col) * tile_size + shift
			var ty: float = rect.position.y + float(row) * tile_size
			canvas.draw_rect(Rect2(tx + 4.0, ty + 4.0, tile_size - 8.0, tile_size - 8.0), XiloPalette.STONE_DARK, true)
			canvas.draw_rect(Rect2(tx, ty, tile_size, tile_size), XiloPalette.LAJOTA_BORDER, false, 2.0)


static func draw_chao_estudio_madeira(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, XiloPalette.MADEIRA_PISO, true)
	var plank_h: float = 40.0
	var py: float = rect.position.y
	while py < rect.end.y:
		canvas.draw_line(Vector2(rect.position.x, py), Vector2(rect.end.x, py), XiloPalette.TERRA_BATIDA_CRACK, 2.0, true)
		var px: float = rect.position.x + 60.0
		while px < rect.end.x:
			draw_ellipse_outline(canvas, Vector2(px, py + plank_h * 0.5), 14.0, 5.0, XiloPalette.MADEIRA_VEIO, 1.0, 0.0, 14)
			px += 180.0
		py += plank_h


static func draw_prensa(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(120.0, 70.0),
	is_ready: bool = true
) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.5, pos.y - h * 0.2, w, h * 0.7), XiloPalette.BROWN_WOOD, XiloPalette.BLACK, 2.5)
	var bed_col: Color = XiloPalette.VERDE_PRENSA if is_ready else XiloPalette.STONE_DARK
	var bed_stroke: Color = XiloPalette.VERDE_PRENSA_BORDA if is_ready else XiloPalette.BLACK
	draw_rect_xilo(canvas, Rect2(pos.x - w * 0.4, pos.y - h * 0.1, w * 0.8, h * 0.35), bed_col, bed_stroke, 2.0)
	canvas.draw_rect(Rect2(pos.x - w * 0.08, pos.y - h * 0.5, w * 0.16, h * 0.4), XiloPalette.BLACK, true)
	canvas.draw_line(pos + Vector2(-w * 0.35, -h * 0.45), pos + Vector2(w * 0.35, -h * 0.45), XiloPalette.GOLD_ACCENT, 4.0, true)
	canvas.draw_circle(pos + Vector2(-w * 0.35, -h * 0.45), 6.0, XiloPalette.GOLD_ACCENT)
	canvas.draw_circle(pos + Vector2(w * 0.35, -h * 0.45), 6.0, XiloPalette.GOLD_ACCENT)


static func draw_varal(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(360.0, 80.0),
	completed: Dictionary = {}
) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_quadratic_curve(canvas, pos + Vector2(-w * 0.5, 0.0), pos + Vector2(0.0, h * 0.2), pos + Vector2(w * 0.5, 0.0), XiloPalette.GOLD_ACCENT, 3.0)

	var keys: Array[String] = ["carimbo", "folha", "pena", "tinta"]
	var colors: Array[Color] = [Color("#f59e0b"), XiloPalette.VERDE_PRENSA, Color("#a855f7"), Color("#3b82f6")]
	var spacing: float = w * 0.22

	for idx: int in range(4):
		var fx: float = pos.x - w * 0.33 + float(idx) * spacing
		var fy: float = pos.y + h * 0.08 + sin(float(idx) * 0.8) * 4.0
		var ok: bool = bool(completed.get(keys[idx], false))

		# Pregador
		draw_rect_xilo(canvas, Rect2(fx - 3.0, fy - 12.0, 6.0, 14.0), Color("#78350f"), XiloPalette.BLACK, 1.0)
		# Folheto
		var page_col: Color = XiloPalette.KRAFT_PAPER if ok else Color("#262626")
		var border_col: Color = colors[idx] if ok else Color("#525252")
		draw_rect_xilo(canvas, Rect2(fx - 18.0, fy, 36.0, 48.0), page_col, border_col, 1.5)
		if ok:
			canvas.draw_line(Vector2(fx - 12.0, fy + 34.0), Vector2(fx + 12.0, fy + 34.0), Color("#78350f"), 1.0, true)
			canvas.draw_line(Vector2(fx - 12.0, fy + 40.0), Vector2(fx + 12.0, fy + 40.0), Color("#78350f"), 1.0, true)


static func draw_palco_violeiros(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(260.0, 90.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var w: float = size.x
	var h: float = size.y
	var r: Rect2 = Rect2(pos.x - w * 0.5, pos.y - h * 0.5, w, h)

	canvas.draw_rect(Rect2(r.position + Vector2(6.0, 8.0), r.size), Color(0.0, 0.0, 0.0, 0.45), true)
	draw_rect_xilo(canvas, r, Color("#2c1a0e"), XiloPalette.BLACK, 3.0)

	var px: float = r.position.x + 20.0
	while px < r.end.x:
		canvas.draw_line(Vector2(px, r.position.y + 2.0), Vector2(px, r.end.y - 2.0), Color("#180e07"), 1.5, true)
		px += 24.0

	canvas.draw_rect(Rect2(r.position + Vector2(5.0, 5.0), r.size - Vector2(10.0, 10.0)), XiloPalette.CERAMICA_BARRO, false, 1.5)
	var flame_pulse: float = sin(t * 8.0) * 1.5
	canvas.draw_circle(Vector2(r.position.x + 14.0, r.position.y + 12.0), 4.0 + flame_pulse, Color("#f59e0b"))
	canvas.draw_circle(Vector2(r.end.x - 14.0, r.position.y + 12.0), 4.0 + flame_pulse, Color("#f59e0b"))


static func draw_placa_aviso(
	canvas: CanvasItem,
	pos: Vector2,
	size: Vector2 = Vector2(34.0, 34.0),
	options: Dictionary = {}
) -> void:
	var t: float = float(options.get("time", 0.0))
	var sway: float = sin(t * 2.0) * 0.02
	var w: float = size.x
	var h: float = size.y

	draw_ellipse_filled(canvas, pos + Vector2(0.0, h * 0.45), w * 0.45, 5.0, XiloPalette.SHADOW_GROUND)
	draw_rect_xilo(canvas, Rect2(pos.x - 3.5, pos.y - h * 0.1, 7.0, h * 0.55), XiloPalette.MADEIRA_RUSTICA, XiloPalette.BLACK, 1.8)
	canvas.draw_line(pos + Vector2(-0.5, 0.0), pos + Vector2(-0.5, h * 0.38), XiloPalette.BLACK, 1.2, true)

	var pw: float = w
	var ph: float = h * 0.58
	var py: float = pos.y - h * 0.22
	var board_rect: Rect2 = Rect2(pos.x - pw * 0.5, py - ph * 0.5, pw, ph)
	draw_rect_xilo(canvas, board_rect, XiloPalette.MADEIRA_PLACA, XiloPalette.BLACK, 2.2)
	canvas.draw_rect(Rect2(board_rect.position + Vector2(2.5, 2.5), board_rect.size - Vector2(5.0, 5.0)), XiloPalette.TEXTO_DOURADO, false, 1.0)
	canvas.draw_circle(Vector2(pos.x - pw * 0.5 + 5.0, py), 1.8, XiloPalette.BLACK)
	canvas.draw_circle(Vector2(pos.x + pw * 0.5 - 5.0, py), 1.8, XiloPalette.BLACK)

	var tri: PackedVector2Array = PackedVector2Array([
		Vector2(pos.x, py - ph * 0.32).rotated(0.0),
		Vector2(pos.x - 7.0, py + ph * 0.22),
		Vector2(pos.x + 7.0, py + ph * 0.22),
	])
	canvas.draw_colored_polygon(tri, XiloPalette.ALERTA_AMARELO)
	var tri_line: PackedVector2Array = tri.duplicate()
	tri_line.append(tri[0])
	canvas.draw_polyline(tri_line, XiloPalette.BLACK, 1.0, true)
	# Exclamação geométrica
	canvas.draw_line(Vector2(pos.x, py - ph * 0.14), Vector2(pos.x, py + ph * 0.06), XiloPalette.BLACK, 2.0, true)
	canvas.draw_circle(Vector2(pos.x + sway * 10.0, py + ph * 0.14), 1.2, XiloPalette.BLACK)


# ============================================================================
# 6. ANIMAIS DA VILA (FASE 3)
# ============================================================================

static func draw_galinha(canvas: CanvasItem, pos: Vector2, size: Vector2 = Vector2(28.0, 28.0)) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_ellipse_xilo(canvas, pos + Vector2(0.0, 2.0), w * 0.35, h * 0.28, XiloPalette.BRANCO_GALINHA, XiloPalette.BLACK, 1.5)
	canvas.draw_circle(pos + Vector2(w * 0.22, -h * 0.25), 4.0, Color("#ef4444"))
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(w * 0.35, -h * 0.15),
		pos + Vector2(w * 0.48, -h * 0.1),
		pos + Vector2(w * 0.35, -h * 0.05),
	]), Color("#f59e0b"))
	canvas.draw_rect(Rect2(pos.x + w * 0.25, pos.y - h * 0.18, 2.0, 2.0), XiloPalette.BLACK, true)
	canvas.draw_line(pos + Vector2(-2.0, h * 0.28), pos + Vector2(-2.0, h * 0.44), XiloPalette.GOLD_ACCENT, 1.5, true)
	canvas.draw_line(pos + Vector2(4.0, h * 0.28), pos + Vector2(4.0, h * 0.44), XiloPalette.GOLD_ACCENT, 1.5, true)


static func draw_porco(canvas: CanvasItem, pos: Vector2, size: Vector2 = Vector2(34.0, 26.0)) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_ellipse_xilo(canvas, pos, w * 0.42, h * 0.35, XiloPalette.ROSA_PORCO, XiloPalette.BLACK, 1.5)
	draw_ellipse_xilo(canvas, pos + Vector2(w * 0.36, 0.0), 4.0, 6.0, XiloPalette.ROSA_FOCINHO, XiloPalette.BLACK, 1.0)
	canvas.draw_rect(Rect2(pos.x + w * 0.36, pos.y - 2.0, 1.5, 1.5), XiloPalette.BLACK, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.36, pos.y + 2.0, 1.5, 1.5), XiloPalette.BLACK, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.18, pos.y - h * 0.18, 2.0, 2.0), XiloPalette.BLACK, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(w * 0.08, -h * 0.25),
		pos + Vector2(w * 0.18, -h * 0.45),
		pos + Vector2(w * 0.25, -h * 0.2),
	]), XiloPalette.ROSA_ESCURO)
	canvas.draw_arc(pos + Vector2(-w * 0.42, -4.0), 4.0, 0.0, PI, 10, XiloPalette.ROSA_ESCURO, 1.5, true)
	canvas.draw_rect(Rect2(pos.x - w * 0.28, pos.y + h * 0.25, 4.0, 6.0), XiloPalette.ROSA_ESCURO, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.18, pos.y + h * 0.25, 4.0, 6.0), XiloPalette.ROSA_ESCURO, true)


static func draw_jumento(canvas: CanvasItem, pos: Vector2, size: Vector2 = Vector2(36.0, 30.0)) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_ellipse_xilo(canvas, pos + Vector2(0.0, 2.0), w * 0.4, h * 0.3, XiloPalette.CINZA_JUMENTO, XiloPalette.BLACK, 1.5)
	draw_ellipse_xilo(canvas, pos + Vector2(w * 0.3, -h * 0.2), w * 0.18, h * 0.22, XiloPalette.CINZA_JUMENTO, XiloPalette.BLACK, 1.5, 0.4)
	draw_ellipse_filled(canvas, pos + Vector2(w * 0.44, -h * 0.12), 5.0, 5.0, Color("#e7e5e4"))
	draw_ellipse_xilo(canvas, pos + Vector2(w * 0.24, -h * 0.48), 3.0, 9.0, XiloPalette.CINZA_JUMENTO_ESCURO, XiloPalette.BLACK, 1.5, -0.2)
	draw_ellipse_xilo(canvas, pos + Vector2(w * 0.32, -h * 0.46), 3.0, 9.0, XiloPalette.CINZA_JUMENTO_ESCURO, XiloPalette.BLACK, 1.5, 0.2)
	canvas.draw_rect(Rect2(pos.x + w * 0.32, pos.y - h * 0.24, 2.0, 2.0), XiloPalette.BLACK, true)
	for px_off: float in [-w * 0.25, -w * 0.12, w * 0.15, w * 0.28]:
		canvas.draw_rect(Rect2(pos.x + px_off, pos.y + h * 0.25, 4.0, 8.0), XiloPalette.CINZA_PATAS, true)


static func draw_cachorro(canvas: CanvasItem, pos: Vector2, size: Vector2 = Vector2(32.0, 26.0)) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_ellipse_xilo(canvas, pos + Vector2(0.0, 2.0), w * 0.38, h * 0.28, XiloPalette.CERAMICA_BARRO, XiloPalette.BLACK, 1.5)
	draw_circle_xilo(canvas, pos + Vector2(w * 0.28, -h * 0.15), 7.0, XiloPalette.CERAMICA_BARRO, XiloPalette.BLACK, 1.5)
	draw_ellipse_filled(canvas, pos + Vector2(w * 0.22, -h * 0.18), 3.0, 6.0, Color("#78350f"), 0.4)
	canvas.draw_rect(Rect2(pos.x + w * 0.34, pos.y - h * 0.14, 5.0, 4.0), XiloPalette.GOLD_ACCENT, true)
	canvas.draw_rect(Rect2(pos.x + w * 0.38, pos.y - h * 0.16, 2.0, 2.0), XiloPalette.BLACK, true)
	draw_quadratic_curve(canvas, pos + Vector2(-w * 0.35, 0.0), pos + Vector2(-w * 0.45, -h * 0.3), pos + Vector2(-w * 0.3, -h * 0.4), XiloPalette.CERAMICA_BARRO, 2.0)
	canvas.draw_rect(Rect2(pos.x - w * 0.22, pos.y + h * 0.25, 3.0, 6.0), Color("#78350f"), true)
	canvas.draw_rect(Rect2(pos.x + w * 0.18, pos.y + h * 0.25, 3.0, 6.0), Color("#78350f"), true)
