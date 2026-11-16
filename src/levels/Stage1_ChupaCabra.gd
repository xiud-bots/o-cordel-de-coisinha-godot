class_name Stage1_ChupaCabra
extends Node2D

const MAP_WIDTH: float = 2400.0
const MAP_HEIGHT: float = 1350.0
const VIEWPORT_WIDTH: float = 960.0
const VIEWPORT_HEIGHT: float = 580.0

const CURRAL_POS: Vector2 = Vector2(1200.0, 675.0)
const CURRAL_SIZE: Vector2 = Vector2(240.0, 180.0)
const FAZENDEIRO_POS: Vector2 = Vector2(1200.0, 620.0)

const CHUPA_START_POS: Vector2 = Vector2(350.0, 350.0)
const CHUPA_HUNT_SPEED: float = 140.0
const CHUPA_FLEE_SPEED: float = 290.0

var _hero_hurt_cooldown: float = 0.0
var _chupa_pos: Vector2 = CHUPA_START_POS
var _chupa_active: bool = true
var _chupa_flee_timer: float = 0.0

var _bushes: Array[Dictionary] = []
var _bush_interactables: Array[InteractableComponent] = []
var _goats: Array[Dictionary] = []

var _has_rope: bool = false
var _has_lantern: bool = false

var _is_aboio_active: bool = false
var _is_grito_active: bool = false
var _sound_wave_timer: float = 0.0
var _sound_wave_radius: float = 0.0
var _sound_wave_max_radius: float = 0.0

var _state_status: String = "PLAYING" # PLAYING | SUCCESS | FAILED
var _rosnado_timer: float = 0.0
var _fail_timer: float = 0.0
var _anim_time: float = 0.0
var _status_message: String = "Explore as moitas, ache a corda e traga os 4 bodes ao curral!"
var _last_player_pos: Vector2 = Vector2(1200.0, 780.0)
var _player_move_dir: Vector2 = Vector2.DOWN

@onready var _player: Coisinha = $Coisinha
@onready var _camera: Camera2D = $Camera2D
@onready var _fazendeiro_interactable: InteractableComponent = $FazendeiroInteractable
@onready var _bushes_root: Node2D = $BushesRoot
@onready var _title_label: Label = $HUDLayer/TopBar/TitleLabel
@onready var _hp_label: Label = $HUDLayer/TopBar/HPBox/HPLabel
@onready var _status_label: Label = $HUDLayer/StatusBar/StatusLabel


func _ready() -> void:
	GameManager.current_scene_id = "STAGE_1_CHUPACABRA"
	SoundManager.play_music("STAGE1_CHUPACABRA")
	SoundManager.set_music_tension(0.3)

	_reset_stage_data()

	if _player != null:
		_player.global_position = Vector2(1200.0, 780.0)
		_player.move_speed = 240.0
		_player.facing = "down"
		_last_player_pos = _player.global_position
		_player.shouted.connect(_on_player_shouted)
		_player.aboio_performed.connect(_on_player_aboio_performed)
		if _player.health != null:
			_player.health.reset_health()
			_player.health.damaged.connect(_on_player_hp_updated)
			_player.health.healed.connect(_on_player_hp_updated)

	if _camera != null:
		_camera.limit_left = 0
		_camera.limit_top = 0
		_camera.limit_right = int(MAP_WIDTH)
		_camera.limit_bottom = int(MAP_HEIGHT)
		_camera.global_position = Vector2(1200.0, 780.0)

	if _fazendeiro_interactable != null:
		_fazendeiro_interactable.global_position = FAZENDEIRO_POS
		_fazendeiro_interactable.interacted.connect(_on_fazendeiro_interacted)

	EventBus.stage_reset_requested.connect(_reset_bushes)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)

	_build_bush_interactables()
	_refresh_hud()

	NarrativeOverlay.show_intro({
		"phase_number": 1,
		"title": "O Ataque do Chupa-Cabra",
		"subtitle": "Pastoreio, coragem e o mistério na Caatinga",
		"verses": PackedStringArray([
			"Na noite fria da caatinga o bicho feio atacou,",
			"Os quatro bodes do curral com pavor afugentou;",
			"Procure a corda nas moitas, com sabedoria e vigor,",
			"Traga os bodes de volta antes do golpe do traidor!",
		]),
		"objective": "Resgate os 4 bodes no curral central e espante o Chupa-Cabra com o grito!",
		"item_reward": {
			"id": "carimbo",
			"name": "Carimbo Mágico",
			"icon": "🪓",
		},
	})
	queue_redraw()


func _exit_tree() -> void:
	_reset_bushes()


