class_name VictoryScene
extends Node2D

const StudioSceneScript := preload("res://src/levels/StudioScene.gd")
const VIEWPORT_WIDTH: float = 960.0
const VIEWPORT_HEIGHT: float = 580.0

var _is_naming_active: bool = true
var _is_printed: bool = false
var _print_progress: float = 0.0
var _anim_timer: float = 0.0
var _sparkle_timer: float = 0.0
var _is_restarting: bool = false

@onready var _naming_modal: CanvasLayer = $NamingModal
@onready var _name_input: LineEdit = $NamingModal/Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/NameInput
@onready var _confirm_button: Button = $NamingModal/Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/ConfirmButton
@onready var _restart_button: Button = $ActionLayer/RestartButton


func _ready() -> void:
	GameManager.current_scene_id = "VICTORY"
	GameManager.register_scene_path("STUDIO", "res://src/levels/StudioScene.tscn")
	GameManager.register_scene_path("VICTORY", "res://src/levels/VictoryScene.tscn")

	if GameManager.player_name.strip_edges().is_empty():
		GameManager.set_player_name("Coisinha")

	SoundManager.play_music("VICTORY")

	_is_naming_active = true
	_is_printed = false
	_print_progress = 0.0
	_anim_timer = 0.0
	_sparkle_timer = 0.0
	_is_restarting = false

	if _restart_button != null:
		_restart_button.visible = false
		_restart_button.pressed.connect(_on_restart_pressed)

	if _confirm_button != null:
		_confirm_button.pressed.connect(_confirm_hero_name)

	if _name_input != null:
		_name_input.text = GameManager.player_name
		_name_input.text_submitted.connect(_on_name_submitted)

	if _naming_modal != null:
		_naming_modal.visible = true

	if _name_input != null:
		_name_input.grab_focus()
		_name_input.caret_column = _name_input.text.length()

	queue_redraw()


func _process(delta: float) -> void:
	_anim_timer += delta

	if _is_naming_active:
		queue_redraw()
		return

	if not _is_printed:
		_print_progress += delta * 0.9
		if _print_progress >= 1.0:
			_print_progress = 1.0
			_is_printed = true
			SoundManager.play_prensa_impacto()
			SoundManager.play_victory_jingle()
			JuiceManager.add_trauma(0.6)
			JuiceManager.emit_particles("sparkle", Vector2(480.0, 240.0), self, {
				"count": 35,
				"speed": 80.0,
			})
			if _restart_button != null:
				_restart_button.visible = true
				_restart_button.grab_focus()
	else:
		_sparkle_timer += delta
		if _sparkle_timer >= 0.4:
			_sparkle_timer = 0.0
			var rx: float = 200.0 + randf() * 560.0
			var ry: float = 100.0 + randf() * 340.0
			JuiceManager.emit_particles("sparkle", Vector2(rx, ry), self, {
				"count": 2,
				"speed": 25.0,
			})

	queue_redraw()


