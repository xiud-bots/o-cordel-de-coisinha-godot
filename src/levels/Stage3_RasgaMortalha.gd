class_name Stage3_RasgaMortalha
extends Node2D

const VIEWPORT_WIDTH: float = 960.0
const VIEWPORT_HEIGHT: float = 580.0

const STAGE_DURATION_SECONDS: float = 300.0
const OWL_CRY_INTERVAL_SECONDS: float = 30.0
const DOOR_COOLDOWN_SECONDS: float = 0.6

const OWL_Y: float = 40.0
const OWL_SPEED: float = 130.0
const OWL_MIN_X: float = 80.0
const OWL_MAX_X: float = 880.0

const VIOLEIRO_1_POS: Vector2 = Vector2(440.0, 260.0)
const VIOLEIRO_2_POS: Vector2 = Vector2(520.0, 260.0)
const VIOLEIRO_1_INTERACT_POS: Vector2 = Vector2(450.0, 280.0)
const VIOLEIRO_2_INTERACT_POS: Vector2 = Vector2(510.0, 280.0)
const VIOLEIRO_INTERACT_RADIUS: float = 65.0

const HOUSE_DOOR_OFFSET_Y: float = 40.0
const HOUSE_DOOR_RADIUS: float = 45.0
const ITEM_PICKUP_RADIUS: float = 45.0
const INTERIOR_PICKUP_RADIUS: float = 60.0

var _current_interior_house_idx: int = -1
var _owl_pos: Vector2 = Vector2(480.0, OWL_Y)
var _owl_direction: float = 1.0

var _anim_time: float = 0.0
var _door_cooldown: float = 0.0
var _stage_timer: float = STAGE_DURATION_SECONDS
var _owl_sound_timer: float = 0.0
var _state_status: String = "PLAYING" # PLAYING | SUCCESS | FAILED

var _houses: Array[Dictionary] = []
var _all_items: Array[Dictionary] = []
var _carried_item: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _player: Coisinha = $Coisinha
@onready var _title_label: Label = $HUDLayer/TopBar/TitleLabel
@onready var _timer_panel: PanelContainer = $HUDLayer/TimerPanel
@onready var _timer_label: Label = $HUDLayer/TimerPanel/TimerLabel
@onready var _status_label: Label = $HUDLayer/StatusBar/StatusLabel


func _ready() -> void:
	_rng.randomize()
	GameManager.current_scene_id = "STAGE_3_RASGAMORTALHA"
	SoundManager.play_music("STAGE3_RASGAMORTALHA")
	SoundManager.set_music_tension(0.2)

	_reset_stage_data()

	if _player != null:
		_player.global_position = Vector2(480.0, 380.0)
		_player.move_speed = 230.0
		_player.facing = "down"
		_player.controls_inverted = false
		_player.shouted.connect(_on_player_shouted)

	_refresh_hud()

	NarrativeOverlay.show_intro({
		"phase_number": 3,
		"title": "A Pena da Rasga-Mortalha",
		"subtitle": "O enigma das 5 casas, os cantadores e a dedução sertaneja",
		"verses": PackedStringArray([
			"Na vila da meia-noite onde a coruja esvoaça,",
			"Cinco casas em fileira guardam glória e trapaça;",
			"Escute os dois violeiros no repente afinado,",
			"Entre nas casas e traga a cada morador seu fumo, bicho e trago sagrado!",
		]),
		"objective": "Pegue itens com [E], entre nas casas e solte-os no interior para resolver o enigma!",
		"item_reward": {
			"id": "pena",
			"name": "Pena Encantada",
			"icon": "🪶",
		},
	})
	queue_redraw()