func _reset_stage_data() -> void:
	_hero_hurt_cooldown = 0.0
	_chupa_pos = CHUPA_START_POS
	_chupa_active = true
	_chupa_flee_timer = 0.0
	_has_rope = false
	_has_lantern = false
	_is_aboio_active = false
	_is_grito_active = false
	_sound_wave_timer = 0.0
	_sound_wave_radius = 0.0
	_sound_wave_max_radius = 0.0
	_state_status = "PLAYING"
	_rosnado_timer = 0.0
	_fail_timer = 0.0
	_anim_time = 0.0
	_status_message = "Explore as moitas, ache a corda e traga os 4 bodes ao curral!"

	_bushes = [
		{"id": "b1", "pos": Vector2(600.0, 400.0), "radius": 46.0, "type": "corda", "is_searched": false, "hiding_goat_id": "goat_1"},
		{"id": "b2", "pos": Vector2(1800.0, 400.0), "radius": 46.0, "type": "candeeiro", "is_searched": false, "hiding_goat_id": "goat_2"},
		{"id": "b3", "pos": Vector2(500.0, 1000.0), "radius": 48.0, "type": "bode", "is_searched": false, "hiding_goat_id": "goat_3"},
		{"id": "b4", "pos": Vector2(1900.0, 1000.0), "radius": 48.0, "type": "bode", "is_searched": false, "hiding_goat_id": "goat_4"},
		{"id": "b_c1", "pos": Vector2(850.0, 350.0), "radius": 44.0, "type": "cacto", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b_c2", "pos": Vector2(1550.0, 350.0), "radius": 44.0, "type": "cacto", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b_c3", "pos": Vector2(800.0, 1100.0), "radius": 44.0, "type": "cacto", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b_c4", "pos": Vector2(1600.0, 1100.0), "radius": 44.0, "type": "cacto", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b_f1", "pos": Vector2(1200.0, 300.0), "radius": 44.0, "type": "fruta", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b_f2", "pos": Vector2(1200.0, 1150.0), "radius": 44.0, "type": "fruta", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b_f3", "pos": Vector2(350.0, 700.0), "radius": 44.0, "type": "fruta", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b_f4", "pos": Vector2(2050.0, 700.0), "radius": 44.0, "type": "fruta", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b5", "pos": Vector2(950.0, 550.0), "radius": 42.0, "type": "normal", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b6", "pos": Vector2(1450.0, 550.0), "radius": 42.0, "type": "normal", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b7", "pos": Vector2(300.0, 350.0), "radius": 42.0, "type": "normal", "is_searched": false, "hiding_goat_id": ""},
		{"id": "b8", "pos": Vector2(2100.0, 350.0), "radius": 42.0, "type": "normal", "is_searched": false, "hiding_goat_id": ""},
	]

	_goats = [
		{
			"id": "goat_1",
			"label": "[BODE 1]",
			"pos": Vector2(600.0, 400.0),
			"vel": Vector2.ZERO,
			"hp": 100.0,
			"max_hp": 100.0,
			"is_rescued": false,
			"is_leashed": false,
			"hidden_in_bush_id": "b1",
			"target_bush_id": "",
			"wander_timer": 1.0,
			"flee_timer": 0.0,
			"facing": "right",
		},
		{
			"id": "goat_2",
			"label": "[BODE 2]",
			"pos": Vector2(1800.0, 400.0),
			"vel": Vector2.ZERO,
			"hp": 100.0,
			"max_hp": 100.0,
			"is_rescued": false,
			"is_leashed": false,
			"hidden_in_bush_id": "b2",
			"target_bush_id": "",
			"wander_timer": 1.5,
			"flee_timer": 0.0,
			"facing": "left",
		},
		{
			"id": "goat_3",
			"label": "[BODE 3]",
			"pos": Vector2(500.0, 1000.0),
			"vel": Vector2.ZERO,
			"hp": 100.0,
			"max_hp": 100.0,
			"is_rescued": false,
			"is_leashed": false,
			"hidden_in_bush_id": "b3",
			"target_bush_id": "",
			"wander_timer": 2.0,
			"flee_timer": 0.0,
			"facing": "right",
		},
		{
			"id": "goat_4",
			"label": "[BODE 4]",
			"pos": Vector2(1900.0, 1000.0),
			"vel": Vector2.ZERO,
			"hp": 100.0,
			"max_hp": 100.0,
			"is_rescued": false,
			"is_leashed": false,
			"hidden_in_bush_id": "b4",
			"target_bush_id": "",
			"wander_timer": 0.5,
			"flee_timer": 0.0,
			"facing": "left",
		},
	]


func _reset_bushes() -> void:
	for bush: Dictionary in _bushes:
		bush["is_searched"] = false
	for inter: InteractableComponent in _bush_interactables:
		if is_instance_valid(inter):
			inter.reset_interactable()
	queue_redraw()