func _draw() -> void:
	# 1. Fundo Papel Kraft / Folheto de Cordel Envelhecido (960x580)
	draw_rect(Rect2(0.0, 0.0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT), XiloPalette.KRAFT_PAPER)

	# Textura sutil de papel artesanal
	var paper_line_col: Color = Color(1.0, 1.0, 1.0, 0.2)
	var py: float = 10.0
	while py < 570.0:
		draw_rect(Rect2(20.0, py, 920.0, 1.0), paper_line_col)
		py += 30.0

	# 2. Moldura Ornamental Classica de Xilogravura
	XiloDraw.draw_moldura_cordel(self, Rect2(24.0, 16.0, 912.0, 548.0), 5.0)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	# 3. Cabecalho do Folheto de Cordel
	draw_string(
		font,
		Vector2(0.0, 52.0),
		"FOLHETO DE CORDEL DO VELHO SERTÃO",
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEWPORT_WIDTH,
		20,
		XiloPalette.BLACK
	)

	var divider: String = "═══════════════════════════════════════════════════════════════════"
	draw_string(
		font,
		Vector2(0.0, 70.0),
		divider,
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEWPORT_WIDTH,
		14,
		XiloPalette.BLACK
	)

	# 4. Titulo Personalizado com Nickname do Heroi
	var raw_name: String = GameManager.player_name.strip_edges()
	var display_name: String = (raw_name if not raw_name.is_empty() else "Coisinha").to_upper()
	draw_string(
		font,
		Vector2(0.0, 102.0),
		"\"O CORDEL DE %s:" % display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEWPORT_WIDTH,
		24,
		XiloPalette.BLACK
	)
	draw_string(
		font,
		Vector2(0.0, 130.0),
		"O HERÓI DO SERTÃO\"",
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEWPORT_WIDTH,
		24,
		XiloPalette.BLACK
	)

	draw_string(
		font,
		Vector2(0.0, 148.0),
		divider,
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEWPORT_WIDTH,
		14,
		XiloPalette.BLACK
	)

	# 5. Gravura Central de Xilogravura com Moldura de Entalhe
	var gx: float = 360.0
	var gy: float = 160.0
	var gw: float = 240.0
	var gh: float = 180.0

	draw_rect(Rect2(gx, gy, gw, gh), XiloPalette.BLACK)
	XiloDraw.draw_rect_xilo(
		self,
		Rect2(gx + 6.0, gy + 6.0, gw - 12.0, gh - 12.0),
		XiloPalette.KRAFT_LIGHT,
		XiloPalette.BLACK,
		2.0
	)

	# Elementos Sertanejos Laterais (Cactos & Estrela de Xilo)
	XiloDraw.draw_cacto_mandacaru(self, Vector2(400.0, 272.0), Vector2(34.0, 52.0))
	XiloDraw.draw_cacto_mandacaru(self, Vector2(560.0, 272.0), Vector2(34.0, 52.0))
	XiloDraw.draw_star(self, Vector2(480.0, 186.0), 12.0, 5.5, XiloPalette.GOLD_ACCENT, 5)

	# Heroi Coisinha Ilustrado no Centro da Capa
	XiloDraw.draw_coisinha(self, Vector2(480.0, 250.0), Vector2(50.0, 64.0), {
		"time": _anim_timer,
		"is_moving": false,
		"facing": "right",
	})

	# 6. Os 4 Selos Misticos Conquistados (Arte em Xilo)
	var items: Array[Dictionary] = [
		{"key": "carimbo", "name": "Carimbo", "desc": "Chupa-Cabra", "color": XiloPalette.GOLD_ACCENT},
		{"key": "folha", "name": "Página", "desc": "Cumade Fulô", "color": XiloPalette.GREEN_ACCENT},
		{"key": "pena", "name": "Pena", "desc": "Rasga-Mortalha", "color": XiloPalette.PURPLE_ACCENT},
		{"key": "tinta", "name": "Tinta", "desc": "Mané Monteiro", "color": XiloPalette.CYAN_ACCENT},
	]

	for i: int in range(items.size()):
		var it: Dictionary = items[i]
		var ix: float = 140.0 + float(i) * 225.0
		var iy: float = 385.0
		var accent: Color = it["color"] as Color

		draw_rect(Rect2(ix - 55.0, iy - 24.0, 130.0, 52.0), XiloPalette.BLACK)
		XiloDraw.draw_rect_xilo(
			self,
			Rect2(ix - 52.0, iy - 21.0, 124.0, 46.0),
			XiloPalette.KRAFT_LIGHT,
			accent,
			1.5
		)

		var icon_pos: Vector2 = Vector2(ix - 30.0, iy + 2.0)
		match str(it["key"]):
			"carimbo":
				XiloDraw.draw_item_carimbo(self, icon_pos, 22.0)
			"folha":
				XiloDraw.draw_item_folha(self, icon_pos, 22.0)
			"pena":
				XiloDraw.draw_item_pena(self, icon_pos, 22.0)
			"tinta":
				XiloDraw.draw_item_tinta(self, icon_pos, 22.0)

		draw_string(
			font,
			Vector2(ix - 10.0, iy - 2.0),
			str(it["name"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			80.0,
			11,
			XiloPalette.BLACK
		)
		draw_string(
			font,
			Vector2(ix - 10.0, iy + 12.0),
			str(it["desc"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			82.0,
			9,
			Color("#525252")
		)

	# 7. Feedback de Prensagem / Conclusao
	if _is_printed:
		var pulse: float = sin(_anim_timer * 5.0) * 2.0
		draw_string(
			font,
			Vector2(0.0, 456.0 + pulse),
			"✨ A GRANDE PORTA SE ABRIU! VOCÊ CONQUISTOU A CHAVE DO SERTÃO! ✨",
			HORIZONTAL_ALIGNMENT_CENTER,
			VIEWPORT_WIDTH,
			13,
			Color("#15803d")
		)
		draw_string(
			font,
			Vector2(0.0, 478.0),
			"O seu cordel agora é eterno nas feiras e cantorias da Paraíba!",
			HORIZONTAL_ALIGNMENT_CENTER,
			VIEWPORT_WIDTH,
			12,
			XiloPalette.BLACK
		)
	elif not _is_naming_active:
		var pct: int = int(round(_print_progress * 100.0))
		draw_string(
			font,
			Vector2(0.0, 470.0),
			"Prensando matriz de xilogravura com os 4 elementos... %d%%" % pct,
			HORIZONTAL_ALIGNMENT_CENTER,
			VIEWPORT_WIDTH,
			13,
			Color("#b45309")
		)


func _on_name_submitted(_text: String) -> void:
	_confirm_hero_name()


func _confirm_hero_name() -> void:
	if not _is_naming_active:
		return
	var typed: String = _name_input.text.strip_edges() if _name_input != null else ""
	var final_name: String = typed if not typed.is_empty() else "Coisinha"
	GameManager.set_player_name(final_name)
	_is_naming_active = false
	if _naming_modal != null:
		_naming_modal.visible = false
	SoundManager.play_cordel_folhear()
	queue_redraw()


func _on_restart_pressed() -> void:
	if _is_restarting:
		return
	_is_restarting = true
	SoundManager.play_ui_click()
	StudioSceneScript.reset_intro_flag()
	GameManager.reset_full_game()
	GameManager.call_deferred("switch_scene", "STUDIO")
