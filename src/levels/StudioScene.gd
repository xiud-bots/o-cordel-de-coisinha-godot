class_name StudioScene
extends Node2D

const VIEWPORT_WIDTH: float = 960.0
const VIEWPORT_HEIGHT: float = 580.0
const DEFAULT_INFO_MESSAGE: String = "Pise em um cordel no chão para entrar no conto!"

static var has_shown_game_intro: bool = false

var _is_opening_active: bool = false
var _is_naming_active: bool = false
var _opening_cooldown: float = 0.0
var _entry_grace_timer: float = 0.35
var _anim_time: float = 0.0
var _info_message: String = DEFAULT_INFO_MESSAGE
var _is_transitioning: bool = false

var _triggers: Array[Dictionary] = [
	{
		"scene_id": "STAGE_1_CHUPACABRA",
		"title": "Conto 1: O Ataque do Chupa-Cabra",
		"pos": Vector2(180.0, 310.0),
		"size": Vector2(140.0, 60.0),
		"item_key": "carimbo",
	},
	{
		"scene_id": "STAGE_2_FULOZINHA",
		"title": "Conto 2: Fazenda da Cumade Fulozinha",
		"pos": Vector2(370.0, 310.0),
		"size": Vector2(140.0, 60.0),
		"item_key": "folha",
	},
	{
		"scene_id": "STAGE_3_RASGAMORTALHA",
		"title": "Conto 3: A Pena da Rasga-Mortalha",
		"pos": Vector2(560.0, 310.0),
		"size": Vector2(140.0, 60.0),
		"item_key": "pena",
	},
	{
		"scene_id": "STAGE_4_BOTIJA",
		"title": "Conto 4: A Botija de Mané Monteiro",
		"pos": Vector2(750.0, 310.0),
		"size": Vector2(140.0, 60.0),
		"item_key": "tinta",
	},
]

@onready var _player: Coisinha = $Coisinha
@onready var _info_label: Label = $HUDLayer/InfoLabel
@onready var _door_area: Area2D = $DoorArea
@onready var _prensa_interactable: InteractableComponent = $PrensaInteractable
@onready var _cordel_1: Area2D = $CordelTriggers/Cordel1
@onready var _cordel_2: Area2D = $CordelTriggers/Cordel2
@onready var _cordel_3: Area2D = $CordelTriggers/Cordel3
@onready var _cordel_4: Area2D = $CordelTriggers/Cordel4

@onready var _opening_overlay: CanvasLayer = $OpeningOverlay
@onready var _opening_button: Button = $OpeningOverlay/Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/ContinueButton

@onready var _naming_modal: CanvasLayer = $NamingModal
@onready var _name_input: LineEdit = $NamingModal/Backdrop/CenterContainer/ModalPanel/MarginContainer/VBoxContainer/NameInput
@onready var _confirm_name_button: Button = $NamingModal/Backdrop/CenterContainer/ModalPanel/MarginContainer/VBoxContainer/ConfirmButton


static func reset_intro_flag() -> void:
	has_shown_game_intro = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.current_scene_id = "STUDIO"
	GameManager.register_scene_path("STAGE_1_CHUPACABRA", "res://src/levels/Stage1_ChupaCabra.tscn")
	GameManager.register_scene_path("STAGE_2_FULOZINHA", "res://src/levels/Stage2_Fulozinha.tscn")
	GameManager.register_scene_path("STAGE_3_RASGAMORTALHA", "res://src/levels/Stage3_RasgaMortalha.tscn")
	GameManager.register_scene_path("STAGE_4_BOTIJA", "res://src/levels/Stage4_Botija.tscn")
	SoundManager.play_music("STUDIO")

	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		_player.global_position = Vector2(480.0, 430.0)
		_player.facing = "right"

	_connect_signals()
	_refresh_info_label()

	if not has_shown_game_intro:
		has_shown_game_intro = true
		_open_opening_leaflet()
	else:
		_opening_overlay.visible = false

	_naming_modal.visible = false
	queue_redraw()


