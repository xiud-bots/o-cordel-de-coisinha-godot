extends Node

enum SceneId {
	STUDIO,
	STAGE_1_CHUPACABRA,
	STAGE_2_FULOZINHA,
	STAGE_3_RASGAMORTALHA,
	STAGE_4_BOTIJA,
	VICTORY,
}

const MAX_HP: int = 3

const ITEM_IDS: PackedStringArray = ["carimbo", "folha", "pena", "tinta"]
const BUSH_ITEM_IDS: PackedStringArray = ["corda", "candeeiro", "fumo"]

const DEFAULT_SCENE_PATHS: Dictionary = {
	"STUDIO": "res://src/levels/StudioScene.tscn",
	"STAGE_1_CHUPACABRA": "res://src/levels/Stage1_ChupaCabra.tscn",
	"STAGE_2_FULOZINHA": "res://src/levels/Stage2_Fulozinha.tscn",
	"STAGE_3_RASGAMORTALHA": "res://src/levels/Stage3_RasgaMortalha.tscn",
	"STAGE_4_BOTIJA": "res://src/levels/Stage4_Botija.tscn",
	"VICTORY": "res://src/levels/VictoryScene.tscn",
}

var current_scene_id: String = "STUDIO"
var player_name: String = "Coisinha"
var hp: int = MAX_HP
var is_paused: bool = false

var inventory: Dictionary = {
	"carimbo": false,
	"folha": false,
	"pena": false,
	"tinta": false,
}

var bush_items: Dictionary = {
	"corda": false,
	"candeeiro": false,
	"fumo": false,
}

var npc_first_contacts: Dictionary = {}
var stage_flags: Dictionary = {}
var scene_paths: Dictionary = {}


func _ready() -> void:
	scene_paths = DEFAULT_SCENE_PATHS.duplicate()
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_player_name(new_name: String) -> void:
	var trimmed: String = new_name.strip_edges()
	player_name = trimmed if not trimmed.is_empty() else "Coisinha"
	EventBus.player_name_changed.emit(player_name)


func unlock_item(item_id: String) -> void:
	if not inventory.has(item_id):
		push_warning("GameManager: item desconhecido '%s'" % item_id)
		return
	if bool(inventory[item_id]):
		return
	inventory[item_id] = true
	EventBus.item_unlocked.emit(item_id)
	EventBus.juice_shake_requested.emit(0.4)


func has_item(item_id: String) -> bool:
	return bool(inventory.get(item_id, false))


func get_unlocked_item_count() -> int:
	var count: int = 0
	for item_id: String in ITEM_IDS:
		if bool(inventory.get(item_id, false)):
			count += 1
	return count


func unlock_bush_item(item_id: String) -> void:
	if not bush_items.has(item_id):
		push_warning("GameManager: item de moita desconhecido '%s'" % item_id)
		return
	if bool(bush_items[item_id]):
		return
	bush_items[item_id] = true
	EventBus.bush_item_unlocked.emit(item_id)


func has_bush_item(item_id: String) -> bool:
	return bool(bush_items.get(item_id, false))


func damage_player(amount: int = 1) -> void:
	if amount <= 0 or hp <= 0:
		return
	hp = maxi(0, hp - amount)
	EventBus.player_hp_changed.emit(hp, MAX_HP)
	if hp == 0:
		EventBus.player_died.emit()


func heal_player(amount: int = 1) -> void:
	if amount <= 0:
		return
	hp = mini(MAX_HP, hp + amount)
	EventBus.player_hp_changed.emit(hp, MAX_HP)


func reset_hp() -> void:
	hp = MAX_HP
	EventBus.player_hp_changed.emit(hp, MAX_HP)


func is_first_contact(npc_id: String) -> bool:
	return not bool(npc_first_contacts.get(npc_id, false))


func mark_npc_contacted(npc_id: String) -> void:
	if not bool(npc_first_contacts.get(npc_id, false)):
		npc_first_contacts[npc_id] = true
		EventBus.npc_first_contact.emit(npc_id)


func consume_first_contact(npc_id: String) -> bool:
	var first: bool = is_first_contact(npc_id)
	if first:
		mark_npc_contacted(npc_id)
	return first


func set_stage_flag(key: String, value: Variant) -> void:
	stage_flags[key] = value


func get_stage_flag(key: String, default_value: Variant = null) -> Variant:
	return stage_flags.get(key, default_value)


func register_scene_path(scene_id: String, res_path: String) -> void:
	scene_paths[scene_id] = res_path


func switch_scene(scene_id: String) -> void:
	EventBus.scene_change_requested.emit(scene_id)
	current_scene_id = scene_id
	reset_stage_state()

	var target_path: String = str(scene_paths.get(scene_id, ""))
	if not target_path.is_empty() and ResourceLoader.exists(target_path):
		var err: Error = get_tree().change_scene_to_file(target_path)
		if err != OK:
			push_error("GameManager: falha ao trocar para cena '%s' (%s)" % [scene_id, target_path])
	EventBus.scene_changed.emit(scene_id)


func reset_stage_state() -> void:
	stage_flags.clear()
	reset_hp()
	set_paused(false)
	EventBus.stage_reset_requested.emit()


func reset_full_game() -> void:
	current_scene_id = "STUDIO"
	player_name = "Coisinha"
	for item_id: String in ITEM_IDS:
		inventory[item_id] = false
	for bush_id: String in BUSH_ITEM_IDS:
		bush_items[bush_id] = false
	npc_first_contacts.clear()
	reset_stage_state()
	EventBus.player_name_changed.emit(player_name)


func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	if get_tree() != null:
		get_tree().paused = paused
	EventBus.game_paused_changed.emit(is_paused)
