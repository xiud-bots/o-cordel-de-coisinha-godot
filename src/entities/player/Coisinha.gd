class_name Coisinha
extends CharacterBody2D

signal shouted(world_pos: Vector2)
signal aboio_performed(world_pos: Vector2)
signal interacted(target: InteractableComponent)
signal controls_inversion_changed(is_inverted: bool)

const STEP_INTERVAL_SECONDS: float = 0.32
const SHOUT_COOLDOWN_SECONDS: float = 0.8
const ABOIO_COOLDOWN_SECONDS: float = 1.2

@export var move_speed: float = 230.0
@export var controls_inverted: bool = false:
	set(value):
		if controls_inverted == value:
			return
		controls_inverted = value
		controls_inversion_changed.emit(controls_inverted)

var facing: String = "right"

var _step_timer: float = 0.0
var _shout_cooldown: float = 0.0
var _aboio_cooldown: float = 0.0
var _focused_interactable: InteractableComponent = null

@onready var sprite: XiloSprite = $XiloSprite
@onready var health: HealthComponent = $HealthComponent
@onready var interaction_area: Area2D = $InteractionArea
@onready var shout_area: Area2D = $ShoutArea


func _ready() -> void:
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if health != null:
		health.set_visual_target(sprite)

	if interaction_area != null:
		interaction_area.area_entered.connect(_on_interaction_area_changed)
		interaction_area.area_exited.connect(_on_interaction_area_changed)


func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)

	if _is_input_blocked():
		velocity = Vector2.ZERO
		if sprite != null:
			sprite.is_moving = false
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if controls_inverted:
		input_dir = -input_dir

	velocity = input_dir * move_speed
	move_and_slide()

	var is_moving_now: bool = input_dir.length_squared() > 0.01
	if is_moving_now:
		if input_dir.x < -0.1:
			facing = "left"
		elif input_dir.x > 0.1:
			facing = "right"

		_step_timer += delta
		if _step_timer >= STEP_INTERVAL_SECONDS:
			_step_timer = 0.0
			SoundManager.play_passos()
			JuiceManager.emit_particles(
				"dust",
				global_position + Vector2(0.0, 18.0),
				get_parent(),
				{"count": 3, "speed": 25.0}
			)
	else:
		_step_timer = STEP_INTERVAL_SECONDS * 0.5

	if sprite != null:
		sprite.facing = facing
		sprite.is_moving = is_moving_now

	_update_focused_interactable()


func _unhandled_input(event: InputEvent) -> void:
	if _is_input_blocked():
		return

	if event.is_action_pressed("shout") and _shout_cooldown <= 0.0:
		get_viewport().set_input_as_handled()
		perform_shout()
		return

	if event.is_action_pressed("aboio") and _aboio_cooldown <= 0.0:
		get_viewport().set_input_as_handled()
		perform_aboio()
		return

	if event.is_action_released("interact") and DialogPanel.dialog_cooldown <= 0.0:
		get_viewport().set_input_as_handled()
		try_interact()


func perform_shout() -> void:
	_shout_cooldown = SHOUT_COOLDOWN_SECONDS
	SoundManager.play_grito()
	JuiceManager.add_trauma(0.18)
	JuiceManager.emit_particles(
		"dust",
		global_position,
		get_parent(),
		{"count": 10, "speed": 55.0}
	)
	shouted.emit(global_position)


func perform_aboio() -> void:
	_aboio_cooldown = ABOIO_COOLDOWN_SECONDS
	SoundManager.play_aboio()
	JuiceManager.emit_particles(
		"note",
		global_position + Vector2(0.0, -16.0),
		get_parent(),
		{"count": 6, "speed": 35.0}
	)
	aboio_performed.emit(global_position)


func try_interact() -> bool:
	var target: InteractableComponent = _find_best_interactable()
	if target == null:
		return false
	if target.interact(self):
		interacted.emit(target)
		return true
	return false


func set_controls_inverted(inverted: bool) -> void:
	controls_inverted = inverted


func take_damage(amount: int = 1) -> bool:
	if health == null:
		return false
	return health.take_damage(amount)


func heal(amount: int = 1) -> void:
	if health != null:
		health.heal(amount)


func is_invulnerable() -> bool:
	return health != null and health.is_invulnerable()


func _is_input_blocked() -> bool:
	return DialogPanel.is_dialog_active or NarrativeOverlay.is_overlay_active or GameManager.is_paused


func _update_cooldowns(delta: float) -> void:
	if _shout_cooldown > 0.0:
		_shout_cooldown = maxf(0.0, _shout_cooldown - delta)
	if _aboio_cooldown > 0.0:
		_aboio_cooldown = maxf(0.0, _aboio_cooldown - delta)


func _on_interaction_area_changed(_area: Area2D) -> void:
	_update_focused_interactable()


func _update_focused_interactable() -> void:
	var best: InteractableComponent = _find_best_interactable()
	if best == _focused_interactable:
		return
	if is_instance_valid(_focused_interactable):
		_focused_interactable.set_focused(false, self)
	_focused_interactable = best
	if is_instance_valid(_focused_interactable):
		_focused_interactable.set_focused(true, self)


func _find_best_interactable() -> InteractableComponent:
	if interaction_area == null:
		return null

	var best: InteractableComponent = null
	var best_score: float = -INF

	for area: Area2D in interaction_area.get_overlapping_areas():
		if not (area is InteractableComponent):
			continue
		var candidate: InteractableComponent = area as InteractableComponent
		if not candidate.can_interact(self):
			continue

		var dist: float = global_position.distance_to(candidate.global_position)
		var score: float = float(candidate.interact_priority) * 1000.0 - dist
		if score > best_score:
			best_score = score
			best = candidate

	return best
