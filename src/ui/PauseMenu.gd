extends CanvasLayer

var _is_open: bool = false

var _backdrop: ColorRect
var _resume_button: Button
var _studio_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_build_ui()
	_backdrop.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	if _is_open:
		get_viewport().set_input_as_handled()
		_close()
	elif _can_open():
		get_viewport().set_input_as_handled()
		_open()


func _can_open() -> bool:
	return (
		not GameManager.is_paused
		and not DialogPanel.is_dialog_active
		and not NarrativeOverlay.is_overlay_active
		and GameManager.current_scene_id != "VICTORY"
	)


func _open() -> void:
	_is_open = true
	_studio_button.visible = GameManager.current_scene_id != "STUDIO"
	_backdrop.visible = true
	GameManager.set_paused(true)
	SoundManager.play_ui_click()
	_resume_button.grab_focus()


func _close() -> void:
	_is_open = false
	_backdrop.visible = false
	GameManager.set_paused(false)


func _on_resume_pressed() -> void:
	SoundManager.play_ui_click()
	_close()


func _on_studio_pressed() -> void:
	SoundManager.play_ui_click()
	_close()
	GameManager.call_deferred("switch_scene", "STUDIO")


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	_backdrop.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: PanelContainer = PanelContainer.new()
	panel.theme = load("res://src/ui/cordel_theme.tres") as Theme
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "⏸ PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_add_volume_row(box, "🎵 Música", SoundManager.get_bgm_volume(), SoundManager.set_bgm_volume)
	_add_volume_row(box, "🔊 Efeitos", SoundManager.get_sfx_volume(), SoundManager.set_sfx_volume)

	_resume_button = Button.new()
	_resume_button.text = "Continuar [Esc]"
	_resume_button.pressed.connect(_on_resume_pressed)
	box.add_child(_resume_button)

	_studio_button = Button.new()
	_studio_button.text = "Voltar ao Estúdio"
	_studio_button.pressed.connect(_on_studio_pressed)
	box.add_child(_studio_button)

	var hint: Label = Label.new()
	hint.text = "Mover: WASD/Setas · Interagir: E · Gritar: Espaço · Aboio: Q/F · Som: M"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)
	
func _add_volume_row(parent: Control, label_text: String, start_value: float, on_change: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = start_value
	slider.custom_minimum_size = Vector2(0.0, 24.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