func _on_scene_change_requested(_scene_id: String) -> void:
	_reset_bushes()


func _build_bush_interactables() -> void:
	if _bushes_root == null:
		return
	for child: Node in _bushes_root.get_children():
		child.queue_free()
	_bush_interactables.clear()

	for idx: int in range(_bushes.size()):
		var bush: Dictionary = _bushes[idx]
		var inter: InteractableComponent = InteractableComponent.new()
		inter.name = "BushInteract_%s" % str(bush["id"])
		inter.position = bush["pos"] as Vector2
		inter.collision_layer = 8
		inter.collision_mask = 2
		inter.interact_id = "bush_%s" % str(bush["id"])
		inter.prompt_text = "Vasculhar Moita [E]"
		inter.one_shot = false
		inter.interact_priority = 1

		var shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = float(bush["radius"]) + 35.0
		shape.shape = circle
		inter.add_child(shape)

		inter.interacted.connect(_on_bush_interacted.bind(idx))
		_bushes_root.add_child(inter)
		_bush_interactables.append(inter)


func _process(delta: float) -> void:
	_anim_time += delta

	if _hero_hurt_cooldown > 0.0:
		_hero_hurt_cooldown = maxf(0.0, _hero_hurt_cooldown - delta)

	if _state_status == "FAILED":
		_fail_timer -= delta
		if _fail_timer <= 0.0:
			_state_status = "RETURNING"
			GameManager.call_deferred("switch_scene", "STUDIO")
		return

	if NarrativeOverlay.is_overlay_active or DialogPanel.is_dialog_active or GameManager.is_paused:
		return

	if _state_status != "PLAYING":
		return

	if _player != null:
		_player.global_position = Vector2(
			clampf(_player.global_position.x, 30.0, MAP_WIDTH - 30.0),
			clampf(_player.global_position.y, 30.0, MAP_HEIGHT - 30.0)
		)
		var delta_move: Vector2 = _player.global_position - _last_player_pos
		if delta_move.length_squared() > 0.25:
			_player_move_dir = delta_move.normalized()
		_last_player_pos = _player.global_position

		if _camera != null:
			var target_cam: Vector2 = Vector2(
				clampf(_player.global_position.x, VIEWPORT_WIDTH * 0.5, MAP_WIDTH - VIEWPORT_WIDTH * 0.5),
				clampf(_player.global_position.y, VIEWPORT_HEIGHT * 0.5, MAP_HEIGHT - VIEWPORT_HEIGHT * 0.5)
			)
			_camera.global_position = _camera.global_position.lerp(target_cam, minf(1.0, 6.0 * delta))

	_update_sound_wave(delta)
	_check_cactus_collisions()
	_update_chupa_cabra(delta)
	_update_goats(delta)
	_check_victory()
	_refresh_hud()
	queue_redraw()


func _update_sound_wave(delta: float) -> void:
	if _sound_wave_timer > 0.0:
		_sound_wave_timer = maxf(0.0, _sound_wave_timer - delta)
		var expand_speed: float = 540.0 if _is_grito_active else 320.0
		_sound_wave_radius = minf(_sound_wave_max_radius, _sound_wave_radius + expand_speed * delta)
		if _sound_wave_timer <= 0.0:
			_is_aboio_active = false
			_is_grito_active = false
			_sound_wave_radius = 0.0


func _check_cactus_collisions() -> void:
	if _player == null or _hero_hurt_cooldown > 0.0:
		return
	if _player.is_invulnerable():
		return

	for bush: Dictionary in _bushes:
		if str(bush["type"]) != "cacto":
			continue
		var bush_pos: Vector2 = bush["pos"] as Vector2
		var dist: float = _player.global_position.distance_to(bush_pos)
		if dist < float(bush["radius"]) + 14.0:
			bush["is_searched"] = true
			_apply_cactus_damage(_player.global_position)
			break


func _apply_cactus_damage(fx_pos: Vector2) -> void:
	_hero_hurt_cooldown = 1.2
	if _player != null and _player.health != null:
		if _player.health.current_hp > 1:
			_player.take_damage(1)
		else:
			# Mantem no minimo 1 HP no cacto como no original TS e ativa i-frames
			_player.health._start_invulnerability()

	SoundManager.play_hurt_cacto()
	SoundManager.play_grito()
	JuiceManager.add_trauma(0.5)
	JuiceManager.emit_particles("dust", fx_pos, self, {"count": 14, "speed": 80.0})
	_set_status("🌵 AI! ESPINHO DE MANDACARU! Você perdeu 1 HP e soltou um grito de dor!", true)
	_trigger_sound_wave(320.0, true)


