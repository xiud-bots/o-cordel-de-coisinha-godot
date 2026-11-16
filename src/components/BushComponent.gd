class_name BushComponent
extends Node2D

signal bush_searched(bush_type: String, item_id: String)
signal cactus_damaged_player(player: Node2D)

@export_enum("empty", "item", "fruta", "cacto") var bush_type: String = "empty":
	set(value):
		bush_type = value
		_sync_visual()

@export var bush_radius: float = 24.0:
	set(value):
		bush_radius = value
		_sync_shapes()
		_sync_visual()

@export var item_id: String = "fumo"
@export var item_name: String = "Fumo de Rolo Aromático"
@export var item_icon: String = "🍂"
@export var item_dialog_lines: PackedStringArray = PackedStringArray([
	"Achei um item escondido na moita!"
])
@export var cactus_damage: int = 1

var is_searched: bool = false

@onready var _sprite: XiloSprite = $XiloSprite
@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _interact_shape: CollisionShape2D = $InteractableComponent/CollisionShape2D
@onready var _hazard_area: Area2D = $HazardArea
@onready var _hazard_shape: CollisionShape2D = $HazardArea/CollisionShape2D


func _ready() -> void:
	_sync_shapes()
	_sync_visual()

	if _interactable != null:
		_interactable.interacted.connect(_on_interacted)
	if _hazard_area != null:
		_hazard_area.body_entered.connect(_on_hazard_body_entered)

	EventBus.stage_reset_requested.connect(reset_bush)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)


func _exit_tree() -> void:
	is_searched = false


func reset_bush() -> void:
	is_searched = false
	if _interactable != null:
		_interactable.reset_interactable()
	_sync_visual()


func _on_scene_change_requested(_scene_id: String) -> void:
	reset_bush()


func _on_hazard_body_entered(body: Node2D) -> void:
	if bush_type != "cacto":
		return
	if body == null or not body.is_in_group("player"):
		return
	_trigger_cactus_damage(body)


func _on_interacted(interactor: Node2D) -> void:
	if is_searched:
		return

	is_searched = true
	_sync_visual()

	match bush_type:
		"item":
			_handle_item_found()
		"fruta":
			_handle_fruit_found(interactor)
		"cacto":
			_trigger_cactus_damage(interactor)
		_:
			SoundManager.play_cordel_folhear()
			JuiceManager.emit_particles("leaf", global_position, get_parent(), {"count": 6, "speed": 30.0})
			DialogPanel.post_message("🌿 Nada nessa moita além de folhas secas...")

	bush_searched.emit(bush_type, item_id if bush_type == "item" else "")


func _handle_item_found() -> void:
	if item_id in GameManager.BUSH_ITEM_IDS:
		GameManager.unlock_bush_item(item_id)
	elif item_id in GameManager.ITEM_IDS:
		GameManager.unlock_item(item_id)

	SoundManager.play_pickup()
	SoundManager.play_item_descobrir()
	JuiceManager.emit_particles("leaf", global_position, get_parent(), {"count": 12, "speed": 45.0})

	var lines: PackedStringArray = item_dialog_lines
	if lines.is_empty():
		lines = PackedStringArray(["Encontrei %s!" % item_name])

	DialogPanel.start_bush_item_dialog(item_id, item_name, item_icon, lines)


func _handle_fruit_found(interactor: Node2D) -> void:
	var health: HealthComponent = _find_health_component(interactor)
	if health != null and health.current_hp < health.max_hp:
		health.heal(1)
		DialogPanel.post_message("🍎 FRUTA REGIONAL! Você recuperou +1 HP!", {"is_success": true})
	else:
		DialogPanel.post_message("🍎 Fruta deliciosa da caatinga!", {"is_success": true})

	SoundManager.play_fruit_eat()
	JuiceManager.emit_particles("sparkle", global_position, get_parent(), {"count": 10, "speed": 40.0})


func _trigger_cactus_damage(player: Node2D) -> void:
	var health: HealthComponent = _find_health_component(player)
	if health == null:
		return
	if health.is_invulnerable() or health.is_dead():
		return

	# Auto-revela a moita ao causar dano
	is_searched = true
	_sync_visual()

	if health.take_damage(cactus_damage):
		SoundManager.play_hurt_cacto()
		SoundManager.play_grito()
		JuiceManager.add_trauma(0.45)
		var fx_pos: Vector2 = player.global_position if player != null else global_position
		JuiceManager.emit_particles("dust", fx_pos, get_parent(), {"count": 12, "speed": 70.0})
		DialogPanel.post_message("🌵 AI! ESPINHO DE CACTO! Você perdeu 1 HP e soltou um grito!", {"is_error": true})
		cactus_damaged_player.emit(player)


func _find_health_component(node: Node) -> HealthComponent:
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null


func _sync_visual() -> void:
	if _sprite == null:
		return
	_sprite.radius = bush_radius
	if not is_searched:
		_sprite.kind = "moita"
		_sprite.searched = false
		_sprite.revealed_kind = ""
	else:
		_sprite.searched = true
		if bush_type == "empty":
			_sprite.kind = "moita"
			_sprite.revealed_kind = ""
		else:
			_sprite.kind = "moita_revelada"
			_sprite.revealed_kind = bush_type


func _sync_shapes() -> void:
	if _interact_shape != null and _interact_shape.shape is CircleShape2D:
		(_interact_shape.shape as CircleShape2D).radius = bush_radius + 26.0
	if _hazard_shape != null and _hazard_shape.shape is CircleShape2D:
		(_hazard_shape.shape as CircleShape2D).radius = bush_radius + 8.0