func _connect_signals() -> void:
	var cordel_areas: Array[Area2D] = [_cordel_1, _cordel_2, _cordel_3, _cordel_4]
	for idx: int in range(cordel_areas.size()):
		var area: Area2D = cordel_areas[idx]
		if area != null:
			area.body_entered.connect(_on_cordel_body_entered.bind(idx))

	if _door_area != null:
		_door_area.body_entered.connect(_on_door_body_entered)
		_door_area.body_exited.connect(_on_door_body_exited)

	if _prensa_interactable != null:
		_prensa_interactable.interacted.connect(_on_prensa_interacted)
		_prensa_interactable.focus_gained.connect(_on_prensa_focus_gained)
		_prensa_interactable.focus_lost.connect(_on_prensa_focus_lost)

	if _opening_button != null:
		_opening_button.pressed.connect(_close_opening_leaflet)

	if _confirm_name_button != null:
		_confirm_name_button.pressed.connect(_confirm_hero_name)

	if _name_input != null:
		_name_input.text_submitted.connect(_on_name_submitted)

	EventBus.item_unlocked.connect(_on_inventory_changed)


func _process(delta: float) -> void:
	_anim_time += delta
	if _opening_cooldown > 0.0:
		_opening_cooldown = maxf(0.0, _opening_cooldown - delta)
	if _entry_grace_timer > 0.0 and not _is_opening_active and not _is_naming_active:
		_entry_grace_timer = maxf(0.0, _entry_grace_timer - delta)

	if _player != null and not _is_opening_active and not _is_naming_active:
		_player.global_position = Vector2(
			clampf(_player.global_position.x, 48.0, VIEWPORT_WIDTH - 48.0),
			clampf(_player.global_position.y, 54.0, VIEWPORT_HEIGHT - 54.0)
		)


func _input(event: InputEvent) -> void:
	if _is_opening_active:
		if (event.is_action_released("interact") or event.is_action_pressed("shout")) and _opening_cooldown <= 0.0:
			get_viewport().set_input_as_handled()
			_close_opening_leaflet()
		elif event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
		return

	if _is_naming_active:
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_close_naming_modal()
		return


