class_name Stage4_Botija
extends Node2D

const VIEWPORT_WIDTH: float = 960.0
const VIEWPORT_HEIGHT: float = 580.0
const PLAYFIELD_HEIGHT: float = 540.0

const PLAYER_BASE_SPEED: float = 220.0
const PLAYER_BOTIJA_SPEED: float = 165.0

const FULO_SIZE: Vector2 = Vector2(42.0, 48.0)
const FULO_SPEED: float = 160.0
const FULO_PURSUIT_DURATION: float = 5.0
const FULO_VANISH_DURATION: float = 3.0
const FULO_FLEE_DURATION: float = 3.0

const PEDRA_POS: Vector2 = Vector2(840.0, 270.0)
const PEDRA_SIZE: Vector2 = Vector2(36.0, 36.0)
const BEATO_POS: Vector2 = Vector2(480.0, 180.0)
const BEATO_SIZE: Vector2 = Vector2(36.0, 50.0)
const ALTAR_RECT: Rect2 = Rect2(480.0 - 80.0, 120.0 - 20.0, 160.0, 40.0)

const DEFAULT_STATUS_MESSAGE: String = "Saia da Igreja pela esquerda, desenterre a Botija no Lote 0 e retorne ao Santuário!"

var _current_lot: String = "igreja"
var _hurt_cooldown: float = 0.0
var _trip_cooldown: float = 0.0

var _fulo_state: String = "SANCTUARY_WAIT" # SANCTUARY_WAIT | PURSUIT | FLEE | VANISHED
var _fulo_timer: float = 0.0
var _fulozinha_pos: Vector2 = Vector2(480.0, 270.0)

var _whistle_timer: float = 6.0
var _whistle_duration: float = 0.0
var _whistle_wave_radius: float = 0.0

var _has_botija: bool = false
var _has_lantern: bool = false
var _lantern_blend: float = 0.0
var _dig_progress: float = 0.0
var _is_digging: bool = false
var _dig_sound_timer: float = 0.0
var _bell_timer: float = 0.0

var _state_status: String = "PLAYING" # PLAYING | SUCCESS | FAILED
var _fail_timer: float = 0.0
var _anim_time: float = 0.0
var _status_message: String = DEFAULT_STATUS_MESSAGE

var _lots: Dictionary = {}
var _gate_colliders: Array[CollisionShape2D] = []

@onready var _player: Coisinha = $Coisinha
@onready var _walls_root: Node2D = $WallsRoot
@onready var _bushes_root: Node2D = $BushesRoot
@onready var _beato_interactable: InteractableComponent = $BeatoInteractable
@onready var _darkness_rect: ColorRect = $DarknessLayer/DarknessRect
@onready var _title_label: Label = $HUDLayer/TopBar/TitleLabel
@onready var _hp_label: Label = $HUDLayer/TopBar/HPBox/HPLabel
@onready var _item_label: Label = $HUDLayer/TopBar/ItemLabel
@onready var _status_label: Label = $HUDLayer/StatusBar/StatusLabel


func _ready() -> void:
	GameManager.current_scene_id = "STAGE_4_BOTIJA"
	SoundManager.play_music("STAGE4_BOTIJA")
	SoundManager.set_music_tension(0.1)
	SoundManager.play_sino_badalo()

	_reset_stage_data()

	if _player != null:
		_player.global_position = Vector2(480.0, 360.0)
		_player.move_speed = PLAYER_BASE_SPEED
		_player.facing = "down"
		_player.controls_inverted = false
		_player.shouted.connect(_on_player_shouted)
		if _player.health != null:
			_player.health.invulnerability_duration = 5.0
			_player.health.reset_health()
			_player.health.damaged.connect(_on_player_hp_updated)
			_player.health.healed.connect(_on_player_hp_updated)

	if _beato_interactable != null:
		_beato_interactable.global_position = BEATO_POS
		_beato_interactable.interacted.connect(_on_beato_interacted)

	EventBus.stage_reset_requested.connect(_reset_all_bushes)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)

	_rebuild_lot_geometry()
	_update_darkness_shader(0.0)
	_refresh_hud()

	NarrativeOverlay.show_intro({
		"phase_number": 4,
		"title": "A Botija de Mané Monteiro",
		"subtitle": "O tesouro encantado, a fuga nas trevas e a bênção da Igreja",
		"verses": PackedStringArray([
			"No templo sagrado da paróquia o Beato faz oração,",
			"A Cumade Furiosa não entra no santuário de bênção e perdão;",
			"Vá ao Lote 0 desenterrar o ouro de Mané Monteiro com bravura,",
			"E volte com a botija nos braços para selar a escritura!",
		]),
		"objective": "Saia pela esquerda, escave a botija no Lote 0 e retorne à Igreja!",
		"item_reward": {
			"id": "tinta",
			"name": "Tinta Encantada",
			"icon": "🖋️",
		},
	})
	queue_redraw()


func _exit_tree() -> void:
	if _player != null:
		_player.controls_inverted = false
		_player.move_speed = PLAYER_BASE_SPEED
	_reset_all_bushes()


