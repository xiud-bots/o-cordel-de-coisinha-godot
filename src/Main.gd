class_name MainRoot
extends Control

const CANONICAL_SCENES: Dictionary = {
	"STUDIO": "res://src/levels/StudioScene.tscn",
	"STAGE_1_CHUPACABRA": "res://src/levels/Stage1_ChupaCabra.tscn",
	"STAGE_2_FULOZINHA": "res://src/levels/Stage2_Fulozinha.tscn",
	"STAGE_3_RASGAMORTALHA": "res://src/levels/Stage3_RasgaMortalha.tscn",
	"STAGE_4_BOTIJA": "res://src/levels/Stage4_Botija.tscn",
	"VICTORY": "res://src/levels/VictoryScene.tscn",
}

var _active_scene: Node = null

@onready var _viewport_container: SubViewportContainer = $MainLayout/ViewportFrame/ViewportContainer
@onready var _game_viewport: SubViewport = $MainLayout/ViewportFrame/ViewportContainer/GameViewport
@onready var _dialog_dock: PanelContainer = $MainLayout/DialogDock
@onready var _status_label: Label = $MainLayout/DialogDock/MarginContainer/StatusLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _viewport_container != null:
		_viewport_container.process_mode = Node.PROCESS_MODE_ALWAYS
	if _game_viewport != null:
		_game_viewport.process_mode = Node.PROCESS_MODE_ALWAYS

	for scene_id: String in CANONICAL_SCENES.keys():
		GameManager.register_scene_path(scene_id, str(CANONICAL_SCENES[scene_id]))

	EventBus.scene_changed.connect(_on_scene_changed)
	_load_initial_scene()


func _load_initial_scene() -> void:
	var target_id: String = GameManager.current_scene_id
	if not CANONICAL_SCENES.has(target_id):
		target_id = "STUDIO"
	load_active_scene(target_id)


func load_active_scene(scene_id: String) -> void:
	var scene_path: String = str(CANONICAL_SCENES.get(scene_id, CANONICAL_SCENES["STUDIO"]))
	if not ResourceLoader.exists(scene_path):
		push_error("MainRoot: cena não encontrada '%s'" % scene_path)
		return

	if _active_scene != null and is_instance_valid(_active_scene):
		_active_scene.queue_free()
		_active_scene = null

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("MainRoot: falha ao carregar PackedScene '%s'" % scene_path)
		return

	_active_scene = packed.instantiate()
	_active_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	if _game_viewport != null:
		_game_viewport.add_child(_active_scene)
	_update_status_text(scene_id)


func get_active_scene() -> Node:
	return _active_scene


func get_game_viewport() -> SubViewport:
	return _game_viewport


func get_dialog_panel() -> Node:
	return DialogPanel


func get_narrative_overlay() -> Node:
	return NarrativeOverlay


func _on_scene_changed(scene_id: String) -> void:
	_update_status_text(scene_id)


func _update_status_text(scene_id: String) -> void:
	if _status_label != null:
		_status_label.text = "O Cordel de Coisinha — Cena Ativa: %s" % scene_id
