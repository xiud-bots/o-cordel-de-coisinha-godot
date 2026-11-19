extends CanvasLayer

const ITEMS: Array = [
	{"id": "carimbo", "icon": "🪓"},
	{"id": "folha", "icon": "📄"},
	{"id": "pena", "icon": "🪶"},
	{"id": "tinta", "icon": "🖋️"},
]

const COLLECTED_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const MISSING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)

var _panel: PanelContainer
var _labels: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build_ui()


func _process(_delta: float) -> void:
	var in_stage: bool = GameManager.current_scene_id.begins_with("STAGE_")
	_panel.visible = in_stage
	if not in_stage:
		return

	for item_id: String in _labels.keys():
		var label: Label = _labels[item_id] as Label
		label.modulate = COLLECTED_COLOR if GameManager.has_item(item_id) else MISSING_COLOR


func _build_ui() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.117647, 0.160784, 0.231373, 0.9)
	style.border_color = Color(0.831373, 0.686275, 0.215686, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0

	_panel = PanelContainer.new()
	_panel.position = Vector2(24.0, 54.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	for item: Dictionary in ITEMS:
		var label: Label = Label.new()
		label.text = str(item["icon"])
		label.add_theme_font_size_override("font_size", 18)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		_labels[str(item["id"])] = label