func _draw() -> void:
	# 1. Piso Rustico de Tabuas de Madeira do Estudio (960x580)
	XiloDraw.draw_chao_estudio_madeira(self, Rect2(0.0, 0.0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT))

	# 2. Moldura de Xilogravura do Estudio
	XiloDraw.draw_moldura_cordel(self, Rect2(10.0, 10.0, VIEWPORT_WIDTH - 20.0, VIEWPORT_HEIGHT - 20.0), 4.0)

	var font: Font = ThemeDB.fallback_font
	var all_completed: bool = _are_all_items_collected()

	# 3. Render dos 4 Cordeis no chao
	for idx: int in range(_triggers.size()):
		var t: Dictionary = _triggers[idx]
		var pos: Vector2 = t["pos"] as Vector2
		var size: Vector2 = t["size"] as Vector2
		var item_key: String = str(t["item_key"])
		var is_completed: bool = GameManager.has_item(item_key)

		var rect: Rect2 = Rect2(pos - size * 0.5, size)
		var fill_col: Color = Color("#166534") if is_completed else Color("#78350f")
		var border_col: Color = Color("#4ade80") if is_completed else Color("#f59e0b")
		XiloDraw.draw_rect_xilo(self, rect, fill_col, border_col, 2.0)

		if font != null:
			draw_string(
				font,
				Vector2(pos.x - size.x * 0.5, pos.y - 4.0),
				"[CORDEL %d]" % (idx + 1),
				HORIZONTAL_ALIGNMENT_CENTER,
				size.x,
				12,
				Color.WHITE
			)
			draw_string(
				font,
				Vector2(pos.x - size.x * 0.5, pos.y + 16.0),
				"✓ Concluído" if is_completed else "Pise para entrar",
				HORIZONTAL_ALIGNMENT_CENTER,
				size.x,
				11,
				Color("#bbf7d0") if is_completed else Color("#fde68a")
			)

	# 4. Porta Ancestral (480, 85)
	var door_pos: Vector2 = Vector2(480.0, 85.0)
	var door_size: Vector2 = Vector2(200.0, 40.0)
	var door_rect: Rect2 = Rect2(door_pos - door_size * 0.5, door_size)
	var door_fill: Color = Color("#10b981") if all_completed else Color("#8b4513")
	var door_border: Color = Color("#34d399") if all_completed else XiloPalette.BLACK
	XiloDraw.draw_rect_xilo(self, door_rect, door_fill, door_border, 2.5)
	if font != null:
		draw_string(
			font,
			Vector2(door_rect.position.x, door_pos.y + 5.0),
			"PORTA DO HERÓI" if all_completed else "SÓ HERÓIS TÊM A CHAVE",
			HORIZONTAL_ALIGNMENT_CENTER,
			door_size.x,
			11,
			Color.WHITE if all_completed else Color("#fef08a")
		)

	# 5. Prensa do Destino (180, 130)
	XiloDraw.draw_prensa(self, Vector2(180.0, 130.0), Vector2(120.0, 90.0), all_completed)
	if font != null:
		draw_string(
			font,
			Vector2(100.0, 194.0),
			"PRENSA DO DESTINO",
			HORIZONTAL_ALIGNMENT_CENTER,
			160.0,
			11,
			Color("#34d399") if all_completed else Color("#cbd5e1")
		)

	# 6. Varal de Cordeis com Pregadores (770, 130)
	XiloDraw.draw_varal(self, Vector2(770.0, 130.0), Vector2(240.0, 60.0), GameManager.inventory)

	# 7. Painel de Itens Misticos Conquistados abaixo do Varal
	_draw_mystical_items_rack(font)


func _draw_mystical_items_rack(font: Font) -> void:
	var item_defs: Array[Dictionary] = [
		{"key": "carimbo", "label": "Carimbo"},
		{"key": "folha", "label": "Folha"},
		{"key": "pena", "label": "Pena"},
		{"key": "tinta", "label": "Tinta"},
	]
	var start_x: float = 680.0
	var spacing: float = 60.0
	var base_y: float = 222.0

	for idx: int in range(item_defs.size()):
		var item: Dictionary = item_defs[idx]
		var key: String = str(item["key"])
		var label: String = str(item["label"])
		var pos: Vector2 = Vector2(start_x + float(idx) * spacing, base_y)
		var unlocked: bool = GameManager.has_item(key)

		if unlocked:
			draw_circle(pos, 18.0, Color(0.85, 0.47, 0.02, 0.25))
			draw_arc(pos, 18.0, 0.0, TAU, 24, XiloPalette.GOLD_ACCENT, 2.0, true)
			match key:
				"carimbo":
					XiloDraw.draw_item_carimbo(self, pos, 24.0)
				"folha":
					XiloDraw.draw_item_folha(self, pos, 24.0)
				"pena":
					XiloDraw.draw_item_pena(self, pos, 24.0)
				"tinta":
					XiloDraw.draw_item_tinta(self, pos, 24.0)
		else:
			draw_circle(pos, 16.0, Color(0.1, 0.08, 0.06, 0.55))
			draw_arc(pos, 16.0, 0.0, TAU, 20, Color("#525252"), 1.5, true)

		if font != null:
			draw_string(
				font,
				Vector2(pos.x - 28.0, pos.y + 30.0),
				label,
				HORIZONTAL_ALIGNMENT_CENTER,
				56.0,
				10,
				Color("#fde047") if unlocked else Color("#94a3b8")
			)


func _are_all_items_collected() -> bool:
	return (
		GameManager.has_item("carimbo")
		and GameManager.has_item("folha")
		and GameManager.has_item("pena")
		and GameManager.has_item("tinta")
	)