func _on_player_shouted(_world_pos: Vector2) -> void:
	if _state_status != "PLAYING":
		return
	_is_grito_active = true
	_is_aboio_active = false
	_sound_wave_timer = 0.55
	_sound_wave_radius = 40.0
	_sound_wave_max_radius = 380.0
	JuiceManager.add_trauma(0.45)
	_trigger_sound_wave(380.0, true)


func _on_player_aboio_performed(_world_pos: Vector2) -> void:
	if _state_status != "PLAYING":
		return
	_is_aboio_active = true
	_is_grito_active = false
	_sound_wave_timer = 0.45
	_sound_wave_radius = 30.0
	_sound_wave_max_radius = 160.0
	_trigger_sound_wave(160.0, false)


func _trigger_sound_wave(radius: float, is_grito: bool) -> void:
	if _player == null:
		return
	var player_pos: Vector2 = _player.global_position

	if is_grito:
		# 1. Grito AFUGENTA o Chupa-Cabra por 3 segundos!
		var dist_chupa: float = player_pos.distance_to(_chupa_pos)
		if dist_chupa < radius + 90.0:
			_chupa_flee_timer = 3.0
			_set_status("🦇 O CHUPA-CABRA FOI AFUGENTADO PELO GRITO! (Fuga de 3s)")
			SoundManager.play_chupacabra_rosnado()
			JuiceManager.emit_particles("dust", _chupa_pos, self, {"count": 10, "speed": 60.0})

		# 2. Grito faz os bodes correrem em panico procurando outra moita
		for goat: Dictionary in _goats:
			if bool(goat["is_rescued"]) or bool(goat["is_leashed"]):
				continue
			var goat_pos: Vector2 = goat["pos"] as Vector2
			if player_pos.distance_to(goat_pos) < radius + 60.0:
				var old_bush_id: String = str(goat["hidden_in_bush_id"])
				if not old_bush_id.is_empty():
					var old_bush: Dictionary = _find_bush_by_id(old_bush_id)
					if not old_bush.is_empty():
						old_bush["hiding_goat_id"] = ""
					goat["hidden_in_bush_id"] = ""

				goat["flee_timer"] = 3.5
				SoundManager.play_berro_bode(true)

				var best_bush: Dictionary = _find_nearest_free_bush(goat["pos"] as Vector2, 30.0)
				if not best_bush.is_empty():
					goat["target_bush_id"] = str(best_bush["id"])
	else:
		# Aboio: NAO afeta o Chupa-Cabra. Faz bodes andarem um pouco.
		for goat: Dictionary in _goats:
			if bool(goat["is_rescued"]) or bool(goat["is_leashed"]):
				continue
			var goat_pos: Vector2 = goat["pos"] as Vector2
			if player_pos.distance_to(goat_pos) < radius + 45.0:
				var old_bush_id: String = str(goat["hidden_in_bush_id"])
				if not old_bush_id.is_empty():
					var old_bush: Dictionary = _find_bush_by_id(old_bush_id)
					if not old_bush.is_empty():
						old_bush["hiding_goat_id"] = ""
						goat["pos"] = (old_bush["pos"] as Vector2) + Vector2(20.0, 20.0)
					else:
						goat["pos"] = goat_pos + Vector2(20.0, 20.0)
					goat["hidden_in_bush_id"] = ""

				var push_dir: Vector2 = ((goat["pos"] as Vector2) - player_pos).normalized()
				if push_dir.length_squared() < 0.01:
					push_dir = Vector2.RIGHT
				goat["vel"] = push_dir * 85.0
				goat["wander_timer"] = 1.2
				goat["facing"] = "left" if push_dir.x < 0.0 else "right"
				SoundManager.play_berro_bode(false)


func _on_fazendeiro_interacted(_interactor: Node2D) -> void:
	if _state_status != "PLAYING":
		return
	var rescued_count: int = _get_rescued_count()
	var lines: Array[Dictionary] = [
		{
			"speaker": "Fazendeiro",
			"avatar_icon": "👨‍🌾",
			"text": "Então, Coisinha! Meus 4 bodes fugiram pelo pasto. Você já salvou %d de 4!" % rescued_count,
		},
		{
			"speaker": "Fazendeiro",
			"avatar_icon": "👨‍🌾",
			"text": "O aboio faz o bode andar de leve. O grito faz o bode correr para se esconder na moita e AFUGENTA o Chupa-Cabra por 3 segundos!",
		},
	]
	DialogPanel.start_dialog("fazendeiro", "Fazendeiro Zé do Bode", "👨‍🌾", lines, Callable(), true)