func _reset_stage_data() -> void:
	_current_lot = "igreja"
	_hurt_cooldown = 0.0
	_trip_cooldown = 0.0
	_fulo_state = "SANCTUARY_WAIT"
	_fulo_timer = 0.0
	_fulozinha_pos = Vector2(480.0, 270.0)
	_whistle_timer = 6.0
	_whistle_duration = 0.0
	_whistle_wave_radius = 0.0
	_has_botija = false
	_has_lantern = false
	_lantern_blend = 0.0
	_dig_progress = 0.0
	_is_digging = false
	_dig_sound_timer = 0.0
	_bell_timer = 0.0
	_state_status = "PLAYING"
	_fail_timer = 0.0
	_anim_time = 0.0
	_status_message = DEFAULT_STATUS_MESSAGE
	_build_lots_data()


func _make_rect_centered(cx: float, cy: float, w: float, h: float) -> Rect2:
	return Rect2(cx - w * 0.5, cy - h * 0.5, w, h)


func _build_lots_data() -> void:
	_lots = {
		"igreja": {
			"id": "igreja",
			"name": "LOTE DA IGREJA — SANTUÁRIO SEGURO (BEATO)",
			"is_sanctuary": true,
			"walls": [
				_make_rect_centered(480.0, 12.0, 960.0, 24.0),
				_make_rect_centered(480.0, 528.0, 960.0, 24.0),
				_make_rect_centered(948.0, 270.0, 24.0, 540.0),
				_make_rect_centered(12.0, 105.0, 24.0, 210.0),
				_make_rect_centered(12.0, 435.0, 24.0, 210.0),
				_make_rect_centered(480.0, 120.0, 180.0, 40.0),
				_make_rect_centered(260.0, 270.0, 20.0, 260.0),
				_make_rect_centered(700.0, 270.0, 20.0, 260.0),
			],
			"gates": [],
			"bushes": [],
		},
		"0": {
			"id": "0",
			"name": "LOTE 0 — A PEDRA ANCESTRAL DA BOTIJA",
			"is_sanctuary": false,
			"walls": [
				_make_rect_centered(480.0, 12.0, 960.0, 24.0),
				_make_rect_centered(480.0, 528.0, 960.0, 24.0),
				_make_rect_centered(12.0, 270.0, 24.0, 540.0),
				_make_rect_centered(948.0, 105.0, 24.0, 210.0),
				_make_rect_centered(948.0, 435.0, 24.0, 210.0),
				_make_rect_centered(820.0, 198.0, 230.0, 24.0),
				_make_rect_centered(820.0, 342.0, 230.0, 24.0),
				_make_rect_centered(260.0, 270.0, 24.0, 260.0),
				_make_rect_centered(425.0, 388.0, 24.0, 250.0),
				_make_rect_centered(580.0, 285.0, 24.0, 240.0),
				_make_rect_centered(432.0, 152.0, 320.0, 24.0),
			],
			"gates": [
				{"rect": _make_rect_centered(260.0, 460.0, 24.0, 110.0), "is_open": true},
				{"rect": _make_rect_centered(718.0, 270.0, 24.0, 110.0), "is_open": true},
				{"rect": _make_rect_centered(580.0, 80.0, 24.0, 110.0), "is_open": false},
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
			"name": "LOTE 1a — TRILHA NORTE DA CAATINGA",
			"is_sanctuary": false,
			"walls": [
				_make_rect_centered(480.0, 12.0, 960.0, 24.0),
				_make_rect_centered(12.0, 270.0, 24.0, 540.0),
				_make_rect_centered(210.0, 528.0, 420.0, 24.0),
				_make_rect_centered(750.0, 528.0, 420.0, 24.0),
				_make_rect_centered(948.0, 105.0, 24.0, 210.0),
				_make_rect_centered(948.0, 435.0, 24.0, 210.0),
				_make_rect_centered(300.0, 340.0, 24.0, 350.0),
				_make_rect_centered(552.0, 390.0, 24.0, 250.0),
				_make_rect_centered(740.0, 269.0, 24.0, 262.0),
				_make_rect_centered(508.0, 150.0, 440.0, 24.0),
			],
			"gates": [
				{"rect": _make_rect_centered(300.0, 80.0, 24.0, 110.0), "is_open": true},
				{"rect": _make_rect_centered(552.0, 80.0, 24.0, 110.0), "is_open": false},
				{"rect": _make_rect_centered(740.0, 458.0, 24.0, 110.0), "is_open": true},
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
			"name": "LOTE 1b — PORTEIRA DA IGREJA",
			"is_sanctuary": false,
			"walls": [
				_make_rect_centered(480.0, 12.0, 960.0, 24.0),
				_make_rect_centered(12.0, 105.0, 24.0, 210.0),
				_make_rect_centered(12.0, 435.0, 24.0, 210.0),
				_make_rect_centered(948.0, 105.0, 24.0, 210.0),
				_make_rect_centered(948.0, 435.0, 24.0, 210.0),
				_make_rect_centered(210.0, 528.0, 420.0, 24.0),
				_make_rect_centered(750.0, 528.0, 420.0, 24.0),
				_make_rect_centered(270.0, 275.0, 24.0, 250.0),
				_make_rect_centered(408.0, 332.0, 24.0, 365.0),
				_make_rect_centered(780.0, 398.0, 24.0, 235.0),
				_make_rect_centered(608.0, 162.0, 370.0, 24.0),
			],
			"gates": [
				{"rect": _make_rect_centered(270.0, 458.0, 24.0, 110.0), "is_open": true},
				{"rect": _make_rect_centered(780.0, 227.0, 24.0, 100.0), "is_open": true},
				{"rect": _make_rect_centered(340.0, 388.0, 110.0, 24.0), "is_open": false},
			],
			"bushes": [
				{"id": "b_1b_fumo", "pos": Vector2(850.0, 470.0), "radius": 36.0, "type": "candeeiro", "is_searched": false},
				{"id": "b_1b_1", "pos": Vector2(80.0, 470.0), "radius": 36.0, "type": "cacto", "is_searched": false},
				{"id": "b_1b_2", "pos": Vector2(340.0, 470.0), "radius": 36.0, "type": "cacto", "is_searched": false},
				{"id": "b_1b_3", "pos": Vector2(600.0, 100.0), "radius": 36.0, "type": "normal", "is_searched": false},
			],
		},
		"2a": {
			"id": "2a",
			"name": "LOTE 2a — ENCRUZILHADA CENTRAL OESTE",
			"is_sanctuary": false,
			"walls": [
				_make_rect_centered(210.0, 12.0, 420.0, 24.0),
				_make_rect_centered(750.0, 12.0, 420.0, 24.0),
				_make_rect_centered(210.0, 528.0, 420.0, 24.0),
				_make_rect_centered(750.0, 528.0, 420.0, 24.0),
				_make_rect_centered(12.0, 105.0, 24.0, 210.0),
				_make_rect_centered(12.0, 435.0, 24.0, 210.0),
				_make_rect_centered(948.0, 105.0, 24.0, 210.0),
				_make_rect_centered(948.0, 435.0, 24.0, 210.0),
				_make_rect_centered(160.0, 270.0, 24.0, 180.0),
				_make_rect_centered(480.0, 388.0, 465.0, 24.0),
				_make_rect_centered(820.0, 270.0, 24.0, 180.0),
				_make_rect_centered(410.0, 112.0, 24.0, 170.0),
				_make_rect_centered(550.0, 112.0, 24.0, 170.0),
			],
			"gates": [
				{"rect": _make_rect_centered(480.0, 185.0, 110.0, 24.0), "is_open": true},
				{"rect": _make_rect_centered(700.0, 458.0, 24.0, 110.0), "is_open": false},
				{"rect": _make_rect_centered(260.0, 458.0, 24.0, 110.0), "is_open": true},
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
			"name": "LOTE 2b — ENCRUZILHADA CENTRAL LESTE",
			"is_sanctuary": false,
			"walls": [
				_make_rect_centered(948.0, 270.0, 24.0, 540.0),
				_make_rect_centered(210.0, 12.0, 420.0, 24.0),
				_make_rect_centered(750.0, 12.0, 420.0, 24.0),
				_make_rect_centered(210.0, 528.0, 420.0, 24.0),
				_make_rect_centered(750.0, 528.0, 420.0, 24.0),
				_make_rect_centered(12.0, 105.0, 24.0, 210.0),
				_make_rect_centered(12.0, 435.0, 24.0, 210.0),
				_make_rect_centered(408.0, 270.0, 24.0, 260.0),
				_make_rect_centered(550.0, 270.0, 24.0, 260.0),
				_make_rect_centered(760.0, 270.0, 24.0, 260.0),
				_make_rect_centered(230.0, 270.0, 24.0, 260.0),
			],
			"gates": [
				{"rect": _make_rect_centered(550.0, 82.0, 24.0, 110.0), "is_open": false},
				{"rect": _make_rect_centered(408.0, 458.0, 24.0, 110.0), "is_open": true},
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
			"name": "LOTE 3a — BOSQUE ESCURO",
			"is_sanctuary": false,
			"walls": [
				_make_rect_centered(480.0, 528.0, 960.0, 24.0),
				_make_rect_centered(12.0, 270.0, 24.0, 540.0),
				_make_rect_centered(210.0, 12.0, 420.0, 24.0),
				_make_rect_centered(750.0, 12.0, 420.0, 24.0),
				_make_rect_centered(948.0, 105.0, 24.0, 210.0),
				_make_rect_centered(948.0, 435.0, 24.0, 210.0),
				_make_rect_centered(365.0, 150.0, 400.0, 24.0),
				_make_rect_centered(152.0, 270.0, 24.0, 270.0),
				_make_rect_centered(550.0, 80.0, 24.0, 110.0),
				_make_rect_centered(495.0, 390.0, 660.0, 24.0),
				_make_rect_centered(810.0, 280.0, 24.0, 190.0),
			],
			"gates": [
				{"rect": _make_rect_centered(880.0, 198.0, 110.0, 24.0), "is_open": true},
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
			"name": "LOTE 3b — CLAREIRA DOS CIPÓS",
			"is_sanctuary": false,
			"walls": [
				_make_rect_centered(480.0, 528.0, 960.0, 24.0),
				_make_rect_centered(948.0, 270.0, 24.0, 540.0),
				_make_rect_centered(210.0, 12.0, 420.0, 24.0),
				_make_rect_centered(750.0, 12.0, 420.0, 24.0),
				_make_rect_centered(12.0, 105.0, 24.0, 210.0),
				_make_rect_centered(12.0, 435.0, 24.0, 210.0),
				_make_rect_centered(270.0, 270.0, 24.0, 270.0),
				_make_rect_centered(410.0, 270.0, 24.0, 270.0),
				_make_rect_centered(550.0, 270.0, 24.0, 270.0),
				_make_rect_centered(690.0, 270.0, 24.0, 270.0),
			],
			"gates": [
				{"rect": _make_rect_centered(480.0, 270.0, 110.0, 24.0), "is_open": true},
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

	var lot: Dictionary = _lots.get(_current_lot, {}) as Dictionary
	if lot.is_empty():
		return

	var wall_body: StaticBody2D = StaticBody2D.new()
	wall_body.name = "LotStaticWalls"
	wall_body.collision_layer = 1
	wall_body.collision_mask = 0
	_walls_root.add_child(wall_body)

	for rect: Rect2 in lot.get("walls", []) as Array:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		col.position = rect.position + rect.size * 0.5
		wall_body.add_child(col)

	var gates: Array = lot.get("gates", []) as Array
	for g_idx: int in range(gates.size()):
		var gate: Dictionary = gates[g_idx] as Dictionary
		var rect: Rect2 = gate["rect"] as Rect2
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		var col: CollisionShape2D = CollisionShape2D.new()
		col.name = "GateCollider_%d" % g_idx
		col.shape = shape
		col.position = rect.position + rect.size * 0.5
		col.disabled = bool(gate["is_open"])
		wall_body.add_child(col)
		_gate_colliders.append(col)

	var bushes: Array = lot.get("bushes", []) as Array
	for b_idx: int in range(bushes.size()):
		var bush: Dictionary = bushes[b_idx] as Dictionary
		var area: InteractableComponent = InteractableComponent.new()
		area.name = "BushInteract_%d" % b_idx
		area.position = bush["pos"] as Vector2
		area.collision_layer = 8
		area.collision_mask = 2
		area.interact_id = str(bush["id"])
		area.prompt_text = "Vasculhar [E]"
		area.interact_priority = 3

		var cshape: CircleShape2D = CircleShape2D.new()
		cshape.radius = float(bush["radius"]) + 30.0
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = cshape
		area.add_child(col)

		area.interacted.connect(_on_bush_interacted.bind(_current_lot, b_idx))
		_bushes_root.add_child(area)

	if _beato_interactable != null:
		var is_igreja: bool = _current_lot == "igreja"
		_beato_interactable.monitoring = is_igreja
		_beato_interactable.monitorable = is_igreja
		_beato_interactable.visible = is_igreja


func _sync_gate_colliders() -> void:
	var lot: Dictionary = _lots.get(_current_lot, {}) as Dictionary
	var gates: Array = lot.get("gates", []) as Array
	for idx: int in range(mini(gates.size(), _gate_colliders.size())):
		var gate: Dictionary = gates[idx] as Dictionary
		var col: CollisionShape2D = _gate_colliders[idx]
		if is_instance_valid(col):
			col.disabled = bool(gate["is_open"])


func _process(delta: float) -> void:
	_anim_time += delta
	if _hurt_cooldown > 0.0:
		_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)
	if _trip_cooldown > 0.0:
		_trip_cooldown = maxf(0.0, _trip_cooldown - delta)

	if _state_status == "FAILED":
		_fail_timer -= delta
		if _fail_timer <= 0.0:
			GameManager.switch_scene("STUDIO")
			return
		queue_redraw()
		return

	if NarrativeOverlay.is_overlay_active or DialogPanel.is_dialog_active or _state_status != "PLAYING":
		_update_darkness_shader(delta)
		queue_redraw()
		return

	var in_sanctuary: bool = _current_lot == "igreja"
	SoundManager.set_music_tension(0.1 if in_sanctuary else 0.8)

	if in_sanctuary:
		_bell_timer += delta
		if _bell_timer >= 10.0:
			_bell_timer = 0.0
			SoundManager.play_sino_badalo()

	# 1. Assobios, inversao de controles e alternancia de portoes
	_update_whistle_and_gates(delta)

	# 2. Ciclo da Cumade Fulozinha (nunca entra na Igreja)
	_update_fulo_fsm(delta, in_sanctuary)

	# 3. Transicoes entre lotes
	_check_lot_transitions()

	# 4. Escavacao e tropeco na Pedra da Botija (Lote 0)
	_update_botija_lot0(delta)

	# 5. Espinhos de cacto por proximidade
	_check_cactuses_proximity()

	# 6. Atualiza shader de escuridao e HUD
	_update_darkness_shader(delta)
	_refresh_hud()
	queue_redraw()


func _update_whistle_and_gates(delta: float) -> void:
	_whistle_timer -= delta
	if _whistle_timer <= 0.0:
		_whistle_timer = 7.0
		_whistle_duration = 4.0
		_whistle_wave_radius = 15.0
		if _player != null:
			_player.controls_inverted = true
		_status_message = "🎶 ASSOBIO NA MATA! Os portões alternaram e os controles foram invertidos!"
		SoundManager.play_cumade_assobio(1.2)
		JuiceManager.add_trauma(0.3)
		JuiceManager.emit_particles("note", Vector2(480.0, 200.0), self, {"count": 8, "speed": 45.0})

		for lot_key: Variant in _lots.keys():
			var lot_data: Dictionary = _lots[lot_key] as Dictionary
			for gate: Dictionary in lot_data["gates"] as Array:
				gate["is_open"] = not bool(gate["is_open"])
		_sync_gate_colliders()

	if _player != null and _player.controls_inverted:
		_whistle_duration -= delta
		_whistle_wave_radius += 350.0 * delta
		if _whistle_duration <= 0.0:
			_player.controls_inverted = false
			_whistle_wave_radius = 0.0
			_status_message = "🌿 O assobio cessou. Controles normais."


func _spawn_fulo_in_lot(lot_id: String) -> void:
	if lot_id == "igreja":
		_fulo_state = "SANCTUARY_WAIT"
		_fulo_timer = 0.0
		return

	var lot_data: Dictionary = _lots.get(lot_id, {}) as Dictionary
	var walls: Array = lot_data.get("walls", []) as Array
	var best_pos: Vector2 = Vector2(480.0, 270.0)
	var half_size: Vector2 = FULO_SIZE * 0.5
	var player_pos: Vector2 = _player.global_position if _player != null else Vector2(480.0, 360.0)

	for _attempt: int in range(30):
		var cand: Vector2 = Vector2(80.0 + randf() * 800.0, 80.0 + randf() * 420.0)
		if cand.distance_to(player_pos) < 140.0:
			continue
		var cand_rect: Rect2 = Rect2(cand - half_size, FULO_SIZE)
		var collides: bool = false
		for w: Rect2 in walls:
			if cand_rect.intersects(w):
				collides = true
				break
		if not collides:
			best_pos = cand
			break

	_fulozinha_pos = best_pos
	_fulo_state = "PURSUIT"
	_fulo_timer = FULO_PURSUIT_DURATION
	SoundManager.play_cumade_assobio(1.3)
	JuiceManager.add_trauma(0.25)
	JuiceManager.emit_particles("leaf", _fulozinha_pos, self, {"count": 16, "speed": 60.0})


func _is_fulo_blocked(pos: Vector2, lot_data: Dictionary) -> bool:
	var half_size: Vector2 = FULO_SIZE * 0.5
	var fulo_rect: Rect2 = Rect2(pos - half_size, FULO_SIZE)
	for w: Rect2 in lot_data.get("walls", []) as Array:
		if fulo_rect.intersects(w):
			return true
	for g: Dictionary in lot_data.get("gates", []) as Array:
		if not bool(g["is_open"]):
			var g_rect: Rect2 = g["rect"] as Rect2
			if fulo_rect.intersects(g_rect):
				return true
	return false


func _move_fulo_with_collision(angle: float, speed: float, delta: float, clamp_bounds: bool) -> void:
	var lot_data: Dictionary = _lots.get(_current_lot, {}) as Dictionary
	var target_x: float = _fulozinha_pos.x + cos(angle) * speed * delta
	if not _is_fulo_blocked(Vector2(target_x, _fulozinha_pos.y), lot_data):
		_fulozinha_pos.x = clampf(target_x, 40.0, 920.0) if clamp_bounds else target_x

	var target_y: float = _fulozinha_pos.y + sin(angle) * speed * delta
	if not _is_fulo_blocked(Vector2(_fulozinha_pos.x, target_y), lot_data):
		_fulozinha_pos.y = clampf(target_y, 40.0, 500.0) if clamp_bounds else target_y


func _update_fulo_fsm(delta: float, in_sanctuary: bool) -> void:
	if in_sanctuary:
		_fulo_state = "SANCTUARY_WAIT"
		_fulo_timer = 0.0
		return

	if _player == null:
		return

	match _fulo_state:
		"SANCTUARY_WAIT":
			_spawn_fulo_in_lot(_current_lot)
		"PURSUIT":
			_fulo_timer -= delta
			var dir_vec: Vector2 = _player.global_position - _fulozinha_pos
			var angle: float = dir_vec.angle() if dir_vec.length_squared() > 0.001 else 0.0
			_move_fulo_with_collision(angle, FULO_SPEED, delta, false)

			var dist_hero: float = _player.global_position.distance_to(_fulozinha_pos)
			if dist_hero < 34.0 and _hurt_cooldown <= 0.0 and _player.health != null and not _player.health.is_invulnerable():
				_hurt_cooldown = 1.5
				_player.health.invulnerability_duration = 5.0
				_player.health.take_damage(1)
				_fulo_state = "FLEE"
				_fulo_timer = FULO_FLEE_DURATION
				_status_message = "🌿 A Cumade Fulozinha amarrou seus cadarços! (-1 HP)"
				SoundManager.play_chicote()
				SoundManager.play_grito()
				JuiceManager.add_trauma(0.5)
				JuiceManager.emit_particles("dust", _player.global_position, self, {"count": 12, "speed": 50.0})

				if _player.health.is_dead():
					_trigger_failure("💀 VOCÊ NÃO RESISTIU AOS ATAQUES DA CUMADE FULOZINHA!", 1.8)
					return

			if _fulo_timer <= 0.0:
				_fulo_state = "VANISHED"
				_fulo_timer = FULO_VANISH_DURATION
				SoundManager.play_ui_click()
				JuiceManager.emit_particles("leaf", _fulozinha_pos, self, {"count": 18, "speed": 50.0})
		"FLEE":
			_fulo_timer -= delta
			var dir_vec: Vector2 = _fulozinha_pos - _player.global_position
			var angle: float = dir_vec.angle() if dir_vec.length_squared() > 0.001 else 0.0
			_move_fulo_with_collision(angle, FULO_SPEED * 1.1, delta, true)

			if _fulo_timer <= 0.0:
				_fulo_state = "PURSUIT"
				_fulo_timer = FULO_PURSUIT_DURATION
				JuiceManager.emit_particles("dust", _fulozinha_pos, self, {"count": 8, "speed": 40.0})
		"VANISHED":
			_fulo_timer -= delta
			if _fulo_timer <= 0.0:
				_spawn_fulo_in_lot(_current_lot)


func _on_player_shouted(world_pos: Vector2) -> void:
	if _state_status != "PLAYING" or _current_lot == "igreja":
		return
	if _fulo_state == "PURSUIT" and world_pos.distance_to(_fulozinha_pos) <= 160.0:
		_fulo_state = "FLEE"
		_fulo_timer = FULO_FLEE_DURATION
		_status_message = "🗣️ SEU GRITO ASSUSTOU A CUMADE FULOZINHA! Ela fugiu na escuridão!"


func _check_lot_transitions() -> void:
	if _player == null:
		return

	var pos: Vector2 = _player.global_position
	var prev_lot: String = _current_lot
	var changed: bool = false

	if pos.x > 936.0:
		match _current_lot:
			"1b":
				_current_lot = "igreja"
				pos.x = 40.0
				changed = true
				SoundManager.play_sino_badalo()
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
			"igreja":
				_current_lot = "1b"
				pos.x = 920.0
				changed = true
				SoundManager.play_sino_badalo()
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
	elif pos.y < 24.0:
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

	if changed and _current_lot != prev_lot:
		_is_digging = false
		_rebuild_lot_geometry()
		if _current_lot == "igreja":
			_fulo_state = "SANCTUARY_WAIT"
			_fulo_timer = 0.0
		else:
			_spawn_fulo_in_lot(_current_lot)


func _update_botija_lot0(delta: float) -> void:
	if _current_lot != "0" or _has_botija or _player == null:
		_is_digging = false
		return

	var dist_pedra: float = _player.global_position.distance_to(PEDRA_POS)

	if dist_pedra < 26.0 and _hurt_cooldown <= 0.0 and _trip_cooldown <= 0.0 and _player.health != null and not _player.health.is_invulnerable():
		_hurt_cooldown = 2.0
		_trip_cooldown = 2.0
		_player.health.invulnerability_duration = 3.0
		_player.health.take_damage(1)
		var trip_phrases: PackedStringArray = PackedStringArray([
			"🗣️ \"Coisinha, tropeçou!\"",
			"🗣️ \"Coisinha vai arrancar um dedo!\"",
			"🗣️ \"Coisinha tá adivinhando butija!\"",
		])
		_status_message = trip_phrases[randi() % trip_phrases.size()]
		SoundManager.play_ui_click()
		SoundManager.play_grito()
		JuiceManager.add_trauma(0.4)
		JuiceManager.emit_particles("dust", _player.global_position + Vector2(0.0, 18.0), self, {"count": 8, "speed": 40.0})

		if _player.health.is_dead():
			_trigger_failure("💀 VOCÊ NÃO RESISTIU AOS ESPINHOS E TROPEÇOS DA CAATINGA!", 1.8)
			return

	if dist_pedra < 55.0:
		if Input.is_action_pressed("interact"):
			_is_digging = true
			_dig_progress += delta * 0.45
			_status_message = "⛏️ Desenterrando a botija de ouro... %d%%" % roundi(_dig_progress * 100.0)

			_dig_sound_timer += delta
			if _dig_sound_timer >= 0.28:
				_dig_sound_timer = 0.0
				SoundManager.play_escavacao()
				JuiceManager.emit_particles("dust", PEDRA_POS, self, {"count": 4, "speed": 30.0})

			if _dig_progress >= 1.0:
				_dig_progress = 1.0
				_is_digging = false
				_has_botija = true
				_player.move_speed = PLAYER_BOTIJA_SPEED
				_status_message = "🏺 BOTIJA DESENTERRADA! É muito pesada (-25% Vel). Fuja para a Igreja!"
				SoundManager.play_pickup()
				SoundManager.play_item_descobrir()
				JuiceManager.add_trauma(0.4)
				JuiceManager.emit_particles("sparkle", PEDRA_POS, self, {"count": 20, "speed": 60.0})
				DialogPanel.start_dialog(
					"item_botija",
					"Botija de Mané Monteiro",
					"🏺",
					[
						{
							"speaker": "Coisinha",
							"avatar_icon": "🏺",
							"text": "🏺 \"Desenterrei a famosa Botija de Ouro de Mané Monteiro! O pote é pesado, preciso correr para a Igreja antes que a Cumade me pegue!\"",
						},
					],
					Callable(),
					true
				)
		else:
			_is_digging = false
	else:
		_is_digging = false


func _check_cactuses_proximity() -> void:
	if _player == null or _player.health == null:
		return
	if _hurt_cooldown > 0.0 or _player.health.is_invulnerable():
		return

	var lot: Dictionary = _lots.get(_current_lot, {}) as Dictionary
	for bush: Dictionary in lot.get("bushes", []) as Array:
		if str(bush["type"]) != "cacto":
			continue
		var dist: float = _player.global_position.distance_to(bush["pos"] as Vector2)
		if dist < float(bush["radius"]) + 12.0:
			bush["is_searched"] = true
			_hurt_cooldown = 1.2
			_player.health.invulnerability_duration = 3.0
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
	var lot: Dictionary = _lots.get(_current_lot, {}) as Dictionary
	var bushes: Array = lot.get("bushes", []) as Array
	if bush_idx < 0 or bush_idx >= bushes.size():
		return
	var bush: Dictionary = bushes[bush_idx] as Dictionary
	if bool(bush["is_searched"]):
		return

	bush["is_searched"] = true
	var btype: String = str(bush["type"])
	var bpos: Vector2 = bush["pos"] as Vector2

	if btype == "candeeiro" and not _has_lantern:
		_has_lantern = true
		GameManager.unlock_bush_item("candeeiro")
		_status_message = "🏮 CANDEEIRO ENCONTRADO! Iluminação expandida na caatinga!"
		SoundManager.play_pickup()
		JuiceManager.emit_particles("sparkle", bpos, self, {"count": 10, "speed": 50.0})
		DialogPanel.start_dialog(
			"item_candeeiro",
			"Candeeiro Místico",
			"🏮",
			[
				{
					"speaker": "Coisinha",
					"avatar_icon": "🏮",
					"text": "🏮 \"Achei o candeeiro! Agora o círculo de luz clareia a escuridão da fazenda para encontrar a pedra!\"",
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
			_player.health.invulnerability_duration = 3.0
			_player.health.take_damage(1)
			SoundManager.play_hurt_cacto()
			SoundManager.play_grito()
			JuiceManager.add_trauma(0.45)
			_status_message = "🌵 AI! ESPINHO DE CACTO! Você perdeu 1 HP e soltou um grito!"
			if _player.health.is_dead():
				_trigger_failure("💀 VOCÊ NÃO RESISTIU AOS ESPINHOS DA CAATINGA!", 2.5)
	else:
		JuiceManager.emit_particles("leaf", bpos, self, {"count": 8, "speed": 35.0})


func _on_beato_interacted(_actor: Node) -> void:
	if _state_status != "PLAYING" or _current_lot != "igreja":
		return

	if not _has_botija:
		DialogPanel.start_dialog(
			"beato",
			"Beato Frei Damião",
			"📿",
			[
				{
					"speaker": "Beato",
					"avatar_icon": "📿",
					"text": "Então, Coisinha! A Cumade Fulô guarda a fazenda, mas aqui dentro ela não tem poder.",
				},
				{
					"speaker": "Beato",
					"avatar_icon": "📿",
					"text": "Vá até o Lote 0, desenterre a Botija de ouro sob a pedra ancestral e traga para consagração no altar!",
				},
			],
			Callable(),
			true
		)
	else:
		_state_status = "SUCCESS"
		if _player != null:
			_player.controls_inverted = false
			_player.move_speed = PLAYER_BASE_SPEED
		GameManager.unlock_item("tinta")
		SoundManager.play_sino_badalo()
		SoundManager.play_victory_jingle()
		JuiceManager.emit_particles("sparkle", BEATO_POS, self, {"count": 35, "speed": 70.0})

		NarrativeOverlay.show_outro(
			{
				"phase_number": 4,
				"title": "A Botija de Mané Monteiro",
				"verses": PackedStringArray([
					"O ouro ancestral foi depositado com fé no altar,",
					"E das mãos do bom Beato a bênção veio brilhar;",
					"Com os quatro elementos reunidos com louvor e glória:",
					"A Tinta Encantada fecha o ciclo da vitória!",
				]),
				"item_reward": {
					"id": "tinta",
					"name": "Tinta Encantada",
					"icon": "🖋️",
				},
			},
			func() -> void:
				GameManager.switch_scene("STUDIO")
		)


func _update_darkness_shader(delta: float) -> void:
	if _darkness_rect == null:
		return

	var in_sanctuary: bool = _current_lot == "igreja"
	_darkness_rect.visible = not in_sanctuary
	if in_sanctuary:
		return

	var target_blend: float = 1.0 if _has_lantern else 0.0
	_lantern_blend = move_toward(_lantern_blend, target_blend, delta * 3.0)

	var mat: ShaderMaterial = _darkness_rect.material as ShaderMaterial
	if mat != null and _player != null:
		mat.set_shader_parameter("light_center_px", _player.global_position)
		mat.set_shader_parameter("lantern_active", _has_lantern)
		mat.set_shader_parameter("lantern_blend", _lantern_blend)


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
	var lot_name: String = str(lot.get("name", "IGREJA"))
	if _title_label != null:
		_title_label.text = "🏺 FASE 4: %s" % lot_name

	if _hp_label != null and _player != null and _player.health != null:
		var hearts: String = ""
		for h: int in range(_player.health.max_hp):
			if h > 0:
				hearts += " "
			hearts += "❤️" if h < _player.health.current_hp else "🖤"
		_hp_label.text = hearts

	if _item_label != null:
		if _has_botija:
			_item_label.text = "🏺 Botija (-25% Vel)"
			_item_label.add_theme_color_override("font_color", Color("#facc15"))
		elif _has_lantern:
			_item_label.text = "🏮 Candeeiro (320px)"
			_item_label.add_theme_color_override("font_color", Color("#fef08a"))
		else:
			_item_label.text = "🏮 Sem Candeeiro | 🏺 Sem Botija"
			_item_label.add_theme_color_override("font_color", Color("#94a3b8"))

	if _status_label != null:
		_status_label.text = _status_message


func _draw() -> void:
	var lot: Dictionary = _lots.get(_current_lot, {}) as Dictionary
	var is_sanctuary: bool = bool(lot.get("is_sanctuary", false))
	var font: Font = ThemeDB.fallback_font

	# 1. Fundo
	if is_sanctuary:
		draw_rect(Rect2(0.0, 0.0, VIEWPORT_WIDTH, PLAYFIELD_HEIGHT), Color("#1e1b18"))
		XiloDraw.draw_moldura_cordel(self, Rect2(8.0, 8.0, VIEWPORT_WIDTH - 16.0, PLAYFIELD_HEIGHT - 16.0), 3.0)

		# Luz divina / velas
		draw_circle(Vector2(480.0, 180.0), 220.0, Color(0.996, 0.941, 0.541, 0.14))
		draw_circle(Vector2(480.0, 180.0), 110.0, Color(0.996, 0.941, 0.541, 0.22))

		# Altar
		XiloDraw.draw_rect_xilo(self, ALTAR_RECT, Color("#78350f"), Color("#facc15"), 2.0)
		if font != null:
			draw_string(font, Vector2(400.0, 124.0), "✝ [ALTAR SAGRADO]", HORIZONTAL_ALIGNMENT_CENTER, 160.0, 11, Color("#fef08a"))
			draw_string(font, Vector2(0.0, 65.0), "🕊️ SANTUÁRIO SEGURO — A CUMADE FULÔ NÃO ENTRA AQUI!", HORIZONTAL_ALIGNMENT_CENTER, VIEWPORT_WIDTH, 12, Color("#86efac"))

		# Beato
		XiloDraw.draw_beato(self, BEATO_POS, BEATO_SIZE)
	else:
		XiloDraw.draw_chao_terra_batida(self, Rect2(0.0, 0.0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT))
		XiloDraw.draw_moldura_cordel(self, Rect2(8.0, 8.0, VIEWPORT_WIDTH - 16.0, VIEWPORT_HEIGHT - 16.0), 3.0)

	# 2. Paredes do Lote
	var wall_fill: Color = Color("#78350f") if is_sanctuary else Color("#1e293b")
	var wall_stroke: Color = Color("#b45309") if is_sanctuary else Color("#334155")
	for rect: Rect2 in lot.get("walls", []) as Array:
		XiloDraw.draw_rect_xilo(self, rect, wall_fill, wall_stroke, 1.5)

	# 3. Portoes Internos Dinamicos
	for gate: Dictionary in lot.get("gates", []) as Array:
		var rect: Rect2 = gate["rect"] as Rect2
		var is_open: bool = bool(gate["is_open"])
		var fill_col: Color = Color("#16a34a") if is_open else Color("#dc2626")
		XiloDraw.draw_rect_xilo(self, rect, fill_col, Color.WHITE, 1.5)

	# 4. Moitas do Lote
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
				_:
					XiloDraw.draw_moita(self, bpos, bradius, true)
		else:
			XiloDraw.draw_moita(self, bpos, bradius, false)

	# 5. Pedra da Botija (Lote 0)
	if _current_lot == "0" and not _has_botija:
		XiloDraw.draw_item_botija(self, PEDRA_POS, 36.0)
		if _is_digging:
			var bar_rect: Rect2 = Rect2(PEDRA_POS.x - 40.0, PEDRA_POS.y - 28.0, 80.0, 8.0)
			draw_rect(bar_rect, Color("#1e293b"))
			draw_rect(Rect2(bar_rect.position.x, bar_rect.position.y, 80.0 * clampf(_dig_progress, 0.0, 1.0), 8.0), Color("#eab308"))
			draw_rect(bar_rect, Color.WHITE, false, 1.5)

	# 6. Fulo Furiosa (fora da Igreja quando em PURSUIT ou FLEE)
	if not is_sanctuary and (_fulo_state == "PURSUIT" or _fulo_state == "FLEE"):
		var ring_col: Color = Color(0.918, 0.702, 0.031, 0.5) if _fulo_state == "FLEE" else Color(0.937, 0.267, 0.267, 0.5)
		var fill_aura: Color = Color(0.918, 0.702, 0.031, 0.12) if _fulo_state == "FLEE" else Color(0.937, 0.267, 0.267, 0.12)
		draw_circle(_fulozinha_pos, 80.0, fill_aura)
		draw_arc(_fulozinha_pos, 80.0, 0.0, TAU, 36, ring_col, 2.0, true)
		XiloDraw.draw_cumade_fulozinha(self, _fulozinha_pos, FULO_SIZE, {"time": _anim_time})
	elif not is_sanctuary and _fulo_state == "VANISHED":
		var vanish_alpha: float = clampf(_fulo_timer / 1.5, 0.15, 0.65)
		draw_arc(_fulozinha_pos, 45.0, 0.0, TAU, 28, Color(0.133, 0.545, 0.133, vanish_alpha), 2.0, true)

	# 7. Indicador de Botija ou Candeeiro junto ao jogador
	if _player != null:
		if _has_botija:
			XiloDraw.draw_item_botija(self, _player.global_position + Vector2(18.0, -10.0), 20.0)
			if font != null:
				draw_string(font, _player.global_position + Vector2(-75.0, -32.0), "🏺 BOTIJA PESADA (-25% Vel)", HORIZONTAL_ALIGNMENT_CENTER, 150.0, 10, Color("#facc15"))
		elif _has_lantern and font != null:
			draw_string(font, _player.global_position + Vector2(-50.0, -32.0), "🏮 CANDEEIRO", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 10, Color("#fef08a"))

	# 8. Efeito visual de Assobio e Controles Invertidos
	if _player != null and _player.controls_inverted:
		draw_rect(Rect2(0.0, 0.0, VIEWPORT_WIDTH, PLAYFIELD_HEIGHT), Color(0.863, 0.149, 0.149, 0.15))
		if _whistle_wave_radius > 0.0:
			draw_arc(_fulozinha_pos, _whistle_wave_radius, 0.0, TAU, 48, Color(0.97, 0.44, 0.44, 0.45), 2.0, true)
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
