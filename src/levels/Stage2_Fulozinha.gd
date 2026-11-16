class_name Stage2_Fulozinha
extends Node2D

const VIEWPORT_WIDTH: float = 960.0
const VIEWPORT_HEIGHT: float = 580.0
const PLAYFIELD_HEIGHT: float = 540.0

const PEDRA_POS: Vector2 = Vector2(840.0, 270.0)
const PEDRA_SIZE: Vector2 = Vector2(28.0, 28.0)
const PLACA_POS: Vector2 = Vector2(800.0, 250.0)
const PLACA_SIZE: Vector2 = Vector2(32.0, 32.0)

const FULO_START_POS: Vector2 = Vector2(750.0, 270.0)
const FULO_SIZE: Vector2 = Vector2(42.0, 48.0)
const FULO_SPEED: float = 155.0

const DEFAULT_STATUS_MESSAGE: String = "Navegue pelos 6 lotes da fazenda. Encontre o Fumo na moita do Lote 1b e leve à Fulô no Lote 3b!"

var _current_lot: String = "0"
var _hurt_cooldown: float = 0.0
var _fulo_flee_timer: float = 0.0
var _fulozinha_pos: Vector2 = FULO_START_POS

var _has_fumo: bool = false
var _whistle_timer: float = 6.0
var _whistle_duration: float = 0.0
var _whistle_wave_radius: float = 0.0

var _state_status: String = "PLAYING" # PLAYING | SUCCESS | FAILED
var _fail_timer: float = 0.0
var _anim_time: float = 0.0
var _status_message: String = DEFAULT_STATUS_MESSAGE

var _lots: Dictionary = {}
var _gate_colliders: Array[CollisionShape2D] = []

@onready var _player: Coisinha = $Coisinha
@onready var _walls_root: Node2D = $WallsRoot
@onready var _bushes_root: Node2D = $BushesRoot
@onready var _placa_interactable: InteractableComponent = $PlacaInteractable
@onready var _title_label: Label = $HUDLayer/TopBar/TitleLabel
@onready var _hp_label: Label = $HUDLayer/TopBar/HPBox/HPLabel
@onready var _fumo_label: Label = $HUDLayer/TopBar/FumoLabel
@onready var _status_label: Label = $HUDLayer/StatusBar/StatusLabel


func _ready() -> void:
	GameManager.current_scene_id = "STAGE_2_FULOZINHA"
	SoundManager.play_music("STAGE2_FULOZINHA")
	SoundManager.set_music_tension(0.2)

	_reset_stage_data()

	if _player != null:
		_player.global_position = Vector2(120.0, 270.0)
		_player.move_speed = 230.0
		_player.facing = "down"
		_player.controls_inverted = false
		_player.shouted.connect(_on_player_shouted)
		if _player.health != null:
			_player.health.invulnerability_duration = 5.0
			_player.health.reset_health()
			_player.health.damaged.connect(_on_player_hp_updated)
			_player.health.healed.connect(_on_player_hp_updated)

	if _placa_interactable != null:
		_placa_interactable.global_position = PLACA_POS
		_placa_interactable.interacted.connect(_on_placa_interacted)

	EventBus.stage_reset_requested.connect(_reset_all_bushes)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)

	_rebuild_lot_geometry()
	_refresh_hud()

	NarrativeOverlay.show_intro({
		"phase_number": 2,
		"title": "A Fazenda da Cumade Fulozinha",
		"subtitle": "Tranças de cipó, assobios e a oferenda de fumo",
		"verses": PackedStringArray([
			"Na mata fechada da fazenda a Fulô vigia o sertão,",
			"Seus assobios enganam quem não presta atenção;",
			"Ache o fumo de rolo na moita do Lote 1b com primor,",
			"E leve a oferenda à Fulô para acalmar seu furor!",
		]),
		"objective": "Encontre o Fumo de Rolo no Lote 1b e entregue à Cumade Fulozinha no Lote 3b!",
		"item_reward": {
			"id": "folha",
			"name": "Página Rasgada",
			"icon": "📄",
		},
	})
	queue_redraw()


func _exit_tree() -> void:
	if _player != null:
		_player.controls_inverted = false
	_reset_all_bushes()


func _reset_stage_data() -> void:
	_current_lot = "0"
	_hurt_cooldown = 0.0
	_fulo_flee_timer = 0.0
	_fulozinha_pos = FULO_START_POS
	_has_fumo = false
	_whistle_timer = 6.0
	_whistle_duration = 0.0
	_whistle_wave_radius = 0.0
	_state_status = "PLAYING"
	_fail_timer = 0.0
	_anim_time = 0.0
	_status_message = DEFAULT_STATUS_MESSAGE
	_build_lots_data()