func _on_bush_interacted(_interactor: Node2D, bush_idx: int) -> void:
	if _state_status != "PLAYING" or bush_idx < 0 or bush_idx >= _bushes.size():
		return

	var bush: Dictionary = _bushes[bush_idx]
	var bush_pos: Vector2 = bush["pos"] as Vector2
	var bush_type: String = str(bush["type"])

	if not bool(bush["is_searched"]):
		bush["is_searched"] = true

		if bush_type == "corda" and not _has_rope:
			_has_rope = true
			GameManager.unlock_bush_item("corda")
			_set_status("🪢 CORDA ENCONTRADA! Agora você laça os bodes ao se aproximar!", false, true)
			SoundManager.play_pickup()
			JuiceManager.emit_particles("sparkle", bush_pos, self, {"count": 10, "speed": 50.0})
			DialogPanel.start_bush_item_dialog(
				"corda",
				"Corda Trançada",
				"🪢",
				PackedStringArray(["🪢 \"Uma corda resistente de couro cru! Com ela posso laçar e conduzir os 4 bodes para o curral com segurança!\""])
			)
		elif bush_type == "candeeiro" and not _has_lantern:
			_has_lantern = true
			GameManager.unlock_bush_item("candeeiro")
			_set_status("🏮 CANDEEIRO ENCONTRADO! Iluminação expandida na caatinga!", false, true)
			SoundManager.play_pickup()
			JuiceManager.emit_particles("sparkle", bush_pos, self, {"count": 10, "speed": 50.0})
			DialogPanel.start_bush_item_dialog(
				"candeeiro",
				"Candeeiro Místico",
				"🏮",
				PackedStringArray(["🏮 \"O candeeiro aceso dissipa a escuridão da caatinga e revela o caminho por entre as moitas!\""])
			)
		elif bush_type == "fruta":
			if _player != null and _player.health != null and _player.health.current_hp < _player.health.max_hp:
				_player.heal(1)
				_set_status("🍎 FRUTA SABOROSA DE UMBU! Você recuperou +1 HP!", false, true)
			else:
				_set_status("🍎 Fruta deliciosa da caatinga!", false, true)
			SoundManager.play_fruit_eat()
			JuiceManager.emit_particles("sparkle", bush_pos, self, {"count": 12, "speed": 45.0})
		elif bush_type == "cacto":
			if _player != null and not _player.is_invulnerable():
				_apply_cactus_damage(bush_pos)
		else:
			SoundManager.play_cordel_folhear()
			JuiceManager.emit_particles("leaf", bush_pos, self, {"count": 8, "speed": 40.0})

	# Se tiver bode escondido, faz sair
	var hiding_id: String = str(bush["hiding_goat_id"])
	if not hiding_id.is_empty():
		var goat: Dictionary = _find_goat_by_id(hiding_id)
		if not goat.is_empty() and not str(goat["hidden_in_bush_id"]).is_empty():
			goat["hidden_in_bush_id"] = ""
			goat["target_bush_id"] = ""
			goat["pos"] = bush_pos + Vector2(25.0, 25.0)
			bush["hiding_goat_id"] = ""
			_set_status("🐐 Você descobriu um bode escondido na moita!")
			SoundManager.play_berro_bode(false)
			SoundManager.play_item_descobrir()
			JuiceManager.emit_particles("leaf", bush_pos, self, {"count": 6, "speed": 35.0})

	queue_redraw()


func _update_chupa_cabra(delta: float) -> void:
	if not _chupa_active:
		return

	var is_attacking_goat: bool = false

	if _chupa_flee_timer > 0.0:
		_chupa_flee_timer = maxf(0.0, _chupa_flee_timer - delta)
		if _player != null:
			var flee_dir: Vector2 = (_chupa_pos - _player.global_position).normalized()
			if flee_dir.length_squared() < 0.01:
				flee_dir = Vector2.LEFT
			_chupa_pos += flee_dir * CHUPA_FLEE_SPEED * delta
	else:
		var target_goat: Dictionary = {}
		var min_dist: float = 9999.0

		for goat: Dictionary in _goats:
			if not bool(goat["is_rescued"]) and str(goat["hidden_in_bush_id"]).is_empty():
				var d: float = (goat["pos"] as Vector2).distance_to(_chupa_pos)
				if d < min_dist:
					min_dist = d
					target_goat = goat

		if not target_goat.is_empty():
			var goat_pos: Vector2 = target_goat["pos"] as Vector2
			var dir: Vector2 = (goat_pos - _chupa_pos).normalized()
			_chupa_pos += dir * CHUPA_HUNT_SPEED * delta

			if min_dist < 32.0:
				is_attacking_goat = true
				target_goat["hp"] = float(target_goat["hp"]) - 25.0 * delta
				_set_status("🩸 O CHUPA-CABRA ESTÁ ATACANDO O %s! GRITE [ESPAÇO] PARA AFUGENTAR!" % str(target_goat["label"]), true)

				_rosnado_timer += delta
				if _rosnado_timer >= 0.7:
					_rosnado_timer = 0.0
					SoundManager.play_chupacabra_rosnado()
					SoundManager.play_berro_bode(true)
					JuiceManager.add_trauma(0.35)

					# Berro de pavor dispersa bodes proximos para outras moitas
					for other_goat: Dictionary in _goats:
						if str(other_goat["id"]) == str(target_goat["id"]):
							continue
						if bool(other_goat["is_rescued"]) or not str(other_goat["hidden_in_bush_id"]).is_empty():
							continue
						var dist_goats: float = (other_goat["pos"] as Vector2).distance_to(goat_pos)
						if dist_goats < 340.0:
							other_goat["flee_timer"] = 3.0
							var best_bush: Dictionary = _find_nearest_free_bush(other_goat["pos"] as Vector2, 0.0)
							if not best_bush.is_empty():
								other_goat["target_bush_id"] = str(best_bush["id"])

				if float(target_goat["hp"]) <= 0.0:
					target_goat["hp"] = 0.0
					_state_status = "FAILED"
					_fail_timer = 2.5
					_set_status("💀 UM BODE MORREU! Missão Falhou. Retornando ao Estúdio...", true)
					SoundManager.play_defeat_jingle()
					return

	_chupa_pos = Vector2(
		clampf(_chupa_pos.x, 40.0, MAP_WIDTH - 40.0),
		clampf(_chupa_pos.y, 40.0, MAP_HEIGHT - 40.0)
	)

	var tension: float = 0.9 if is_attacking_goat else (0.1 if _chupa_flee_timer > 0.0 else 0.3)
	SoundManager.set_music_tension(tension)


