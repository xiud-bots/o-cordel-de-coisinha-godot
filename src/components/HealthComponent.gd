class_name HealthComponent
extends Node

signal damaged(amount: int, current_hp: int, max_hp: int)
signal healed(amount: int, current_hp: int, max_hp: int)
signal died()
signal invulnerability_changed(is_invulnerable: bool)

@export var max_hp: int = 3
@export var invulnerability_duration: float = 5.0
@export var blink_interval: float = 0.08
@export var sync_with_game_manager: bool = false
@export var visual_target_path: NodePath = NodePath("")

var current_hp: int = 3
var _invuln_timer: float = 0.0
var _blink_timer: float = 0.0
var _visual_node: CanvasItem = null


func _ready() -> void:
	current_hp = max_hp
	if sync_with_game_manager:
		current_hp = clampi(GameManager.hp, 0, max_hp)
	_resolve_visual_target()


func _process(delta: float) -> void:
	if _invuln_timer <= 0.0:
		return

	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_blink_timer += delta
	if _blink_timer >= blink_interval:
		_blink_timer = 0.0
		_toggle_blink()

	if _invuln_timer <= 0.0:
		_end_invulnerability()


func take_damage(amount: int = 1) -> bool:
	## Aplica dano sem knockback e ativa 5.0s de i-frames com piscar visual.
	if amount <= 0 or current_hp <= 0 or is_invulnerable():
		return false

	current_hp = maxi(0, current_hp - amount)
	if sync_with_game_manager:
		GameManager.damage_player(amount)

	damaged.emit(amount, current_hp, max_hp)

	if current_hp <= 0:
		_end_invulnerability()
		died.emit()
		return true

	if invulnerability_duration > 0.0:
		_start_invulnerability()

	return true


func heal(amount: int = 1) -> void:
	if amount <= 0 or current_hp <= 0:
		return

	var prev_hp: int = current_hp
	current_hp = mini(max_hp, current_hp + amount)
	if sync_with_game_manager:
		GameManager.heal_player(amount)

	if current_hp != prev_hp:
		healed.emit(current_hp - prev_hp, current_hp, max_hp)


func reset_health() -> void:
	current_hp = max_hp
	_end_invulnerability()
	if sync_with_game_manager:
		GameManager.reset_hp()


func is_invulnerable() -> bool:
	return _invuln_timer > 0.0


func get_invulnerability_remaining() -> float:
	return _invuln_timer


func is_dead() -> bool:
	return current_hp <= 0


func set_visual_target(target: CanvasItem) -> void:
	_visual_node = target


func _resolve_visual_target() -> void:
	if not visual_target_path.is_empty():
		var node: Node = get_node_or_null(visual_target_path)
		if node is CanvasItem:
			_visual_node = node as CanvasItem
			return

	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var xilo: Node = parent_node.get_node_or_null("XiloSprite")
	if xilo is CanvasItem:
		_visual_node = xilo as CanvasItem
	elif parent_node is CanvasItem:
		_visual_node = parent_node as CanvasItem


func _start_invulnerability() -> void:
	_invuln_timer = invulnerability_duration
	_blink_timer = 0.0
	if _visual_node != null and "is_invulnerable" in _visual_node:
		_visual_node.set("is_invulnerable", true)
	invulnerability_changed.emit(true)


func _end_invulnerability() -> void:
	_invuln_timer = 0.0
	_blink_timer = 0.0
	if _visual_node != null:
		_visual_node.modulate.a = 1.0
		if "is_invulnerable" in _visual_node:
			_visual_node.set("is_invulnerable", false)
	invulnerability_changed.emit(false)


func _toggle_blink() -> void:
	if _visual_node == null:
		return
	_visual_node.modulate.a = 0.3 if _visual_node.modulate.a > 0.6 else 1.0
