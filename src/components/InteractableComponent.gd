class_name InteractableComponent
extends Area2D

signal interacted(interactor: Node2D)
signal focus_gained(interactor: Node2D)
signal focus_lost(interactor: Node2D)

@export var interact_id: String = ""
@export var prompt_text: String = "Interagir [E]"
@export var one_shot: bool = false
@export var enabled: bool = true
@export var interact_priority: int = 0

var _has_triggered: bool = false
var _is_focused: bool = false


func _ready() -> void:
	if collision_layer == 0:
		collision_layer = 8 # Layer 4: interactable
	if collision_mask == 0:
		collision_mask = 2 # Layer 2: player
	monitoring = true
	monitorable = true


func can_interact(_interactor: Node2D = null) -> bool:
	if not enabled:
		return false
	if one_shot and _has_triggered:
		return false
	return true


func interact(interactor: Node2D = null) -> bool:
	if not can_interact(interactor):
		return false
	if one_shot:
		_has_triggered = true
	interacted.emit(interactor)
	return true


func reset_interactable() -> void:
	_has_triggered = false
	enabled = true


func set_focused(focused: bool, interactor: Node2D = null) -> void:
	if _is_focused == focused:
		return
	_is_focused = focused
	if _is_focused:
		focus_gained.emit(interactor)
	else:
		focus_lost.emit(interactor)


func is_focused() -> bool:
	return _is_focused