func _update_goats(delta: float) -> void:
	if _player == null:
		return

	var player_pos: Vector2 = _player.global_position
	var leashed_idx: int = 1

	for goat: Dictionary in _goats:
		if bool(goat["is_rescued"]) or not str(goat["hidden_in_bush_id"]).is_empty():
			continue

		var goat_pos: Vector2 = goat["pos"] as Vector2
		var dist_hero: float = player_pos.distance_to(goat_pos)

		# Entrou no Curral Central -> Resgatado!
		if (
			absf(goat_pos.x - CURRAL_POS.x) < CURRAL_SIZE.x * 0.5 - 15.0
			and absf(goat_pos.y - CURRAL_POS.y) < CURRAL_SIZE.y * 0.5 - 15.0
		):
			goat["is_rescued"] = true
			goat["is_leashed"] = false
			goat["target_bush_id"] = ""
			SoundManager.play_pickup()
			JuiceManager.emit_particles("sparkle", goat_pos, self, {"count": 8, "speed": 45.0})
			continue

		# Laçar com a corda
		if _has_rope and dist_hero < 75.0:
			if not bool(goat["is_leashed"]):
				SoundManager.play_berro_bode(false)
				JuiceManager.emit_particles("dust", goat_pos, self, {"count": 4, "speed": 20.0})
			goat["is_leashed"] = true
			goat["target_bush_id"] = ""

		if bool(goat["is_leashed"]):
			var follow_dist: float = float(leashed_idx) * 34.0
			leashed_idx += 1
			var target_pos: Vector2 = player_pos - _player_move_dir * follow_dist
			var to_target: Vector2 = target_pos - goat_pos
			if to_target.length() > 22.0:
				var move_step: Vector2 = to_target.normalized() * 200.0 * delta
				goat_pos += move_step
				goat["facing"] = "left" if move_step.x < 0.0 else "right"
		else:
			if float(goat["flee_timer"]) > 0.0:
				goat["flee_timer"] = maxf(0.0, float(goat["flee_timer"]) - delta)
				var target_bush: Dictionary = {}
				var target_id: String = str(goat["target_bush_id"])
				if not target_id.is_empty():
					var candidate: Dictionary = _find_bush_by_id(target_id)
					if not candidate.is_empty() and str(candidate["hiding_goat_id"]).is_empty() and str(candidate["type"]) != "cacto":
						target_bush = candidate

				if not target_bush.is_empty():
					var bush_pos: Vector2 = target_bush["pos"] as Vector2
					var to_bush: Vector2 = bush_pos - goat_pos
					if to_bush.length() > 0.01:
						var step: Vector2 = to_bush.normalized() * 230.0 * delta
						goat_pos += step
						goat["facing"] = "left" if step.x < 0.0 else "right"

					if goat_pos.distance_to(bush_pos) < float(target_bush["radius"]) * 0.8:
						goat["hidden_in_bush_id"] = str(target_bush["id"])
						target_bush["hiding_goat_id"] = str(goat["id"])
						goat["target_bush_id"] = ""
						goat["flee_timer"] = 0.0
						JuiceManager.emit_particles("leaf", bush_pos, self, {"count": 6, "speed": 30.0})
				else:
					var panic_dir: Vector2 = (goat_pos - player_pos).normalized()
					if panic_dir.length_squared() < 0.01:
						panic_dir = Vector2.RIGHT
					goat_pos += panic_dir * 210.0 * delta
					goat["facing"] = "left" if panic_dir.x < 0.0 else "right"
			else:
				goat["wander_timer"] = float(goat["wander_timer"]) - delta
				if float(goat["wander_timer"]) <= 0.0:
					goat["wander_timer"] = randf_range(1.0, 3.0)
					var vx: float = randf_range(-30.0, 30.0)
					var vy: float = randf_range(-30.0, 30.0)
					goat["vel"] = Vector2(vx, vy)
				var vel: Vector2 = goat["vel"] as Vector2
				goat_pos += vel * delta
				if absf(vel.x) > 1.0:
					goat["facing"] = "left" if vel.x < 0.0 else "right"

		goat["pos"] = Vector2(
			clampf(goat_pos.x, 40.0, MAP_WIDTH - 40.0),
			clampf(goat_pos.y, 40.0, MAP_HEIGHT - 40.0)
		)


