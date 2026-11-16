extends CanvasLayer

const LINE_DEBOUNCE_SECONDS: float = 0.3
const DIALOG_CLOSE_COOLDOWN: float = 0.25
const DEFAULT_TOAST_DURATION: float = 3.5
const MAX_TOAST_QUEUE: int = 3

var is_dialog_active: bool = false
var current_npc_id: String = ""
var dialog_cooldown: float = 0.0

var _current_lines: Array[Dictionary] = []
var _current_line_idx: int = 0
var _line_advance_cooldown: float = 0.0
var _on_dialog_complete: Callable = Callable()
var _is_blocking: bool = false

var _toast_queue: Array[Dictionary] = []
var _active_toast: Dictionary = {}
var _last_toast_text: String = ""

@onready var _panel: PanelContainer = $PanelContainer
@onready var _avatar_label: Label = $PanelContainer/MarginContainer/HBoxContainer/AvatarBox/AvatarLabel
@onready var _speaker_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TextColumn/SpeakerLabel
@onready var _body_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TextColumn/BodyLabel
@onready var _prompt_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TextColumn/FooterRow/PromptLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_panel.visible = false
	EventBus.dialogue_requested.connect(_on_dialogue_requested)


func _process(delta: float) -> void:
	if dialog_cooldown > 0.0:
		dialog_cooldown = maxf(0.0, dialog_cooldown - delta)

	if _line_advance_cooldown > 0.0:
		_line_advance_cooldown = maxf(0.0, _line_advance_cooldown - delta)

	if not is_dialog_active and not _active_toast.is_empty():
		_active_toast["timer"] = float(_active_toast.get("timer", 0.0)) + delta
		if float(_active_toast["timer"]) >= float(_active_toast.get("duration", DEFAULT_TOAST_DURATION)):
			_advance_toast()


func _input(event: InputEvent) -> void:
	if not is_dialog_active:
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released("interact"):
		get_viewport().set_input_as_handled()
		if _line_advance_cooldown <= 0.0:
			_advance_dialog()
		return

	if _is_blocking and (
		event.is_action_pressed("move_up")
		or event.is_action_pressed("move_down")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("shout")
		or event.is_action_pressed("aboio")
	):
		get_viewport().set_input_as_handled()


func start_dialog(
	npc_id: String,
	npc_name: String,
	npc_icon: String,
	subsequent_lines: Array[Dictionary],
	on_complete: Callable = Callable(),
	blocking: bool = false
) -> void:
	if dialog_cooldown > 0.0 or is_dialog_active:
		return

	clear_toast()
	current_npc_id = npc_id
	_on_dialog_complete = on_complete
	_current_line_idx = 0
	_line_advance_cooldown = LINE_DEBOUNCE_SECONDS
	_is_blocking = blocking
	is_dialog_active = true

	if GameManager.consume_first_contact(npc_id):
		_current_lines = [
			{
				"speaker": npc_name,
				"avatar_icon": npc_icon,
				"text": "Opa, forasteiro! Qual é o seu nome?",
				"is_glitch_name": false,
			},
			{
				"speaker": "Herói",
				"avatar_icon": "🤠",
				"text": "Meu nome é @#$!*&%#!",
				"is_glitch_name": true,
			},
			{
				"speaker": npc_name,
				"avatar_icon": npc_icon,
				"text": "Entendi foi nada!",
				"is_glitch_name": false,
			},
		]
		for line: Dictionary in subsequent_lines:
			_current_lines.append(line)
	else:
		_current_lines = subsequent_lines.duplicate(true)

	if _current_lines.is_empty():
		_close_dialog()
		return

	if _is_blocking:
		GameManager.set_paused(true)

	_panel.visible = true
	_render_current_line()
	EventBus.dialogue_started.emit(current_npc_id)


func start_bush_item_dialog(
	item_id: String,
	item_name: String,
	item_icon: String,
	lines: PackedStringArray,
	on_complete: Callable = Callable()
) -> void:
	if dialog_cooldown > 0.0 or is_dialog_active:
		return

	clear_toast()
	current_npc_id = "bush_%s" % item_id
	_on_dialog_complete = on_complete
	_current_line_idx = 0
	_line_advance_cooldown = LINE_DEBOUNCE_SECONDS
	_is_blocking = true
	is_dialog_active = true
	_current_lines.clear()

	for raw_text: String in lines:
		_current_lines.append({
			"speaker": item_name,
			"avatar_icon": item_icon,
			"text": raw_text,
			"is_glitch_name": false,
		})

	if _current_lines.is_empty():
		_close_dialog()
		return

	GameManager.set_paused(true)
	_panel.visible = true
	_render_current_line()
	EventBus.dialogue_started.emit(current_npc_id)


func post_message(message: String, options: Dictionary = {}) -> void:
	if is_dialog_active:
		return
	if message.is_empty() or message == _last_toast_text:
		return

	_last_toast_text = message
	var is_error: bool = bool(options.get("is_error", false))
	var is_success: bool = bool(options.get("is_success", false))
	var default_icon: String = "💀" if is_error else ("✨" if is_success else "📜")
	var toast: Dictionary = {
		"message": message,
		"icon": str(options.get("icon", default_icon)),
		"is_error": is_error,
		"is_success": is_success,
		"timer": 0.0,
		"duration": float(options.get("duration", DEFAULT_TOAST_DURATION)),
	}

	if _active_toast.is_empty():
		_active_toast = toast
		_render_active_toast()
	else:
		_toast_queue.append(toast)
		if _toast_queue.size() > MAX_TOAST_QUEUE:
			_toast_queue.pop_front()


