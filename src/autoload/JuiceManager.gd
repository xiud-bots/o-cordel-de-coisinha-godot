extends Node

const MAX_SHAKE_OFFSET: float = 18.0
const TRAUMA_DECAY_RATE: float = 1.6

const PARTICLE_COLORS: Dictionary = {
	"dust": Color("#c2a170"),
	"leaf": Color("#15803d"),
	"sparkle": Color("#facc15"),
	"sweat": Color("#38bdf8"),
	"woodchip": Color("#5c3a21"),
	"note": Color("#eab308"),
}

var trauma: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO

var _shake_time: float = 0.0
var _hitstop_active: bool = false
var _hitstop_token: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.juice_shake_requested.connect(_on_shake_requested)
	EventBus.juice_hitstop_requested.connect(_on_hitstop_requested)


func _process(delta: float) -> void:
	_update_shake(delta)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func trigger_hitstop(duration: float = 0.06, time_scale_value: float = 0.05) -> void:
	if duration <= 0.0:
		return
	_hitstop_token += 1
	var current_token: int = _hitstop_token
	_hitstop_active = true
	Engine.time_scale = clampf(time_scale_value, 0.0, 1.0)

	var timer: SceneTreeTimer = get_tree().create_timer(duration, true, false, true)
	await timer.timeout
	if current_token == _hitstop_token:
		Engine.time_scale = 1.0
		_hitstop_active = false


func is_hitstop_active() -> bool:
	return _hitstop_active


func emit_particles(
	particle_type: String,
	world_pos: Vector2,
	parent: Node = null,
	options: Dictionary = {}
) -> CPUParticles2D:
	var target_parent: Node = parent
	if target_parent == null and get_tree() != null:
		target_parent = get_tree().current_scene
	if target_parent == null:
		return null

	var count: int = int(options.get("count", 8))
	var speed: float = float(options.get("speed", 45.0))
	var spread_deg: float = float(options.get("spread_deg", 180.0))
	var lifetime: float = float(options.get("life", 0.55))
	var scale_val: float = float(options.get("size", 3.0))
	var direction_vec: Vector2 = options.get("direction", Vector2.UP) as Vector2
	var color_val: Color = options.get("color", PARTICLE_COLORS.get(particle_type, Color("#d4a373"))) as Color

	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = world_pos
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = maxi(1, count)
	particles.lifetime = maxf(0.1, lifetime)
	particles.direction = direction_vec.normalized() if direction_vec.length_squared() > 0.0 else Vector2.UP
	particles.spread = spread_deg
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed * 1.25
	particles.gravity = Vector2(0.0, 60.0) if particle_type in ["sweat", "woodchip"] else Vector2.ZERO
	particles.damping_min = 40.0
	particles.damping_max = 70.0
	particles.scale_amount_min = maxf(1.0, scale_val * 0.7)
	particles.scale_amount_max = maxf(1.0, scale_val * 1.3)
	particles.color = color_val

	target_parent.add_child(particles)
	particles.emitting = true

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime + 0.15, true, false, true)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
	return particles


func _update_shake(delta: float) -> void:
	_shake_time += delta * 35.0
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - TRAUMA_DECAY_RATE * delta)
		var shake_power: float = trauma * trauma
		shake_offset = Vector2(
			sin(_shake_time * 1.7) * MAX_SHAKE_OFFSET * shake_power,
			cos(_shake_time * 2.3) * MAX_SHAKE_OFFSET * shake_power
		)
	else:
		shake_offset = Vector2.ZERO

	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam != null:
		cam.offset = shake_offset


func _on_shake_requested(amount: float) -> void:
	add_trauma(amount)


func _on_hitstop_requested(duration: float) -> void:
	trigger_hitstop(duration)