func _check_victory() -> void:
	if _state_status != "PLAYING":
		return
	if _get_rescued_count() == 4:
		_state_status = "SUCCESS"
		GameManager.unlock_item("carimbo")
		SoundManager.play_victory_jingle()

		NarrativeOverlay.show_outro(
			{
				"phase_number": 1,
				"title": "O Ataque do Chupa-Cabra",
				"verses": PackedStringArray([
					"Com laço firme e grito de vaqueiro destemido,",
					"O rebanho sagrado foi salvo e protegido;",
					"O Fazendeiro grato lhe entrega a matriz entalhada:",
					"O Carimbo Mágico da lenda consagrada!",
				]),
				"item_reward": {
					"id": "carimbo",
					"name": "Carimbo Mágico",
					"icon": "🪓",
				},
			},
			func() -> void:
				GameManager.call_deferred("switch_scene", "STUDIO")
		)


func _draw() -> void:
	# 1. Piso de Terra Batida da Caatinga
	XiloDraw.draw_chao_terra_batida(self, Rect2(0.0, 0.0, MAP_WIDTH, MAP_HEIGHT))

	# 2. Iluminacao do Candeeiro (quando encontrado)
	if _has_lantern and _player != null:
		draw_circle(_player.global_position, 320.0, Color(0.996, 0.941, 0.541, 0.14))
		draw_circle(_player.global_position, 180.0, Color(0.996, 0.941, 0.541, 0.16))
		draw_arc(_player.global_position, 320.0, 0.0, TAU, 48, Color(0.996, 0.941, 0.541, 0.28), 2.0, true)

	# 3. Curral Central
	XiloDraw.draw_curral(self, CURRAL_POS, CURRAL_SIZE)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			Vector2(CURRAL_POS.x - 100.0, CURRAL_POS.y - 6.0),
			"[CURRAL CENTRAL]",
			HORIZONTAL_ALIGNMENT_CENTER,
			200.0,
			12,
			Color("#facc15")
		)

	# 4. Fazendeiro
	XiloDraw.draw_fazendeiro(self, FAZENDEIRO_POS, Vector2(36.0, 50.0))

	# 5. Moitas Homogeneas
	for bush: Dictionary in _bushes:
		var pos: Vector2 = bush["pos"] as Vector2
		var r: float = float(bush["radius"])
		var b_type: String = str(bush["type"])
		if bool(bush["is_searched"]):
			if b_type == "cacto":
				XiloDraw.draw_moita_cacto_espinhos(self, pos, r)
			elif b_type == "fruta":
				XiloDraw.draw_moita_fruta_regional(self, pos, r, true)
			else:
				XiloDraw.draw_moita(self, pos, r, true)
		else:
			XiloDraw.draw_moita(self, pos, r, false)

	# 6. Bodes
	for goat: Dictionary in _goats:
		if not str(goat["hidden_in_bush_id"]).is_empty():
			continue

		var g_pos: Vector2 = goat["pos"] as Vector2
		var is_rescued: bool = bool(goat["is_rescued"])
		var is_leashed: bool = bool(goat["is_leashed"])
		XiloDraw.draw_bode(self, g_pos, Vector2(36.0, 32.0), {
			"is_moving": not is_rescued,
			"time": _anim_time,
			"facing": str(goat["facing"]),
		})

		# Barra de HP
		var bar_w: float = 36.0
		var bar_h: float = 5.0
		var hp_ratio: float = clampf(float(goat["hp"]) / float(goat["max_hp"]), 0.0, 1.0)
		var hp_color: Color = Color("#22c55e") if hp_ratio > 0.5 else (Color("#eab308") if hp_ratio > 0.25 else Color("#ef4444"))
		var bar_rect: Rect2 = Rect2(g_pos.x - bar_w * 0.5, g_pos.y - 24.0, bar_w, bar_h)
		draw_rect(bar_rect, Color("#1e293b"), true)
		draw_rect(Rect2(bar_rect.position.x, bar_rect.position.y, bar_w * hp_ratio, bar_h), hp_color, true)
		draw_rect(bar_rect, Color.WHITE, false, 1.0)

		if is_rescued and font != null:
			draw_string(font, Vector2(g_pos.x - 32.0, g_pos.y + 24.0), "✓ Salvo", HORIZONTAL_ALIGNMENT_CENTER, 64.0, 10, Color("#4ade80"))
		elif is_leashed:
			if _player != null:
				draw_line(_player.global_position, g_pos, Color("#d97706"), 2.0, true)
			if font != null:
				draw_string(font, Vector2(g_pos.x - 32.0, g_pos.y + 24.0), "🪢 Preso", HORIZONTAL_ALIGNMENT_CENTER, 64.0, 10, Color("#facc15"))

	# 7. Chupa-Cabra
	if _chupa_active:
		XiloDraw.draw_chupa_cabra(self, _chupa_pos, Vector2(44.0, 44.0), {"time": _anim_time})
		if _chupa_flee_timer > 0.0 and font != null:
			draw_string(
				font,
				Vector2(_chupa_pos.x - 70.0, _chupa_pos.y - 28.0),
				"💨 FUGINDO! (%.1fs)" % _chupa_flee_timer,
				HORIZONTAL_ALIGNMENT_CENTER,
				140.0,
				10,
				Color("#38bdf8")
			)

	# 8. Onda Sonora de Grito / Aboio
	if (_is_aboio_active or _is_grito_active) and _sound_wave_radius > 0.0 and _player != null:
		var p_pos: Vector2 = _player.global_position
		var ring_col: Color = Color(0.937, 0.267, 0.267, 0.9) if _is_grito_active else Color(0.98, 0.8, 0.082, 0.8)
		var fill_col: Color = Color(0.937, 0.267, 0.267, 0.2) if _is_grito_active else Color(0.98, 0.8, 0.082, 0.15)
		draw_circle(p_pos, _sound_wave_radius, fill_col)
		draw_arc(p_pos, _sound_wave_radius, 0.0, TAU, 48, ring_col, 5.0 if _is_grito_active else 3.0, true)
		if font != null:
			draw_string(
				font,
				Vector2(p_pos.x - 110.0, p_pos.y - 36.0),
				"📢 ÊÊÊ-BOOOI! (GRITO FORTE)" if _is_grito_active else "📣 ABOIO",
				HORIZONTAL_ALIGNMENT_CENTER,
				220.0,
				12,
				Color("#fca5a5") if _is_grito_active else Color("#fde047")
			)