func clear_toast() -> void:
	_active_toast.clear()
	_toast_queue.clear()
	_last_toast_text = ""
	if not is_dialog_active:
		_panel.visible = false


func _advance_dialog() -> void:
	if not is_dialog_active:
		return

	_current_line_idx += 1
	_line_advance_cooldown = LINE_DEBOUNCE_SECONDS

	if _current_line_idx >= _current_lines.size():
		_close_dialog()
	else:
		_render_current_line()


func _close_dialog() -> void:
	is_dialog_active = false
	_panel.visible = false
	dialog_cooldown = DIALOG_CLOSE_COOLDOWN

	if _is_blocking:
		GameManager.set_paused(false)
		_is_blocking = false

	var finished_npc: String = current_npc_id
	var callback: Callable = _on_dialog_complete
	current_npc_id = ""
	_on_dialog_complete = Callable()
	_current_lines.clear()
	_current_line_idx = 0

	EventBus.dialogue_ended.emit(finished_npc)
	if callback.is_valid():
		callback.call()


func _render_current_line() -> void:
	if _current_line_idx < 0 or _current_line_idx >= _current_lines.size():
		return

	var line: Dictionary = _current_lines[_current_line_idx]
	var speaker: String = str(line.get("speaker", "Narrador"))
	var avatar: String = str(line.get("avatar_icon", "📜"))
	var text: String = str(line.get("text", ""))
	var is_glitch: bool = bool(line.get("is_glitch_name", false))

	_avatar_label.text = avatar
	_speaker_label.text = "[ %s ]" % speaker.to_upper()
	_speaker_label.add_theme_color_override(
		"font_color",
		Color("#9a3412") if speaker == "Herói" else Color("#14100c")
	)

	_body_label.text = text
	_body_label.add_theme_color_override(
		"font_color",
		Color("#dc2626") if is_glitch else Color("#14100c")
	)

	var is_last: bool = _current_line_idx >= _current_lines.size() - 1
	_prompt_label.text = "Solte [E] para Fechar ■" if is_last else "Solte [E] para Avançar ▶"

	if is_glitch:
		EventBus.juice_shake_requested.emit(0.25)


func _advance_toast() -> void:
	if _toast_queue.is_empty():
		clear_toast()
		return
	_active_toast = _toast_queue.pop_front() as Dictionary
	_render_active_toast()


func _render_active_toast() -> void:
	if _active_toast.is_empty() or is_dialog_active:
		return

	var icon: String = str(_active_toast.get("icon", "📜"))
	var is_error: bool = bool(_active_toast.get("is_error", false))
	var is_success: bool = bool(_active_toast.get("is_success", false))
	var header: String = "ALERTA DO SERTÃO" if is_error else ("VITÓRIA" if is_success else "ORIENTAÇÃO DO CORDEL")

	_avatar_label.text = icon
	_speaker_label.text = "[ %s ]" % header
	_speaker_label.add_theme_color_override(
		"font_color",
		Color("#dc2626") if is_error else (Color("#15803d") if is_success else Color("#14100c"))
	)
	_body_label.text = str(_active_toast.get("message", ""))
	_body_label.add_theme_color_override("font_color", Color("#14100c"))
	_prompt_label.text = ("+%d na fila" % _toast_queue.size()) if not _toast_queue.is_empty() else ""
	_panel.visible = true


func _on_dialogue_requested(dialogue_data: Dictionary) -> void:
	var is_bush: bool = bool(dialogue_data.get("is_bush_item", false))
	var on_complete: Callable = dialogue_data.get("on_complete", Callable()) as Callable

	if is_bush:
		var item_id: String = str(dialogue_data.get("item_id", "item"))
		var item_name: String = str(dialogue_data.get("item_name", "Item do Sertão"))
		var item_icon: String = str(dialogue_data.get("item_icon", "🌿"))
		var raw_lines: Variant = dialogue_data.get("lines", PackedStringArray())
		var packed: PackedStringArray = PackedStringArray()
		if raw_lines is PackedStringArray:
			packed = raw_lines
		elif raw_lines is Array:
			for entry: Variant in raw_lines:
				packed.append(str(entry))
		start_bush_item_dialog(item_id, item_name, item_icon, packed, on_complete)
		return

	var npc_id: String = str(dialogue_data.get("npc_id", "npc"))
	var npc_name: String = str(dialogue_data.get("npc_name", "Morador"))
	var npc_icon: String = str(dialogue_data.get("npc_icon", "🧑"))
	var blocking: bool = bool(dialogue_data.get("blocking", false))
	var lines: Array[Dictionary] = []
	var raw_npc_lines: Variant = dialogue_data.get("lines", [])
	if raw_npc_lines is Array:
		for item: Variant in raw_npc_lines:
			if item is Dictionary:
				lines.append(item as Dictionary)
			else:
				lines.append({
					"speaker": npc_name,
					"avatar_icon": npc_icon,
					"text": str(item),
					"is_glitch_name": false,
				})
	start_dialog(npc_id, npc_name, npc_icon, lines, on_complete, blocking)