func _reset_stage_data() -> void:
	_current_interior_house_idx = -1
	_owl_pos = Vector2(480.0, OWL_Y)
	_owl_direction = 1.0
	_anim_time = 0.0
	_door_cooldown = 0.0
	_stage_timer = STAGE_DURATION_SECONDS
	_owl_sound_timer = 0.0
	_state_status = "PLAYING"
	_carried_item = {}

	var arc_positions: Array[Vector2] = [
		Vector2(130.0, 155.0),
		Vector2(305.0, 125.0),
		Vector2(480.0, 110.0),
		Vector2(655.0, 125.0),
		Vector2(830.0, 155.0),
	]

	_houses = [
		{"index": 1, "cor_name": "Amarela", "color_hex": "#eab308", "pos": arc_positions[0], "size": Vector2(140.0, 110.0), "morador": "", "bebida": "", "fumo": "", "animal": ""},
		{"index": 2, "cor_name": "Azul", "color_hex": "#2563eb", "pos": arc_positions[1], "size": Vector2(140.0, 110.0), "morador": "", "bebida": "", "fumo": "", "animal": ""},
		{"index": 3, "cor_name": "Vermelha", "color_hex": "#dc2626", "pos": arc_positions[2], "size": Vector2(140.0, 110.0), "morador": "", "bebida": "", "fumo": "", "animal": ""},
		{"index": 4, "cor_name": "Verde", "color_hex": "#16a34a", "pos": arc_positions[3], "size": Vector2(140.0, 110.0), "morador": "", "bebida": "", "fumo": "", "animal": ""},
		{"index": 5, "cor_name": "Branca", "color_hex": "#f8fafc", "pos": arc_positions[4], "size": Vector2(140.0, 110.0), "morador": "", "bebida": "", "fumo": "", "animal": ""},
	]

	_all_items = [
		# 5 Moradores (Bodega dos Moradores)
		{"id": "v_vaqueiro", "type": "morador", "name": "Vaqueiro", "icon": "🤠", "color": "#eab308", "pos": Vector2(55.0, 425.0), "origin": Vector2(55.0, 425.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "v_rendeira", "type": "morador", "name": "Rendeira", "icon": "👒", "color": "#38bdf8", "pos": Vector2(95.0, 435.0), "origin": Vector2(95.0, 435.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "v_cantador", "type": "morador", "name": "Cantador", "icon": "🪕", "color": "#f87171", "pos": Vector2(135.0, 445.0), "origin": Vector2(135.0, 445.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "v_ferrador", "type": "morador", "name": "Ferrador", "icon": "🔨", "color": "#4ade80", "pos": Vector2(175.0, 435.0), "origin": Vector2(175.0, 435.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "v_rezadeira", "type": "morador", "name": "Rezadeira", "icon": "📿", "color": "#f1f5f9", "pos": Vector2(215.0, 425.0), "origin": Vector2(215.0, 425.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},

		# 5 Bebidas (Bebidas & Cafe)
		{"id": "b_agua", "type": "bebida", "name": "Água", "icon": "💧", "color": "#38bdf8", "pos": Vector2(295.0, 450.0), "origin": Vector2(295.0, 450.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "b_garapa", "type": "bebida", "name": "Garapa", "icon": "🍯", "color": "#facc15", "pos": Vector2(330.0, 460.0), "origin": Vector2(330.0, 460.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "b_cachaca", "type": "bebida", "name": "Cachaça", "icon": "🍶", "color": "#f87171", "pos": Vector2(365.0, 470.0), "origin": Vector2(365.0, 470.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "b_umbu", "type": "bebida", "name": "Umbu", "icon": "🍈", "color": "#4ade80", "pos": Vector2(400.0, 460.0), "origin": Vector2(400.0, 460.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "b_cafe", "type": "bebida", "name": "Café", "icon": "☕", "color": "#78350f", "pos": Vector2(435.0, 450.0), "origin": Vector2(435.0, 450.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},

		# 5 Fumos (Fumos Regionais)
		{"id": "f_paieiro", "type": "fumo", "name": "Paieiro", "icon": "🍂", "color": "#d97706", "pos": Vector2(525.0, 450.0), "origin": Vector2(525.0, 450.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "f_palha", "type": "fumo", "name": "Palha", "icon": "🌾", "color": "#eab308", "pos": Vector2(560.0, 460.0), "origin": Vector2(560.0, 460.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "f_desfiado", "type": "fumo", "name": "Desfiado", "icon": "🍁", "color": "#dc2626", "pos": Vector2(595.0, 470.0), "origin": Vector2(595.0, 470.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "f_arapiraca", "type": "fumo", "name": "Arapiraca", "icon": "🌿", "color": "#16a34a", "pos": Vector2(630.0, 460.0), "origin": Vector2(630.0, 460.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "f_trevo", "type": "fumo", "name": "Trevo", "icon": "🍀", "color": "#22c55e", "pos": Vector2(665.0, 450.0), "origin": Vector2(665.0, 450.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},

		# 5 Animais (Curral de Animais)
		{"id": "a_bode", "type": "animal", "name": "Bode", "icon": "🐐", "color": "#cbd5e1", "pos": Vector2(745.0, 425.0), "origin": Vector2(745.0, 425.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "a_galo", "type": "animal", "name": "Galo", "icon": "🐓", "color": "#ef4444", "pos": Vector2(785.0, 435.0), "origin": Vector2(785.0, 435.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "a_tatu", "type": "animal", "name": "Tatu", "icon": "🦔", "color": "#a16207", "pos": Vector2(825.0, 445.0), "origin": Vector2(825.0, 445.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "a_cavalo", "type": "animal", "name": "Cavalo", "icon": "🐎", "color": "#92400e", "pos": Vector2(865.0, 435.0), "origin": Vector2(865.0, 435.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
		{"id": "a_canario", "type": "animal", "name": "Canário", "icon": "🐤", "color": "#facc15", "pos": Vector2(905.0, 425.0), "origin": Vector2(905.0, 425.0), "assigned_house_idx": -1, "interior_pos": Vector2.ZERO},
	]


func _process(delta: float) -> void:
	_anim_time += delta

	if _door_cooldown > 0.0:
		_door_cooldown = maxf(0.0, _door_cooldown - delta)

	if NarrativeOverlay.is_overlay_active or DialogPanel.is_dialog_active:
		queue_redraw()
		return

	if _state_status != "PLAYING":
		queue_redraw()
		return

	# 0. Timer da Fase (300s) e Grito da Rasga-Mortalha a cada 30s
	_stage_timer -= delta
	_owl_sound_timer += delta

	if _owl_sound_timer >= OWL_CRY_INTERVAL_SECONDS:
		_owl_sound_timer = 0.0
		SoundManager.play_rasga_canto()
		JuiceManager.add_trauma(0.2)

	if _stage_timer <= 60.0:
		SoundManager.set_music_tension(0.65)

	if _stage_timer <= 0.0:
		_trigger_timeout_failure()
		return

	# 1. Voo da Coruja Rasga-Mortalha (apenas na praca exterior)
	if _current_interior_house_idx == -1:
		_owl_pos.x += _owl_direction * OWL_SPEED * delta
		if _owl_pos.x > OWL_MAX_X:
			_owl_pos.x = OWL_MAX_X
			_owl_direction = -1.0
		elif _owl_pos.x < OWL_MIN_X:
			_owl_pos.x = OWL_MIN_X
			_owl_direction = 1.0

	# 2. Limites de tela e transicao de portas
	if _player != null:
		if _current_interior_house_idx != -1:
			_player.global_position = Vector2(
				clampf(_player.global_position.x, 90.0, 870.0),
				clampf(_player.global_position.y, 90.0, 490.0)
			)

			# Saida pela porta inferior da casa
			if _door_cooldown <= 0.0 and _player.global_position.y >= 475.0 and _player.global_position.x > 420.0 and _player.global_position.x < 540.0:
				var exit_house: Dictionary = _get_house(_current_interior_house_idx)
				_current_interior_house_idx = -1
				_door_cooldown = DOOR_COOLDOWN_SECONDS
				if not exit_house.is_empty():
					var h_pos: Vector2 = exit_house["pos"] as Vector2
					_player.global_position = Vector2(h_pos.x, h_pos.y + 110.0)
				else:
					_player.global_position = Vector2(480.0, 270.0)
				DialogPanel.post_message("🚪 Você saiu para a praça da vila.")
				SoundManager.play_ui_click()
		else:
			_player.global_position = Vector2(
				clampf(_player.global_position.x, 30.0, 930.0),
				clampf(_player.global_position.y, 30.0, 510.0)
			)

			if _door_cooldown <= 0.0:
				for h: Dictionary in _houses:
					var h_pos: Vector2 = h["pos"] as Vector2
					var door_pos: Vector2 = Vector2(h_pos.x, h_pos.y + HOUSE_DOOR_OFFSET_Y)
					if _player.global_position.distance_to(door_pos) < HOUSE_DOOR_RADIUS:
						var house_idx: int = int(h["index"])
						var cor_name: String = str(h["cor_name"])
						_current_interior_house_idx = house_idx
						_door_cooldown = DOOR_COOLDOWN_SECONDS
						_player.global_position = Vector2(480.0, 400.0)
						DialogPanel.post_message(
							"🏠 Entrou na Casa %d (%s). Solte itens com [E] ou Grite [Espaço] para resetar!" % [house_idx, cor_name]
						)
						SoundManager.play_ui_click()
						break

	_refresh_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _state_status != "PLAYING":
		return
	if NarrativeOverlay.is_overlay_active or DialogPanel.is_dialog_active or DialogPanel.dialog_cooldown > 0.0:
		return
	if _player == null:
		return

	if event.is_action_released("interact"):
		get_viewport().set_input_as_handled()
		if _current_interior_house_idx != -1:
			_handle_interior_interact()
		else:
			_handle_exterior_interact()


func _on_player_shouted(_world_pos: Vector2) -> void:
	if _state_status != "PLAYING":
		return
	if NarrativeOverlay.is_overlay_active or DialogPanel.is_dialog_active:
		return

	if _current_interior_house_idx != -1:
		var house: Dictionary = _get_house(_current_interior_house_idx)
		if house.is_empty():
			return

		JuiceManager.add_trauma(0.4)
		var house_idx: int = int(house["index"])
		var reset_count: int = 0
		for it: Dictionary in _all_items:
			if int(it["assigned_house_idx"]) == house_idx:
				it["assigned_house_idx"] = -1
				it["pos"] = it["origin"]
				it["interior_pos"] = Vector2.ZERO
				reset_count += 1

		house["morador"] = ""
		house["bebida"] = ""
		house["fumo"] = ""
		house["animal"] = ""

		if reset_count > 0:
			DialogPanel.post_message(
				"🗣️ GRITO NA CASA! Os %d elementos se assustaram e voltaram para as mesas!" % reset_count,
				{"is_success": true}
			)
			SoundManager.play_item_descobrir()
			JuiceManager.emit_particles("dust", Vector2(480.0, 270.0), self, {"count": 18, "speed": 60.0})
		else:
			DialogPanel.post_message("🗣️ Coisinha soltou um grito no interior da Casa %d!" % house_idx)
	else:
		JuiceManager.add_trauma(0.35)


func _handle_interior_interact() -> void:
	var house: Dictionary = _get_house(_current_interior_house_idx)
	if house.is_empty():
		return
	var house_idx: int = int(house["index"])
	var cor_name: String = str(house["cor_name"])

	if not _carried_item.is_empty():
		var item_type: String = str(_carried_item["type"])
		var item_name: String = str(_carried_item["name"])

		# Se ja houver outro item do mesmo tipo nesta casa, devolve-o a mesa para manter consistencia
		for other: Dictionary in _all_items:
			if int(other["assigned_house_idx"]) == house_idx and str(other["type"]) == item_type and str(other["id"]) != str(_carried_item["id"]):
				other["assigned_house_idx"] = -1
				other["pos"] = other["origin"]
				other["interior_pos"] = Vector2.ZERO

		_carried_item["assigned_house_idx"] = house_idx
		_carried_item["interior_pos"] = Vector2(
			300.0 + _rng.randf() * 360.0,
			220.0 + _rng.randf() * 160.0
		)
		house[item_type] = item_name

		DialogPanel.post_message("📦 %s foi colocado no chão da Casa %d (%s)!" % [item_name, house_idx, cor_name])
		SoundManager.play_pickup()
		JuiceManager.emit_particles("sparkle", _player.global_position, self, {"count": 10, "speed": 45.0})
		_carried_item = {}
		_check_victory()
		return

	# Recapturar item do interior da casa
	for it: Dictionary in _all_items:
		if int(it["assigned_house_idx"]) == house_idx:
			var i_pos: Vector2 = it["interior_pos"] as Vector2
			if i_pos != Vector2.ZERO and _player.global_position.distance_to(i_pos) < INTERIOR_PICKUP_RADIUS:
				it["assigned_house_idx"] = -1
				it["interior_pos"] = Vector2.ZERO
				var it_type: String = str(it["type"])
				house[it_type] = ""
				_carried_item = it
				DialogPanel.post_message("✋ Você recapturou %s do interior da Casa %d!" % [str(it["name"]), house_idx])
				SoundManager.play_pickup()
				JuiceManager.emit_particles("sparkle", _player.global_position, self, {"count": 8, "speed": 35.0})
				return


func _handle_exterior_interact() -> void:
	var dist_v1: float = _player.global_position.distance_to(VIOLEIRO_1_INTERACT_POS)
	var dist_v2: float = _player.global_position.distance_to(VIOLEIRO_2_INTERACT_POS)

	if dist_v1 < VIOLEIRO_INTERACT_RADIUS or dist_v2 < VIOLEIRO_INTERACT_RADIUS:
		if dist_v1 <= dist_v2:
			_talk_to_violeiro_1()
		else:
			_talk_to_violeiro_2()
		return

	if not _carried_item.is_empty():
		var item_name: String = str(_carried_item["name"])
		_carried_item["assigned_house_idx"] = -1
		_carried_item["pos"] = _carried_item["origin"]
		_carried_item["interior_pos"] = Vector2.ZERO
		DialogPanel.post_message("↩️ %s foi solto fora de uma casa e retornou à sua mesa de origem!" % item_name)
		SoundManager.play_pickup()
		JuiceManager.emit_particles("dust", _player.global_position, self, {"count": 8, "speed": 30.0})
		_carried_item = {}
		return

	var closest_item: Dictionary = {}
	var closest_dist: float = ITEM_PICKUP_RADIUS
	for it: Dictionary in _all_items:
		if int(it["assigned_house_idx"]) == -1:
			var d: float = _player.global_position.distance_to(it["pos"] as Vector2)
			if d < closest_dist:
				closest_dist = d
				closest_item = it

	if not closest_item.is_empty():
		_carried_item = closest_item
		DialogPanel.post_message(
			"✋ Você pegou: %s (%s). Leve até a casa certa e entre na porta!" % [str(closest_item["name"]), str(closest_item["icon"])]
		)
		SoundManager.play_pickup()
		JuiceManager.emit_particles("sparkle", _player.global_position, self, {"count": 8, "speed": 35.0})


func _talk_to_violeiro_1() -> void:
	SoundManager.play_viola_repente()
	var lines: Array[Dictionary] = [
		{
			"speaker": "Violeiro 1",
			"avatar_icon": "🪕",
			"text": "🎵 \"O Vaqueiro na Casa Amarela habita, e bebe Água de pote bem gelada que palpita; ao seu lado a Casa Azul a cantiga ressuscita!\"",
		},
		{
			"speaker": "Violeiro 1",
			"avatar_icon": "🪕",
			"text": "🎵 \"A Rendeira caprichosa mora na bela Casa Azul, cria o Galo que canta no sertão e bebe doce Garapa na cuia!\"",
		},
		{
			"speaker": "Violeiro 1",
			"avatar_icon": "🪕",
			"text": "🎵 \"O Cantador de repente mora na Casa Vermelha, toma Cachaça acendendo sua centelha e pita Fumo Desfiado na brasa!\"",
		},
	]
	DialogPanel.start_dialog("violeiro_1", "Mestre Cícero Violeiro", "🪕", lines, Callable(), true)


func _talk_to_violeiro_2() -> void:
	SoundManager.play_viola_repente()
	var lines: Array[Dictionary] = [
		{
			"speaker": "Violeiro 2",
			"avatar_icon": "🪕",
			"text": "🎵 \"A Casa Verde fica ao lado da Branca; seu dono bebe Umbu: é o Ferrador afamado!\"",
		},
		{
			"speaker": "Violeiro 2",
			"avatar_icon": "🪕",
			"text": "🎵 \"O Ferrador cria o Cavalo veloz e pita Fumo Arapiraca trazido do seu norte!\"",
		},
		{
			"speaker": "Violeiro 2",
			"avatar_icon": "🪕",
			"text": "🎵 \"A Rezadeira na Casa Branca toma Café e pita Trevo! Na 1ª Amarela o Bode pasta com Paieiro, na Branca o Canário canta, e na Vermelha o Tatu cava o chão!\"",
		},
	]
	DialogPanel.start_dialog("violeiro_2", "Severino Cantador", "🪕", lines, Callable(), true)


func _check_victory() -> void:
	if _state_status != "PLAYING" or _houses.size() < 5:
		return

	var h1: Dictionary = _houses[0]
	var h2: Dictionary = _houses[1]
	var h3: Dictionary = _houses[2]
	var h4: Dictionary = _houses[3]
	var h5: Dictionary = _houses[4]

	var is_h1_valid: bool = str(h1["morador"]) == "Vaqueiro" and str(h1["bebida"]) == "Água" and str(h1["fumo"]) == "Paieiro" and str(h1["animal"]) == "Bode"
	var is_h2_valid: bool = str(h2["morador"]) == "Rendeira" and str(h2["bebida"]) == "Garapa" and str(h2["fumo"]) == "Palha" and str(h2["animal"]) == "Galo"
	var is_h3_valid: bool = str(h3["morador"]) == "Cantador" and str(h3["bebida"]) == "Cachaça" and str(h3["fumo"]) == "Desfiado" and str(h3["animal"]) == "Tatu"
	var is_h4_valid: bool = str(h4["morador"]) == "Ferrador" and str(h4["bebida"]) == "Umbu" and str(h4["fumo"]) == "Arapiraca" and str(h4["animal"]) == "Cavalo"
	var is_h5_valid: bool = str(h5["morador"]) == "Rezadeira" and str(h5["bebida"]) == "Café" and str(h5["fumo"]) == "Trevo" and str(h5["animal"]) == "Canário"

	if is_h1_valid and is_h2_valid and is_h3_valid and is_h4_valid and is_h5_valid:
		_state_status = "SUCCESS"
		GameManager.unlock_item("pena")
		SoundManager.play_victory_jingle()
		NarrativeOverlay.show_outro({
			"phase_number": 3,
			"title": "A Pena da Rasga-Mortalha",
			"verses": PackedStringArray([
				"A dedução foi perfeita na vila da cantoria,",
				"Cada casa no seu canto com firme sabedoria;",
				"A Rasga-Mortalha desce das nuvens do sertão:",
				"E entrega a Pena Encantada com louvor e consagração!",
			]),
			"item_reward": {
				"id": "pena",
				"name": "Pena Encantada",
				"icon": "🪶",
			},
		}, func() -> void:
			GameManager.call_deferred("switch_scene", "STUDIO")
		)


func _trigger_timeout_failure() -> void:
	if _state_status != "PLAYING":
		return
	_stage_timer = 0.0
	_state_status = "FAILED"
	_refresh_hud()
	SoundManager.play_defeat_jingle()
	NarrativeOverlay.show_outro({
		"phase_number": 3,
		"title": "O Mau Agouro da Rasga-Mortalha",
		"verses": PackedStringArray([
			"O tempo findou-se na escuridão da praça,",
			"O grito da coruja espalhou sua desgraça;",
			"Os moradores correram com medo da assombração,",
			"Retorne ao Estúdio para tentar nova dedução!",
		]),
		"item_reward": {
			"id": "pena",
			"name": "Pena Perdida",
			"icon": "🪶",
		},
	}, func() -> void:
		GameManager.call_deferred("switch_scene", "STUDIO")
	)


func _get_house(house_idx: int) -> Dictionary:
	for h: Dictionary in _houses:
		if int(h["index"]) == house_idx:
			return h
	return {}


func _refresh_hud() -> void:
	if _title_label != null:
		if _current_interior_house_idx != -1:
			var h: Dictionary = _get_house(_current_interior_house_idx)
			_title_label.text = "🏠 INTERIOR DA CASA %d (%s)" % [_current_interior_house_idx, str(h.get("cor_name", ""))]
		else:
			_title_label.text = "🦉 FASE 3: A PRAÇA DAS 5 CASAS"

	if _timer_label != null:
		var minutes: int = int(floor(_stage_timer / 60.0))
		var seconds: int = int(floor(fmod(_stage_timer, 60.0)))
		_timer_label.text = "⏳ %02d:%02d" % [minutes, seconds]
		var urgent: bool = _stage_timer <= 60.0
		_timer_label.add_theme_color_override(
			"font_color",
			Color("#f87171") if urgent else Color("#fef08a")
		)

	if _status_label != null:
		if not _carried_item.is_empty():
			_status_label.text = "Carregando: %s %s — Entre em uma casa para soltar [E] ou solte fora para devolver." % [str(_carried_item["icon"]), str(_carried_item["name"])]
		elif _current_interior_house_idx != -1:
			_status_label.text = "[E] Soltar/Pegar item no chão | [Espaço] Gritar para devolver tudo às mesas | Desça até a SAÍDA ⬇"
		else:
			_status_label.text = "Ouça os 2 Violeiros [E], pegue Moradores, Bebidas, Fumos e Animais [E] e entre nas 5 casas!"


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font

	if _current_interior_house_idx != -1:
		_draw_house_interior(font)
		return

	# 1. Fundo da Praca da Vila (Exterior)
	draw_rect(Rect2(0.0, 0.0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT), Color("#1e1b18"), true)
	XiloDraw.draw_moldura_cordel(self, Rect2(8.0, 8.0, VIEWPORT_WIDTH - 16.0, VIEWPORT_HEIGHT - 16.0), 3.0)

	# 2. As 5 Casas em Arco
	for h: Dictionary in _houses:
		var h_pos: Vector2 = h["pos"] as Vector2
		var h_size: Vector2 = h["size"] as Vector2
		var h_color: Color = Color(str(h["color_hex"]))
		var h_rect: Rect2 = Rect2(h_pos - h_size * 0.5, h_size)
		XiloDraw.draw_rect_xilo(self, h_rect, Color("#292524"), h_color, 3.0)

		if font != null:
			draw_string(font, Vector2(h_pos.x - h_size.x * 0.5, h_pos.y - 36.0), "Casa %d" % int(h["index"]), HORIZONTAL_ALIGNMENT_CENTER, h_size.x, 12, h_color)
			draw_string(font, Vector2(h_pos.x - h_size.x * 0.5, h_pos.y - 22.0), str(h["cor_name"]), HORIZONTAL_ALIGNMENT_CENTER, h_size.x, 10, Color("#d6d3d1"))

		# Porta da Casa
		var door_rect: Rect2 = Rect2(h_pos.x - 18.0, h_pos.y + 12.0, 36.0, 42.0)
		XiloDraw.draw_rect_xilo(self, door_rect, Color("#44403c"), Color("#facc15"), 1.5)
		if font != null:
			draw_string(font, Vector2(h_pos.x - 18.0, h_pos.y + 36.0), "ENTRAR", HORIZONTAL_ALIGNMENT_CENTER, 36.0, 8, Color("#facc15"))

		# Icones dos itens dentro da casa
		var icons: Array[String] = []
		var h_idx: int = int(h["index"])
		for it: Dictionary in _all_items:
			if int(it["assigned_house_idx"]) == h_idx:
				icons.append(str(it["icon"]))
		if not icons.is_empty() and font != null:
			draw_string(font, Vector2(h_pos.x - h_size.x * 0.5, h_pos.y), " ".join(icons), HORIZONTAL_ALIGNMENT_CENTER, h_size.x, 13, Color.WHITE)

	# 3. Palco Central dos Violeiros
	XiloDraw.draw_palco_violeiros(self, Vector2(480.0, 270.0), Vector2(220.0, 85.0), {"time": _anim_time})
	XiloDraw.draw_violeiro(self, VIOLEIRO_1_POS, Vector2(38.0, 44.0), {"time": _anim_time})
	XiloDraw.draw_violeiro(self, VIOLEIRO_2_POS, Vector2(38.0, 44.0), {"time": _anim_time, "color_tint": Color("#1e3a8a")})
	if font != null:
		draw_string(font, Vector2(VIOLEIRO_1_POS.x - 45.0, VIOLEIRO_1_POS.y + 34.0), "🪕 Violeiro 1 [E]", HORIZONTAL_ALIGNMENT_CENTER, 90.0, 9, Color("#fde047"))
		draw_string(font, Vector2(VIOLEIRO_2_POS.x - 45.0, VIOLEIRO_2_POS.y + 34.0), "🪕 Violeiro 2 [E]", HORIZONTAL_ALIGNMENT_CENTER, 90.0, 9, Color("#93c5fd"))

	# 4. Os 4 Quadros / Mesas Ampliados em Arco na Base da Praca
	_draw_table_box(font, Vector2(140.0, 440.0), Vector2(220.0, 100.0), "🍻 BODEGA DOS MORADORES")
	_draw_table_box(font, Vector2(370.0, 465.0), Vector2(200.0, 100.0), "🍶 BEBIDAS & CAFÉ")
	_draw_table_box(font, Vector2(590.0, 465.0), Vector2(200.0, 100.0), "🍂 FUMOS REGIONAIS")
	_draw_table_box(font, Vector2(820.0, 440.0), Vector2(220.0, 100.0), "🐐 CURRAL DE ANIMAIS")

	# 5. Itens nas Mesas (nao atribuidos e nao carregados)
	var carried_id: String = str(_carried_item.get("id", ""))
	for it: Dictionary in _all_items:
		if int(it["assigned_house_idx"]) == -1 and str(it["id"]) != carried_id:
			var it_pos: Vector2 = it["pos"] as Vector2
			var it_type: String = str(it["type"])
			if it_type == "morador":
				XiloDraw.draw_morador_bebado(self, it_pos + Vector2(0.0, 8.0), Vector2(28.0, 38.0), {"color_tint": Color(str(it["color"])), "time": _anim_time})
			elif it_type == "animal":
				XiloDraw.draw_rect_xilo(self, Rect2(it_pos.x - 18.0, it_pos.y - 12.0, 36.0, 36.0), Color("#1e293b"), Color("#ea580c"), 1.5)
				if font != null:
					draw_string(font, Vector2(it_pos.x - 18.0, it_pos.y + 12.0), str(it["icon"]), HORIZONTAL_ALIGNMENT_CENTER, 36.0, 20, Color.WHITE)
			else:
				if font != null:
					draw_string(font, Vector2(it_pos.x - 18.0, it_pos.y + 10.0), str(it["icon"]), HORIZONTAL_ALIGNMENT_CENTER, 36.0, 18, Color.WHITE)

			if font != null:
				draw_string(font, Vector2(it_pos.x - 36.0, it_pos.y + 26.0), str(it["name"]), HORIZONTAL_ALIGNMENT_CENTER, 72.0, 9, Color("#e2e8f0"))

	# 6. Coruja Rasga-Mortalha
	XiloDraw.draw_rasga_mortalha(self, _owl_pos, Vector2(48.0, 36.0), {"time": _anim_time})

	# 7. Item Carregado
	_draw_carried_item(font)


func _draw_house_interior(font: Font) -> void:
	var house: Dictionary = _get_house(_current_interior_house_idx)
	var h_color: Color = Color(str(house.get("color_hex", "#d4af37")))

	# Piso de madeira e paredes internas xilo
	XiloDraw.draw_chao_estudio_madeira(self, Rect2(0.0, 0.0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT))
	XiloDraw.draw_rect_xilo(self, Rect2(70.0, 70.0, 820.0, 440.0), Color("#241b14"), h_color, 4.0)
	XiloDraw.draw_moldura_cordel(self, Rect2(8.0, 8.0, VIEWPORT_WIDTH - 16.0, VIEWPORT_HEIGHT - 16.0), 3.0)

	if font != null:
		draw_string(
			font,
			Vector2(100.0, 108.0),
			"Casa %d (%s) — [E] Soltar / Pegar | [Espaço] Gritar para Resetar" % [int(house.get("index", 0)), str(house.get("cor_name", ""))],
			HORIZONTAL_ALIGNMENT_CENTER,
			760.0,
			13,
			Color("#fef08a")
		)

	# Itens depositados nesta casa
	var house_idx: int = int(house.get("index", -1))
	for it: Dictionary in _all_items:
		if int(it["assigned_house_idx"]) == house_idx:
			var i_pos: Vector2 = it["interior_pos"] as Vector2
			if i_pos == Vector2.ZERO:
				continue
			var it_type: String = str(it["type"])
			if it_type == "morador":
				XiloDraw.draw_morador_bebado(self, i_pos, Vector2(36.0, 48.0), {"color_tint": Color(str(it["color"])), "time": _anim_time})
			elif it_type == "animal":
				XiloDraw.draw_rect_xilo(self, Rect2(i_pos.x - 20.0, i_pos.y - 20.0, 40.0, 40.0), Color("#1e293b"), Color("#ea580c"), 1.5)
				if font != null:
					draw_string(font, Vector2(i_pos.x - 20.0, i_pos.y + 7.0), str(it["icon"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, Color.WHITE)
			else:
				XiloDraw.draw_rect_xilo(self, Rect2(i_pos.x - 18.0, i_pos.y - 18.0, 36.0, 36.0), Color("#1e293b"), Color("#d4af37"), 1.5)
				if font != null:
					draw_string(font, Vector2(i_pos.x - 18.0, i_pos.y + 7.0), str(it["icon"]), HORIZONTAL_ALIGNMENT_CENTER, 36.0, 20, Color.WHITE)

			if font != null:
				draw_string(font, Vector2(i_pos.x - 45.0, i_pos.y + 30.0), "[E] %s" % str(it["name"]), HORIZONTAL_ALIGNMENT_CENTER, 90.0, 10, Color("#facc15"))

	# Tapete / Porta de Saida Inferior
	XiloDraw.draw_rect_xilo(self, Rect2(430.0, 425.0, 100.0, 30.0), Color("#854d0e"), Color("#fef08a"), 2.0)
	if font != null:
		draw_string(font, Vector2(430.0, 444.0), "SAÍDA ⬇", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 11, Color("#fef08a"))

	_draw_carried_item(font)


func _draw_table_box(font: Font, center: Vector2, size: Vector2, label: String) -> void:
	var rect: Rect2 = Rect2(center - size * 0.5, size)
	XiloDraw.draw_rect_xilo(self, rect, Color("#27272a"), XiloPalette.GOLD_ACCENT, 2.0)
	if font != null:
		draw_string(font, Vector2(rect.position.x, rect.position.y + 15.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color("#fde047"))


func _draw_carried_item(font: Font) -> void:
	if _carried_item.is_empty() or _player == null or font == null:
		return
	var anchor: Vector2 = _player.global_position + Vector2(22.0, -24.0)
	draw_string(font, Vector2(anchor.x - 16.0, anchor.y), str(_carried_item["icon"]), HORIZONTAL_ALIGNMENT_CENTER, 32.0, 20, Color.WHITE)
	draw_string(font, Vector2(anchor.x - 45.0, anchor.y - 16.0), "[%s]" % str(_carried_item["name"]), HORIZONTAL_ALIGNMENT_CENTER, 90.0, 9, Color("#fef08a"))