func _find_bush_by_id(bush_id: String) -> Dictionary:
	for bush: Dictionary in _bushes:
		if str(bush["id"]) == bush_id:
			return bush
	return {}


func _find_goat_by_id(goat_id: String) -> Dictionary:
	for goat: Dictionary in _goats:
		if str(goat["id"]) == goat_id:
			return goat
	return {}


func _find_nearest_free_bush(origin: Vector2, min_dist_threshold: float) -> Dictionary:
	var best_bush: Dictionary = {}
	var best_dist: float = 99999.0
	for bush: Dictionary in _bushes:
		if str(bush["hiding_goat_id"]).is_empty() and str(bush["type"]) != "cacto":
			var d: float = (bush["pos"] as Vector2).distance_to(origin)
			if d > min_dist_threshold and d < best_dist:
				best_dist = d
				best_bush = bush
	return best_bush


func _get_rescued_count() -> int:
	var count: int = 0
	for goat: Dictionary in _goats:
		if bool(goat["is_rescued"]):
			count += 1
	return count


func _set_status(msg: String, is_error: bool = false, is_success: bool = false) -> void:
	_status_message = msg
	DialogPanel.post_message(msg, {"is_error": is_error, "is_success": is_success})
	_refresh_hud()


func _on_player_hp_updated(_amount: int, _current_hp: int, _max_hp: int) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	if _title_label != null:
		_title_label.text = "🐐 FASE 1: O ATAQUE DO CHUPA-CABRA | Bodes Salvos: %d / 4" % _get_rescued_count()

	if _hp_label != null and _player != null and _player.health != null:
		var hp: int = _player.health.current_hp
		var max_hp: int = _player.health.max_hp
		var hearts: String = ""
		for i: int in range(max_hp):
			hearts += "❤️ " if i < hp else "🖤 "
		_hp_label.text = hearts.strip_edges()

	if _status_label != null:
		_status_label.text = _status_message