func _open_opening_leaflet() -> void:
	_is_opening_active = true
	_opening_cooldown = 0.3
	_opening_overlay.visible = true
	GameManager.set_paused(true)
	if _opening_button != null:
		_opening_button.grab_focus()


func _close_opening_leaflet() -> void:
	if not _is_opening_active:
		return
	_is_opening_active = false
	_opening_overlay.visible = false
	GameManager.set_paused(false)
	SoundManager.play_ui_click()


func _open_naming_modal() -> void:
	if _is_naming_active or _is_opening_active:
		return
	_is_naming_active = true
	_naming_modal.visible = true
	GameManager.set_paused(true)
	SoundManager.play_ui_click()
	if _name_input != null:
		_name_input.text = GameManager.player_name
		_name_input.grab_focus()
		_name_input.caret_column = _name_input.text.length()


func _close_naming_modal() -> void:
	if not _is_naming_active:
		return
	_is_naming_active = false
	_naming_modal.visible = false
	GameManager.set_paused(false)


func _on_name_submitted(_text: String) -> void:
	_confirm_hero_name()


func _confirm_hero_name() -> void:
	if not _is_naming_active or _is_transitioning:
		return
	_is_transitioning = true
	var typed_name: String = _name_input.text.strip_edges() if _name_input != null else ""
	var final_name: String = typed_name if not typed_name.is_empty() else "Coisinha"
	GameManager.set_player_name(final_name)
	_is_naming_active = false
	_naming_modal.visible = false
	GameManager.set_paused(false)
	SoundManager.play_prensa_impacto()
	JuiceManager.add_trauma(0.6)
	GameManager.call_deferred("switch_scene", "VICTORY")


func _on_cordel_body_entered(body: Node2D, idx: int) -> void:
	if _is_transitioning or _is_opening_active or _is_naming_active or _entry_grace_timer > 0.0:
		return
	if body != _player:
		return
	if idx < 0 or idx >= _triggers.size():
		return

	var t: Dictionary = _triggers[idx]
	_info_message = "Entrando em: %s..." % str(t["title"])
	_refresh_info_label()
	_is_transitioning = true
	SoundManager.play_cordel_folhear()
	GameManager.call_deferred("switch_scene", str(t["scene_id"]))


func _on_door_body_entered(body: Node2D) -> void:
	if body != _player or _is_opening_active or _is_naming_active:
		return
	if _are_all_items_collected():
		_open_naming_modal()
	else:
		_info_message = "🔒 Só heróis têm a chave! Reúna os 4 instrumentos na Prensa."
		_refresh_info_label()
		DialogPanel.post_message(_info_message, {"icon": "🔒"})


func _on_door_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_info_message = DEFAULT_INFO_MESSAGE
	_refresh_info_label()


func _on_prensa_focus_gained(_interactor: Node2D) -> void:
	if _are_all_items_collected():
		_info_message = "✨ 4 ITENS REUNIDOS! Aperte [E / Enter] para estampar teu nome e encerrar o cordel!"
	else:
		var remaining: int = 4 - GameManager.get_unlocked_item_count()
		_info_message = "🔒 A Prensa necessita dos 4 instrumentos mestre! Faltam %d elemento(s)." % remaining
	_refresh_info_label()


func _on_prensa_focus_lost(_interactor: Node2D) -> void:
	_info_message = DEFAULT_INFO_MESSAGE
	_refresh_info_label()


func _on_prensa_interacted(_interactor: Node2D) -> void:
	if _are_all_items_collected():
		_open_naming_modal()
	else:
		var remaining: int = 4 - GameManager.get_unlocked_item_count()
		var msg: String = "🔒 A Prensa necessita dos 4 instrumentos mestre! Faltam %d elemento(s)." % remaining
		_info_message = msg
		_refresh_info_label()
		SoundManager.play_ui_click()
		DialogPanel.post_message(msg, {"icon": "🔒"})


func _on_inventory_changed(_item_id: String) -> void:
	queue_redraw()


func _refresh_info_label() -> void:
	if _info_label != null:
		_info_label.text = _info_message
