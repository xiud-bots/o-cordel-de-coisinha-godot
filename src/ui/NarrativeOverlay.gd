extends CanvasLayer

const CLOSE_DEBOUNCE_SECONDS: float = 0.3

var is_overlay_active: bool = false
var is_intro_mode: bool = true

var _close_cooldown: float = 0.0
var _on_done: Callable = Callable()

@onready var _backdrop: ColorRect = $Backdrop
@onready var _header_label: Label = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/HeaderLabel
@onready var _title_label: Label = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var _verses_label: Label = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/VersesLabel
@onready var _objective_box: PanelContainer = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/ObjectiveBox
@onready var _objective_title: Label = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/ObjectiveBox/MarginContainer/VBoxContainer/ObjectiveTitle
@onready var _objective_body: Label = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/ObjectiveBox/MarginContainer/VBoxContainer/ObjectiveBody
@onready var _reward_label: Label = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/ObjectiveBox/MarginContainer/VBoxContainer/RewardLabel
@onready var _continue_button: Button = $Backdrop/CenterContainer/FolhetoPanel/MarginContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_backdrop.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	EventBus.narrative_leaflet_requested.connect(_on_narrative_leaflet_requested)


func _process(delta: float) -> void:
	if _close_cooldown > 0.0:
		_close_cooldown = maxf(0.0, _close_cooldown - delta)


func _input(event: InputEvent) -> void:
	if not is_overlay_active:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("shout"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released("interact") and _close_cooldown <= 0.0:
		get_viewport().set_input_as_handled()
		_close_overlay()


func show_intro(config: Dictionary, on_done: Callable = Callable()) -> void:
	is_intro_mode = true
	_on_done = on_done
	_close_cooldown = CLOSE_DEBOUNCE_SECONDS

	var phase_num: int = int(config.get("phase_number", 1))
	var title: String = str(config.get("title", "Conto do Sertão"))
	var subtitle: String = str(config.get("subtitle", ""))
	var objective: String = str(config.get("objective", ""))
	var verses: PackedStringArray = _extract_verses(config.get("verses", PackedStringArray()))
	var reward: Dictionary = config.get("item_reward", {}) as Dictionary
	var reward_icon: String = str(reward.get("icon", "📜"))
	var reward_name: String = str(reward.get("name", "Relíquia do Cordel"))

	_header_label.text = "FOLHETO DE CORDEL — CONTO %d" % phase_num
	_header_label.add_theme_color_override("font_color", Color("#14100c"))
	_title_label.text = "\"%s\"" % title.to_upper()
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
	_verses_label.text = "\n".join(verses)

	_objective_box.visible = true
	_objective_title.text = "🎯 MISSÃO DO CORDEL:"
	_objective_body.text = objective
	_objective_body.visible = not objective.is_empty()
	_reward_label.text = "Recompensa: %s %s" % [reward_icon, reward_name]
	_continue_button.text = "ENTRAR NO CONTO [E / Clique] ▶"

	_open_overlay()


func show_outro(config: Dictionary, on_done: Callable = Callable()) -> void:
	is_intro_mode = false
	_on_done = on_done
	_close_cooldown = CLOSE_DEBOUNCE_SECONDS

	var title: String = str(config.get("title", "Vitória no Sertão"))
	var verses: PackedStringArray = _extract_verses(config.get("verses", PackedStringArray()))
	var reward: Dictionary = config.get("item_reward", {}) as Dictionary
	var reward_icon: String = str(reward.get("icon", "✨"))
	var reward_name: String = str(reward.get("name", "Relíquia Consagrada"))

	_header_label.text = "✨ VITÓRIA & CONSAGRAÇÃO MÍSTICA ✨"
	_header_label.add_theme_color_override("font_color", Color("#15803d"))
	_title_label.text = "\"%s\"" % title.to_upper()
	_subtitle_label.text = "%s %s" % [reward_icon, reward_name]
	_subtitle_label.visible = true
	_verses_label.text = "\n".join(verses)

	_objective_box.visible = false
	_continue_button.text = "RETORNAR AO ESTÚDIO [E / Clique] 🏠"

	_open_overlay()


func _open_overlay() -> void:
	is_overlay_active = true
	_backdrop.visible = true
	GameManager.set_paused(true)


func _close_overlay() -> void:
	if not is_overlay_active:
		return
	is_overlay_active = false
	_backdrop.visible = false
	GameManager.set_paused(false)

	var cb: Callable = _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call()


func _on_continue_pressed() -> void:
	if _close_cooldown <= 0.0:
		_close_overlay()


func _on_narrative_leaflet_requested(title: String, verses: PackedStringArray) -> void:
	show_intro({
		"phase_number": 1,
		"title": title,
		"verses": verses,
	})


func _extract_verses(raw_verses: Variant) -> PackedStringArray:
	if raw_verses is PackedStringArray:
		return raw_verses
	var packed: PackedStringArray = PackedStringArray()
	if raw_verses is Array:
		for v: Variant in raw_verses:
			packed.append(str(v))
	return packed
