extends Node

const SAVE_PATH: String = "user://progress.cfg"


func _ready() -> void:
	load_progress()
	EventBus.item_unlocked.connect(_on_progress_changed)
	EventBus.player_name_changed.connect(_on_progress_changed)


func _on_progress_changed(_value: String) -> void:
	save_progress()


func save_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("player", "name", GameManager.player_name)
	for item_id: String in GameManager.ITEM_IDS:
		config.set_value("inventory", item_id, bool(GameManager.inventory[item_id]))

	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_warning("SaveManager: não foi possível salvar o progresso (erro %d)" % error)


func load_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	var saved_name: String = str(config.get_value("player", "name", "Coisinha")).strip_edges()
	GameManager.player_name = saved_name if not saved_name.is_empty() else "Coisinha"

	for item_id: String in GameManager.ITEM_IDS:
		GameManager.inventory[item_id] = bool(config.get_value("inventory", item_id, false))