func _build_lots_data() -> void:
	_lots = {
		"0": {
			"id": "0",
			"name": "LOTE 0 — ENTRADA DA FAZENDA",
			"walls": [
				Rect2(480.0 - 480.0, 12.0 - 12.0, 960.0, 24.0),
				Rect2(480.0 - 480.0, 528.0 - 12.0, 960.0, 24.0),
				Rect2(12.0 - 12.0, 270.0 - 270.0, 24.0, 540.0),
				Rect2(948.0 - 12.0, 105.0 - 105.0, 24.0, 210.0),
				Rect2(948.0 - 12.0, 435.0 - 105.0, 24.0, 210.0),
				Rect2(820.0 - 115.0, 198.0 - 12.0, 230.0, 24.0),
				Rect2(820.0 - 115.0, 342.0 - 12.0, 230.0, 24.0),
				Rect2(260.0 - 12.0, 270.0 - 130.0, 24.0, 260.0),
				Rect2(425.0 - 12.0, 388.0 - 125.0, 24.0, 250.0),
				Rect2(580.0 - 12.0, 285.0 - 120.0, 24.0, 240.0),
				Rect2(432.0 - 160.0, 152.0 - 12.0, 320.0, 24.0),
			],
			"gates": [
				{"rect": Rect2(260.0 - 12.0, 460.0 - 55.0, 24.0, 110.0), "is_open": true},
				{"rect": Rect2(718.0 - 12.0, 270.0 - 55.0, 24.0, 110.0), "is_open": true},
				{"rect": Rect2(580.0 - 12.0, 80.0 - 55.0, 24.0, 110.0), "is_open": false},
			],
			"bushes": [
				{"id": "b_0_1", "pos": Vector2(130.0, 100.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_0_2", "pos": Vector2(350.0, 320.0), "radius": 36.0, "type": "cacto", "is_searched": false},
				{"id": "b_0_3", "pos": Vector2(650.0, 100.0), "radius": 36.0, "type": "normal", "is_searched": false},
				{"id": "b_0_4", "pos": Vector2(740.0, 440.0), "radius": 36.0, "type": "cacto", "is_searched": false},
			],
		},
		"1a": {
			"id": "1a",
			"name": "LOTE 1a — POMAR NORTE",
			"walls": [
				Rect2(480.0 - 480.0, 12.0 - 12.0, 960.0, 24.0),
				Rect2(12.0 - 12.0, 270.0 - 270.0, 24.0, 540.0),
				Rect2(210.0 - 210.0, 528.0 - 12.0, 420.0, 24.0),
				Rect2(750.0 - 210.0, 528.0 - 12.0, 420.0, 24.0),
				Rect2(948.0 - 12.0, 105.0 - 105.0, 24.0, 210.0),
				Rect2(948.0 - 12.0, 435.0 - 105.0, 24.0, 210.0),
				Rect2(300.0 - 12.0, 340.0 - 175.0, 24.0, 350.0),
				Rect2(552.0 - 12.0, 390.0 - 125.0, 24.0, 250.0),
				Rect2(740.0 - 12.0, 269.0 - 131.0, 24.0, 262.0),
				Rect2(508.0 - 220.0, 150.0 - 12.0, 440.0, 24.0),
			],
			"gates": [
				{"rect": Rect2(300.0 - 12.0, 80.0 - 55.0, 24.0, 110.0), "is_open": true},
				{"rect": Rect2(552.0 - 12.0, 80.0 - 55.0, 24.0, 110.0), "is_open": false},
				{"rect": Rect2(740.0 - 12.0, 458.0 - 55.0, 24.0, 110.0), "is_open": true},
			],
			"bushes": [
				{"id": "b_1a_1", "pos": Vector2(130.0, 410.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_1a_2", "pos": Vector2(420.0, 100.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_1a_3", "pos": Vector2(870.0, 80.0), "radius": 36.0, "type": "cacto", "is_searched": false},
				{"id": "b_1a_4", "pos": Vector2(560.0, 220.0), "radius": 36.0, "type": "cacto", "is_searched": false},
			],
		},
		"1b": {
			"id": "1b",
			"name": "LOTE 1b — PORTEIRA DO TOCO (FUMO NA MOITA)",
			"walls": [
				Rect2(480.0 - 480.0, 12.0 - 12.0, 960.0, 24.0),
				Rect2(948.0 - 12.0, 270.0 - 270.0, 24.0, 540.0),
				Rect2(12.0 - 12.0, 105.0 - 105.0, 24.0, 210.0),
				Rect2(12.0 - 12.0, 435.0 - 105.0, 24.0, 210.0),
				Rect2(210.0 - 210.0, 528.0 - 12.0, 420.0, 24.0),
				Rect2(750.0 - 210.0, 528.0 - 12.0, 420.0, 24.0),
				Rect2(270.0 - 12.0, 275.0 - 125.0, 24.0, 250.0),
				Rect2(408.0 - 12.0, 332.0 - 182.5, 24.0, 365.0),
				Rect2(780.0 - 12.0, 398.0 - 117.5, 24.0, 235.0),
				Rect2(608.0 - 185.0, 162.0 - 12.0, 370.0, 24.0),
			],
			"gates": [
				{"rect": Rect2(270.0 - 12.0, 458.0 - 55.0, 24.0, 110.0), "is_open": true},
				{"rect": Rect2(780.0 - 12.0, 227.0 - 50.0, 24.0, 100.0), "is_open": true},
				{"rect": Rect2(340.0 - 55.0, 388.0 - 12.0, 110.0, 24.0), "is_open": false},
			],
			"bushes": [
				{"id": "b_1b_fumo", "pos": Vector2(850.0, 470.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_1b_1", "pos": Vector2(80.0, 470.0), "radius": 36.0, "type": "cacto", "is_searched": false},
				{"id": "b_1b_2", "pos": Vector2(340.0, 470.0), "radius": 36.0, "type": "fumo", "is_searched": false},
				{"id": "b_1b_3", "pos": Vector2(600.0, 100.0), "radius": 36.0, "type": "normal", "is_searched": false},
			],
		},
		"2a": {
			"id": "2a",
			"name": "LOTE 2a — PASTAGEM CENTRAL OESTE",
			"walls": [
				Rect2(210.0 - 210.0, 12.0 - 12.0, 420.0, 24.0),
				Rect2(750.0 - 210.0, 12.0 - 12.0, 420.0, 24.0),
				Rect2(210.0 - 210.0, 528.0 - 12.0, 420.0, 24.0),
				Rect2(750.0 - 210.0, 528.0 - 12.0, 420.0, 24.0),
				Rect2(12.0 - 12.0, 105.0 - 105.0, 24.0, 210.0),
				Rect2(12.0 - 12.0, 435.0 - 105.0, 24.0, 210.0),
				Rect2(948.0 - 12.0, 105.0 - 105.0, 24.0, 210.0),
				Rect2(948.0 - 12.0, 435.0 - 105.0, 24.0, 210.0),
				Rect2(160.0 - 12.0, 270.0 - 90.0, 24.0, 180.0),
				Rect2(480.0 - 232.5, 388.0 - 12.0, 465.0, 24.0),
				Rect2(820.0 - 12.0, 270.0 - 90.0, 24.0, 180.0),
				Rect2(410.0 - 12.0, 112.0 - 85.0, 24.0, 170.0),
				Rect2(550.0 - 12.0, 112.0 - 85.0, 24.0, 170.0),
			],
			"gates": [
				{"rect": Rect2(480.0 - 55.0, 185.0 - 12.0, 110.0, 24.0), "is_open": true},
				{"rect": Rect2(700.0 - 12.0, 458.0 - 55.0, 24.0, 110.0), "is_open": false},
				{"rect": Rect2(260.0 - 12.0, 458.0 - 55.0, 24.0, 110.0), "is_open": true},
			],
			"bushes": [
				{"id": "b_2a_1", "pos": Vector2(160.0, 420.0), "radius": 36.0, "type": "cacto", "is_searched": false},
				{"id": "b_2a_2", "pos": Vector2(350.0, 120.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_2a_3", "pos": Vector2(820.0, 140.0), "radius": 36.0, "type": "normal", "is_searched": false},
				{"id": "b_2a_4", "pos": Vector2(620.0, 470.0), "radius": 36.0, "type": "fruta", "is_searched": false},
			],
		},
		"2b": {
			"id": "2b",
			"name": "LOTE 2b — PASTAGEM CENTRAL LESTE",
			"walls": [
				Rect2(948.0 - 12.0, 270.0 - 270.0, 24.0, 540.0),
				Rect2(210.0 - 210.0, 12.0 - 12.0, 420.0, 24.0),
				Rect2(750.0 - 210.0, 12.0 - 12.0, 420.0, 24.0),
				Rect2(210.0 - 210.0, 528.0 - 12.0, 420.0, 24.0),
				Rect2(750.0 - 210.0, 528.0 - 12.0, 420.0, 24.0),
				Rect2(12.0 - 12.0, 105.0 - 105.0, 24.0, 210.0),
				Rect2(12.0 - 12.0, 435.0 - 105.0, 24.0, 210.0),
				Rect2(408.0 - 12.0, 270.0 - 130.0, 24.0, 260.0),
				Rect2(550.0 - 12.0, 270.0 - 130.0, 24.0, 260.0),
				Rect2(760.0 - 12.0, 270.0 - 130.0, 24.0, 260.0),
				Rect2(230.0 - 12.0, 270.0 - 130.0, 24.0, 260.0),
			],
			"gates": [
				{"rect": Rect2(550.0 - 12.0, 82.0 - 55.0, 24.0, 110.0), "is_open": false},
				{"rect": Rect2(408.0 - 12.0, 458.0 - 55.0, 24.0, 110.0), "is_open": true},
			],
			"bushes": [
				{"id": "b_2b_1", "pos": Vector2(170.0, 120.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_2b_2", "pos": Vector2(280.0, 450.0), "radius": 36.0, "type": "cacto", "is_searched": false},
				{"id": "b_2b_3", "pos": Vector2(710.0, 120.0), "radius": 36.0, "type": "normal", "is_searched": false},
				{"id": "b_2b_4", "pos": Vector2(810.0, 450.0), "radius": 36.0, "type": "fruta", "is_searched": false},
			],
		},
		"3a": {
			"id": "3a",
			"name": "LOTE 3a — BOSQUE SUL PROFUNDO",
			"walls": [
				Rect2(480.0 - 480.0, 528.0 - 12.0, 960.0, 24.0),
				Rect2(12.0 - 12.0, 270.0 - 270.0, 24.0, 540.0),
				Rect2(210.0 - 210.0, 12.0 - 12.0, 420.0, 24.0),
				Rect2(750.0 - 210.0, 12.0 - 12.0, 420.0, 24.0),
				Rect2(948.0 - 12.0, 105.0 - 105.0, 24.0, 210.0),
				Rect2(948.0 - 12.0, 435.0 - 105.0, 24.0, 210.0),
				Rect2(365.0 - 200.0, 150.0 - 12.0, 400.0, 24.0),
				Rect2(152.0 - 12.0, 270.0 - 135.0, 24.0, 270.0),
				Rect2(550.0 - 12.0, 80.0 - 55.0, 24.0, 110.0),
				Rect2(495.0 - 330.0, 390.0 - 12.0, 660.0, 24.0),
				Rect2(810.0 - 12.0, 280.0 - 95.0, 24.0, 190.0),
			],
			"gates": [
				{"rect": Rect2(880.0 - 55.0, 198.0 - 12.0, 110.0, 24.0), "is_open": true},
			],
			"bushes": [
				{"id": "b_3a_1", "pos": Vector2(820.0, 150.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_3a_2", "pos": Vector2(890.0, 150.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_3a_3", "pos": Vector2(890.0, 80.0), "radius": 36.0, "type": "cacto", "is_searched": false},
				{"id": "b_3a_4", "pos": Vector2(820.0, 80.0), "radius": 36.0, "type": "normal", "is_searched": false},
			],
		},
		"3b": {
			"id": "3b",
			"name": "LOTE 3b — MORADA DA CUMADE FULOZINHA",
			"walls": [
				Rect2(480.0 - 480.0, 528.0 - 12.0, 960.0, 24.0),
				Rect2(948.0 - 12.0, 270.0 - 270.0, 24.0, 540.0),
				Rect2(210.0 - 210.0, 12.0 - 12.0, 420.0, 24.0),
				Rect2(750.0 - 210.0, 12.0 - 12.0, 420.0, 24.0),
				Rect2(12.0 - 12.0, 105.0 - 105.0, 24.0, 210.0),
				Rect2(12.0 - 12.0, 435.0 - 105.0, 24.0, 210.0),
				Rect2(270.0 - 12.0, 270.0 - 135.0, 24.0, 270.0),
				Rect2(410.0 - 12.0, 270.0 - 135.0, 24.0, 270.0),
				Rect2(550.0 - 12.0, 270.0 - 135.0, 24.0, 270.0),
				Rect2(690.0 - 12.0, 270.0 - 135.0, 24.0, 270.0),
			],
			"gates": [
				{"rect": Rect2(480.0 - 55.0, 270.0 - 12.0, 110.0, 24.0), "is_open": true},
			],
			"bushes": [
				{"id": "b_3b_1", "pos": Vector2(80.0, 80.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_3b_2", "pos": Vector2(480.0, 180.0), "radius": 36.0, "type": "fruta", "is_searched": false},
				{"id": "b_3b_3", "pos": Vector2(880.0, 480.0), "radius": 36.0, "type": "normal", "is_searched": false},
				{"id": "b_3b_4", "pos": Vector2(480.0, 380.0), "radius": 36.0, "type": "fruta", "is_searched": false},
			],
		},
	}


func _rebuild_lot_geometry() -> void:
	for child: Node in _walls_root.get_children():
		child.queue_free()
	for child: Node in _bushes_root.get_children():
		child.queue_free()
	_gate_colliders.clear()

	var lot: Dictionary = _lots[_current_lot] as Dictionary

	# Paredes sólidas do lote
	var walls_body: StaticBody2D = StaticBody2D.new()
	walls_body.collision_layer = 1
	walls_body.collision_mask = 0
	for rect: Rect2 in lot["walls"] as Array:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		col.position = rect.position + rect.size * 0.5
		walls_body.add_child(col)
	_walls_root.add_child(walls_body)

	# Portões internos dinâmicos
	var gates_body: StaticBody2D = StaticBody2D.new()
	gates_body.collision_layer = 1
	gates_body.collision_mask = 0
	for gate: Dictionary in lot["gates"] as Array:
		var rect: Rect2 = gate["rect"] as Rect2
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		col.position = rect.position + rect.size * 0.5
		col.disabled = bool(gate["is_open"])
		gates_body.add_child(col)
		_gate_colliders.append(col)
	_walls_root.add_child(gates_body)

	# Moitas do lote
	var bushes: Array = lot["bushes"] as Array
	for idx: int in range(bushes.size()):
		var bush: Dictionary = bushes[idx] as Dictionary
		var area: InteractableComponent = InteractableComponent.new()
		area.position = bush["pos"] as Vector2
		area.collision_layer = 8
		area.collision_mask = 2
		area.interact_id = str(bush["id"])
		area.prompt_text = "Vasculhar Moita [E]"
		area.interact_priority = 5

		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = float(bush["radius"]) + 30.0
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		area.add_child(col)
		area.interacted.connect(_on_bush_interacted.bind(_current_lot, idx))
		_bushes_root.add_child(area)

	# Placa de aviso exclusiva do Lote 0
	if _placa_interactable != null:
		var in_lot_0: bool = _current_lot == "0"
		_placa_interactable.monitoring = in_lot_0
		_placa_interactable.monitorable = in_lot_0


func _process(delta: float) -> void:
	_anim_time += delta
	if _hurt_cooldown > 0.0:
		_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)
	if _fulo_flee_timer > 0.0:
		_fulo_flee_timer = maxf(0.0, _fulo_flee_timer - delta)

	if _state_status == "FAILED":
		_fail_timer -= delta
		if _fail_timer <= 0.0:
			_state_status = "DONE"
			GameManager.switch_scene("STUDIO")
		queue_redraw()
		return

	if NarrativeOverlay.is_overlay_active or DialogPanel.is_dialog_active or _state_status != "PLAYING":
		queue_redraw()
		return

	_update_whistle_and_gates(delta)
	_check_lot_transitions()
	_check_cactuses_proximity()
	_check_pedra_and_placa_lot0()
	_update_fulozinha_lot3b(delta)

	_refresh_hud()
	queue_redraw()


func _update_whistle_and_gates(delta: float) -> void:
	var in_fulozinha_lair: bool = _current_lot == "3b"
	var timer_interval: float = 4.5 if in_fulozinha_lair else 7.0
	SoundManager.set_music_tension(0.75 if in_fulozinha_lair else 0.2)

	_whistle_timer -= delta
	if _whistle_timer <= 0.0:
		_whistle_timer = timer_interval
		if _player != null:
			_player.controls_inverted = true
		_whistle_duration = 4.0 if in_fulozinha_lair else 3.2
		_whistle_wave_radius = 15.0
		_status_message = "🎶 ASSOBIO NA MATA! Os portões alternaram e os controles foram invertidos!"
		SoundManager.play_cumade_assobio(1.2 if in_fulozinha_lair else 1.0)
		JuiceManager.add_trauma(0.3)
		JuiceManager.emit_particles("note", Vector2(480.0, 200.0), self, {"count": 8, "speed": 45.0})

		for lot_key: Variant in _lots.keys():
			var lot_data: Dictionary = _lots[lot_key] as Dictionary
			for gate: Dictionary in lot_data["gates"] as Array:
				gate["is_open"] = not bool(gate["is_open"])

		_sync_current_lot_gate_colliders()

	if _player != null and _player.controls_inverted:
		_whistle_duration -= delta
		_whistle_wave_radius += 350.0 * delta
		if _whistle_duration <= 0.0:
			_player.controls_inverted = false
			_whistle_wave_radius = 0.0
			_status_message = "🌿 O assobio cessou. Controles normais."


func _sync_current_lot_gate_colliders() -> void:
	var lot: Dictionary = _lots[_current_lot] as Dictionary
	var gates: Array = lot["gates"] as Array
	for i: int in range(mini(gates.size(), _gate_colliders.size())):
		var gate: Dictionary = gates[i] as Dictionary
		var col: CollisionShape2D = _gate_colliders[i]
		if is_instance_valid(col):
			col.disabled = bool(gate["is_open"])


func _check_lot_transitions() -> void:
	if _player == null:
		return

	var pos: Vector2 = _player.global_position
	var changed: bool = false

	if pos.x > 936.0:
		match _current_lot:
			"0":
				_current_lot = "2a"
				pos.x = 40.0
				changed = true
			"2a":
				_current_lot = "2b"
				pos.x = 40.0
				changed = true
			"1a":
				_current_lot = "1b"
				pos.x = 40.0
				changed = true
			"3a":
				_current_lot = "3b"
				pos.x = 40.0
				changed = true
	elif pos.x < 24.0:
		match _current_lot:
			"2b":
				_current_lot = "2a"
				pos.x = 920.0
				changed = true
			"2a":
				_current_lot = "0"
				pos.x = 920.0
				changed = true
			"1b":
				_current_lot = "1a"
				pos.x = 920.0
				changed = true
			"3b":
				_current_lot = "3a"
				pos.x = 920.0
				changed = true

	if pos.y < 24.0:
		match _current_lot:
			"2a":
				_current_lot = "1a"
				pos.y = 500.0
				changed = true
			"2b":
				_current_lot = "1b"
				pos.y = 500.0
				changed = true
			"3a":
				_current_lot = "2a"
				pos.y = 500.0
				changed = true
			"3b":
				_current_lot = "2b"
				pos.y = 500.0
				changed = true
	elif pos.y > 516.0:
		match _current_lot:
			"1a":
				_current_lot = "2a"
				pos.y = 40.0
				changed = true
			"1b":
				_current_lot = "2b"
				pos.y = 40.0
				changed = true
			"2a":
				_current_lot = "3a"
				pos.y = 40.0
				changed = true
			"2b":
				_current_lot = "3b"
				pos.y = 40.0
				changed = true

	pos.x = clampf(pos.x, 20.0, 940.0)
	pos.y = clampf(pos.y, 20.0, 520.0)
	_player.global_position = pos

	if changed:
		_rebuild_lot_geometry()


func _check_cactuses_proximity() -> void:
	if _player == null or _player.health == null:
		return
	if _hurt_cooldown > 0.0 or _player.health.is_invulnerable():
		return

	var lot: Dictionary = _lots[_current_lot] as Dictionary
	for bush: Dictionary in lot["bushes"] as Array:
		if str(bush["type"]) != "cacto":
			continue
		var dist: float = _player.global_position.distance_to(bush["pos"] as Vector2)
		if dist < float(bush["radius"]) + 12.0:
			bush["is_searched"] = true
			_hurt_cooldown = 1.2
			_player.health.take_damage(1)
			SoundManager.play_hurt_cacto()
			SoundManager.play_grito()
			JuiceManager.add_trauma(0.45)
			JuiceManager.emit_particles("dust", _player.global_position, self, {"count": 12, "speed": 70.0})
			_status_message = "🌵 AI! ESPINHO DE CACTO! Você perdeu 1 HP e soltou um grito!"
			if _player.health.is_dead():
				_trigger_failure("💀 VOCÊ NÃO RESISTIU AOS ESPINHOS DA CAATINGA!", 2.5)
			return


func _on_bush_interacted(_actor: Node, lot_id: String, bush_idx: int) -> void:
	if _state_status != "PLAYING" or lot_id != _current_lot:
		return
	var lot: Dictionary = _lots[_current_lot] as Dictionary
	var bushes: Array = lot["bushes"] as Array
	if bush_idx < 0 or bush_idx >= bushes.size():
		return
	var bush: Dictionary = bushes[bush_idx] as Dictionary
	if bool(bush["is_searched"]):
		return

	bush["is_searched"] = true
	var btype: String = str(bush["type"])
	var bpos: Vector2 = bush["pos"] as Vector2

	if btype == "fumo" and not _has_fumo:
		_has_fumo = true
		GameManager.unlock_bush_item("fumo")
		_status_message = "🍂 FUMO DE ROLO ENCONTRADO NA MOITA! Leve a oferenda à Cumade no Lote 3b!"
		SoundManager.play_pickup()
		SoundManager.play_item_descobrir()
		JuiceManager.emit_particles("leaf", bpos, self, {"count": 12, "speed": 45.0})
		DialogPanel.start_dialog(
			"item_fumo",
			"Fumo de Rolo Aromático",
			"🍂",
			[
				{
					"speaker": "Coisinha",
					"avatar_icon": "🍂",
					"text": "🍂 \"Achei o fumo de rolo perfumado! Agora posso levar até o toco sagrado no Lote 3b e apaziguar a Cumade Fulozinha!\"",
				},
			],
			Callable(),
			true
		)
	elif btype == "fruta":
		if _player != null and _player.health != null and _player.health.current_hp < _player.health.max_hp:
			_player.health.heal(1)
			_status_message = "🍎 FRUTA REGIONAL! Você recuperou +1 HP!"
		else:
			_status_message = "🍎 Fruta deliciosa da caatinga!"
		SoundManager.play_fruit_eat()
		JuiceManager.emit_particles("sparkle", bpos, self, {"count": 10, "speed": 40.0})
	elif btype == "cacto":
		if _player != null and _player.health != null and not _player.health.is_invulnerable():
			_player.health.take_damage(1)
			SoundManager.play_hurt_cacto()
			SoundManager.play_grito()
			JuiceManager.add_trauma(0.45)
			_status_message = "🌵 AI! ESPINHO DE CACTO! Você perdeu 1 HP e soltou um grito!"
			if _player.health.is_dead():
				_trigger_failure("💀 VOCÊ NÃO RESISTIU AOS ESPINHOS DA CAATINGA!", 2.5)
	else:
		JuiceManager.emit_particles("leaf", bpos, self, {"count": 8, "speed": 35.0})


func _check_pedra_and_placa_lot0() -> void:
	if _current_lot != "0" or _player == null or _player.health == null:
		return

	var dist_pedra: float = _player.global_position.distance_to(PEDRA_POS)
	var dist_placa: float = _player.global_position.distance_to(PLACA_POS)

	if dist_pedra < 26.0 and _hurt_cooldown <= 0.0 and not _player.health.is_invulnerable():
		_hurt_cooldown = 2.0
		_player.health.take_damage(1)
		SoundManager.play_ui_click()
		SoundManager.play_grito()
		JuiceManager.add_trauma(0.4)
		JuiceManager.emit_particles("dust", _player.global_position + Vector2(0.0, 18.0), self, {"count": 8, "speed": 40.0})

		var trip_phrases: PackedStringArray = PackedStringArray([
			"🗣️ \"Coisinha, tropeçou! (-1 Vida)\"",
			"🗣️ \"Coisinha vai arrancar um dedo! (-1 Vida)\"",
			"🗣️ \"Coisinha tá adivinhando butija! (-1 Vida)\"",
		])
		_status_message = trip_phrases[randi() % trip_phrases.size()]

		if _player.health.is_dead():
			_trigger_failure("💀 VOCÊ NÃO RESISTIU AOS ESPINHOS E TROPEÇOS DA CAATINGA!", 1.8)
	elif dist_pedra >= 26.0 and dist_pedra < 45.0 and _hurt_cooldown <= 0.0:
		_status_message = "🪨 PISTA SECRETA: Uma pedra solta na saída do Lote 0... Sob ela jaz a Botija de Mané!"
	elif dist_placa < 45.0 and _hurt_cooldown <= 0.0:
		_status_message = "🪧 PLACA: \"cuidado risco de topada\""


func _on_placa_interacted(_actor: Node) -> void:
	if _current_lot != "0" or _state_status != "PLAYING":
		return
	_status_message = "🪧 PLACA: \"cuidado risco de topada\""
	SoundManager.play_ui_click()


func _update_fulozinha_lot3b(delta: float) -> void:
	if _current_lot != "3b" or _player == null:
		return

	var is_fleeing: bool = _fulo_flee_timer > 0.0
	var dir_vec: Vector2 = (_fulozinha_pos - _player.global_position) if is_fleeing else (_player.global_position - _fulozinha_pos)
	var angle: float = dir_vec.angle() if dir_vec.length_squared() > 0.001 else 0.0

	_fulozinha_pos.x = clampf(_fulozinha_pos.x + cos(angle) * FULO_SPEED * delta, 50.0, 910.0)
	_fulozinha_pos.y = clampf(_fulozinha_pos.y + sin(angle) * FULO_SPEED * delta, 50.0, 490.0)

	var dist_fulo: float = _player.global_position.distance_to(_fulozinha_pos)
	if dist_fulo < 36.0 and not is_fleeing:
		if _has_fumo:
			_state_status = "SUCCESS"
			_fulo_flee_timer = 3.0
			_player.controls_inverted = false
			GameManager.unlock_item("folha")
			SoundManager.play_victory_jingle()
			JuiceManager.emit_particles("sparkle", _fulozinha_pos, self, {"count": 20, "speed": 60.0})

			NarrativeOverlay.show_outro(
				{
					"phase_number": 2,
					"title": "A Fazenda da Cumade Fulozinha",
					"verses": PackedStringArray([
						"A fumaça perfumada acalmou a guardiã da mata,",
						"Que das suas tranças soltas uma folha de ouro desata;",
						"Com carinho e respeito pelo sagrado sertão,",
						"A Página Rasgada brilha em sua mão!",
					]),
					"item_reward": {
						"id": "folha",
						"name": "Página Rasgada",
						"icon": "📄",
					},
				},
				func() -> void:
					GameManager.switch_scene("STUDIO")
			)
		elif _hurt_cooldown <= 0.0 and _player.health != null and not _player.health.is_invulnerable():
			_hurt_cooldown = 1.5
			_fulo_flee_timer = 3.0
			_player.health.take_damage(1)
			_status_message = "🌿 A Cumade Fulozinha amarrou seus cadarços! (-1 HP)"
			SoundManager.play_chicote()
			SoundManager.play_grito()
			JuiceManager.add_trauma(0.5)
			JuiceManager.emit_particles("dust", _player.global_position, self, {"count": 10, "speed": 50.0})

			if _player.health.is_dead():
				_trigger_failure("💀 VOCÊ NÃO RESISTIU AOS ATAQUES DA CUMADE FULOZINHA!", 1.8)


func _on_player_shouted(world_pos: Vector2) -> void:
	if _state_status != "PLAYING" or _current_lot != "3b":
		return
	if world_pos.distance_to(_fulozinha_pos) <= 180.0:
		_fulo_flee_timer = 3.0
		_status_message = "🗣️ SEU GRITO ASSUSTOU A CUMADE FULOZINHA! Ela fugiu na direção oposta!"


func _on_player_hp_updated(_amount: int, _current_hp: int, _max_hp: int) -> void:
	_refresh_hud()


func _trigger_failure(msg: String, delay: float) -> void:
	_state_status = "FAILED"
	_fail_timer = delay
	_status_message = msg
	if _player != null:
		_player.controls_inverted = false
	SoundManager.play_defeat_jingle()
	_refresh_hud()


func _reset_all_bushes() -> void:
	for lot_key: Variant in _lots.keys():
		var lot_data: Dictionary = _lots[lot_key] as Dictionary
		for bush: Dictionary in lot_data["bushes"] as Array:
			bush["is_searched"] = false


func _on_scene_change_requested(_next_scene_id: String) -> void:
	_reset_all_bushes()


func _refresh_hud() -> void:
	var lot: Dictionary = _lots.get(_current_lot, {}) as Dictionary
	var lot_name: String = str(lot.get("name", "LOTE 0"))
	if _title_label != null:
		_title_label.text = "🌿 FASE 2: %s" % lot_name

	if _hp_label != null and _player != null and _player.health != null:
		var hearts: String = ""
		for h: int in range(_player.health.max_hp):
			if h > 0:
				hearts += " "
			hearts += "❤️" if h < _player.health.current_hp else "🖤"
		_hp_label.text = hearts

	if _fumo_label != null:
		_fumo_label.text = "🍂 Fumo: OK" if _has_fumo else "🍂 Fumo: 0/1"
		_fumo_label.add_theme_color_override(
			"font_color",
			Color("#4ade80") if _has_fumo else Color("#fde68a")
		)

	if _status_label != null:
		_status_label.text = _status_message


func _draw() -> void:
	var lot: Dictionary = _lots.get(_current_lot, {}) as Dictionary
	var font: Font = ThemeDB.fallback_font

	# 1. Fundo de Terra Batida
	XiloDraw.draw_chao_terra_batida(self, Rect2(0.0, 0.0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT))

	# 2. Moldura de Cordel
	XiloDraw.draw_moldura_cordel(self, Rect2(8.0, 8.0, VIEWPORT_WIDTH - 16.0, PLAYFIELD_HEIGHT - 16.0), 3.0)

	# 3. Paredes Labirinticas e Perimetricas
	for rect: Rect2 in lot.get("walls", []) as Array:
		XiloDraw.draw_rect_xilo(self, rect, Color("#334155"), Color("#64748b"), 1.5)

	# 4. Portoes Internos Dinamicos
	for gate: Dictionary in lot.get("gates", []) as Array:
		var rect: Rect2 = gate["rect"] as Rect2
		var is_open: bool = bool(gate["is_open"])
		var fill_col: Color = Color("#16a34a") if is_open else Color("#dc2626")
		XiloDraw.draw_rect_xilo(self, rect, fill_col, Color.WHITE, 1.5)

	# 5. Moitas do Lote
	for bush: Dictionary in lot.get("bushes", []) as Array:
		var bpos: Vector2 = bush["pos"] as Vector2
		var bradius: float = float(bush["radius"])
		var btype: String = str(bush["type"])
		var searched: bool = bool(bush["is_searched"])

		if searched:
			match btype:
				"cacto":
					XiloDraw.draw_moita_cacto_espinhos(self, bpos, bradius)
				"fruta":
					XiloDraw.draw_moita_fruta_regional(self, bpos, bradius, true)
				"fumo":
					XiloDraw.draw_moita_revelada(self, bpos, bradius, "folha")
					if not _has_fumo and font != null:
						draw_string(font, bpos + Vector2(-36.0, -bradius - 6.0), "🍂 FUMO", HORIZONTAL_ALIGNMENT_CENTER, 72.0, 10, Color("#facc15"))
				_:
					XiloDraw.draw_moita(self, bpos, bradius, true)
		else:
			XiloDraw.draw_moita(self, bpos, bradius, false)

	# 6. Pedra da Botija e Placa de Aviso (exclusivo Lote 0)
	if _current_lot == "0":
		XiloDraw.draw_placa_aviso(self, PLACA_POS, PLACA_SIZE, {"time": _anim_time})
		XiloDraw.draw_pedra(self, PEDRA_POS, PEDRA_SIZE)
		if font != null:
			draw_string(font, PLACA_POS + Vector2(-70.0, -24.0), "Risco de topada!", HORIZONTAL_ALIGNMENT_CENTER, 140.0, 10, Color("#fef08a"))

	# 7. Cumade Fulozinha (Lote 3b)
	if _current_lot == "3b":
		XiloDraw.draw_cumade_fulozinha(self, _fulozinha_pos, FULO_SIZE, {"time": _anim_time})
		draw_arc(_fulozinha_pos, 80.0, 0.0, TAU, 36, Color(0.918, 0.702, 0.031, 0.4), 2.0, true)

	# 8. Efeito visual de Assobio e Controles Invertidos
	if _player != null and _player.controls_inverted:
		draw_rect(Rect2(0.0, 0.0, VIEWPORT_WIDTH, PLAYFIELD_HEIGHT), Color(0.863, 0.149, 0.149, 0.15))
		if _whistle_wave_radius > 0.0:
			draw_arc(Vector2(480.0, 270.0), _whistle_wave_radius, 0.0, TAU, 48, Color(0.97, 0.44, 0.44, 0.45), 2.0, true)
		if font != null:
			draw_string(
				font,
				Vector2(0.0, 62.0),
				"⚡ ASSOBIO DA FULÔ: CONTROLES INVERTIDOS! ⚡",
				HORIZONTAL_ALIGNMENT_CENTER,
				VIEWPORT_WIDTH,
				15,
				Color("#f87171")
			)
