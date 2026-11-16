@tool
class_name XiloSprite
extends Node2D

## Node2D utilitário de Xilogravura para uso direto nas cenas do Godot 4.7.
## Desenha proceduralmente no _draw() delegando para XiloDraw conforme `kind`.

@export_enum(
	"coisinha",
	"bode",
	"chupa_cabra",
	"fulozinha",
	"rasga_mortalha",
	"fazendeiro",
	"beato",
	"violeiro",
	"morador_bebado",
	"moita",
	"moita_revelada",
	"moita_fruta",
	"moita_espinho",
	"cacto",
	"fruta",
	"pedra",
	"casa",
	"igreja",
	"curral",
	"prensa",
	"varal",
	"palco",
	"placa",
	"carimbo",
	"folha",
	"pena",
	"tinta",
	"botija",
	"galinha",
	"porco",
	"jumento",
	"cachorro",
	"moldura"
) var kind: String = "moita":
	set(value):
		kind = value
		queue_redraw()

@export var sprite_size: Vector2 = Vector2(48.0, 48.0):
	set(value):
		sprite_size = value
		queue_redraw()

@export var radius: float = 24.0:
	set(value):
		radius = value
		queue_redraw()

@export var searched: bool = false:
	set(value):
		searched = value
		queue_redraw()

@export var revealed_kind: String = "":
	set(value):
		revealed_kind = value
		queue_redraw()

@export var is_moving: bool = false:
	set(value):
		is_moving = value
		queue_redraw()

@export var is_invulnerable: bool = false:
	set(value):
		is_invulnerable = value
		queue_redraw()

@export_enum("right", "left") var facing: String = "right":
	set(value):
		facing = value
		queue_redraw()

@export var color_tint: Color = Color(0.0, 0.0, 0.0, 0.0):
	set(value):
		color_tint = value
		queue_redraw()

@export var animate: bool = true:
	set(value):
		animate = value
		set_process(animate and not Engine.is_editor_hint())

var _elapsed: float = 0.0


func _ready() -> void:
	set_process(animate and not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not animate:
		return
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var opts: Dictionary = {
		"time": _elapsed,
		"is_moving": is_moving,
		"is_invulnerable": is_invulnerable,
		"facing": facing,
		"color_tint": color_tint,
	}

	match kind:
		"coisinha":
			XiloDraw.draw_coisinha(self, Vector2.ZERO, sprite_size, opts)
		"bode":
			XiloDraw.draw_bode(self, Vector2.ZERO, sprite_size, opts)
		"chupa_cabra":
			XiloDraw.draw_chupa_cabra(self, Vector2.ZERO, sprite_size, opts)
		"fulozinha":
			XiloDraw.draw_cumade_fulozinha(self, Vector2.ZERO, sprite_size, opts)
		"rasga_mortalha":
			XiloDraw.draw_rasga_mortalha(self, Vector2.ZERO, sprite_size, opts)
		"fazendeiro":
			XiloDraw.draw_fazendeiro(self, Vector2.ZERO, sprite_size, opts)
		"beato":
			XiloDraw.draw_beato(self, Vector2.ZERO, sprite_size, opts)
		"violeiro":
			XiloDraw.draw_violeiro(self, Vector2.ZERO, sprite_size, opts)
		"morador_bebado":
			XiloDraw.draw_morador_bebado(self, Vector2.ZERO, sprite_size, opts)
		"moita":
			XiloDraw.draw_moita(self, Vector2.ZERO, radius, searched)
		"moita_revelada":
			XiloDraw.draw_moita_revelada(self, Vector2.ZERO, radius, revealed_kind)
		"moita_fruta":
			XiloDraw.draw_moita_fruta_regional(self, Vector2.ZERO, radius, searched)
		"moita_espinho":
			XiloDraw.draw_moita_cacto_espinhos(self, Vector2.ZERO, radius)
		"cacto":
			XiloDraw.draw_cacto_mandacaru(self, Vector2.ZERO, sprite_size)
		"fruta":
			var fruit_col: Color = color_tint if color_tint.a > 0.0 else XiloPalette.RED_ACCENT
			XiloDraw.draw_fruta(self, Vector2.ZERO, radius, fruit_col)
		"pedra":
			XiloDraw.draw_pedra(self, Vector2.ZERO, sprite_size)
		"casa":
			XiloDraw.draw_casa(self, Vector2.ZERO, sprite_size, opts)
		"igreja":
			XiloDraw.draw_igreja(self, Vector2.ZERO, sprite_size, opts)
		"curral":
			XiloDraw.draw_curral(self, Vector2.ZERO, sprite_size, opts)
		"prensa":
			XiloDraw.draw_prensa(self, Vector2.ZERO, sprite_size, not searched)
		"varal":
			XiloDraw.draw_varal(self, Vector2.ZERO, sprite_size, {})
		"palco":
			XiloDraw.draw_palco_violeiros(self, Vector2.ZERO, sprite_size, opts)
		"placa":
			XiloDraw.draw_placa_aviso(self, Vector2.ZERO, sprite_size, opts)
		"carimbo":
			XiloDraw.draw_item_carimbo(self, Vector2.ZERO, sprite_size.x)
		"folha":
			XiloDraw.draw_item_folha(self, Vector2.ZERO, sprite_size.x)
		"pena":
			XiloDraw.draw_item_pena(self, Vector2.ZERO, sprite_size.x)
		"tinta":
			XiloDraw.draw_item_tinta(self, Vector2.ZERO, sprite_size.x)
		"botija":
			XiloDraw.draw_item_botija(self, Vector2.ZERO, sprite_size.x)
		"galinha":
			XiloDraw.draw_galinha(self, Vector2.ZERO, sprite_size)
		"porco":
			XiloDraw.draw_porco(self, Vector2.ZERO, sprite_size)
		"jumento":
			XiloDraw.draw_jumento(self, Vector2.ZERO, sprite_size)
		"cachorro":
			XiloDraw.draw_cachorro(self, Vector2.ZERO, sprite_size)
		"moldura":
			XiloDraw.draw_moldura_cordel(self, Rect2(-sprite_size * 0.5, sprite_size))
		_:
			XiloDraw.draw_moita(self, Vector2.ZERO, radius, searched)
