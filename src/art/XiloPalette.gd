class_name XiloPalette
extends RefCounted

## Paleta canônica de Xilogravura 2D & Papel Kraft de Cordel.
## Portada de src/renderer/xilogravura.ts (XILO_COLORS) para Godot 4.7.

# --- Núcleo Semântico (Papel Cordel, Nanquim, Sépia, Destaque, Perigo) ---
const PAPEL_CORDEL: Color = Color("#e6cfa8")
const PAPEL_CLARO: Color = Color("#f4ebd9")
const PAPEL_ESCURO: Color = Color("#c2a170")
const NANQUIM: Color = Color("#14100c")
const SEPIA: Color = Color("#5c3a21")
const SEPIA_ESCURO: Color = Color("#241b14")
const DESTAQUE: Color = Color("#d97706")
const PERIGO: Color = Color("#b91c1c")

# --- Aliases Canônicos (espelhando XILO_COLORS) ---
const BLACK: Color = Color("#14100c")
const DARK_WOOD: Color = Color("#241b14")
const KRAFT_PAPER: Color = Color("#e6cfa8")
const KRAFT_LIGHT: Color = Color("#f4ebd9")
const KRAFT_DARK: Color = Color("#c2a170")
const WHITE_HATCH: Color = Color("#fefefe")
const RED_ACCENT: Color = Color("#b91c1c")
const GOLD_ACCENT: Color = Color("#d97706")
const GREEN_ACCENT: Color = Color("#15803d")
const PURPLE_ACCENT: Color = Color("#7e22ce")
const CYAN_ACCENT: Color = Color("#0284c7")
const BROWN_WOOD: Color = Color("#5c3a21")
const DIRT_ROAD: Color = Color("#a07844")
const STONE_GREY: Color = Color("#475569")
const STONE_DARK: Color = Color("#334155")

# --- Tons Auxiliares de Cenário, Vegetação e Itens ---
const SHADOW_GROUND: Color = Color(0.0, 0.0, 0.0, 0.32)
const BUSH_GREEN: Color = Color("#14532d")
const BUSH_SEARCHED: Color = Color("#27272a")
const BUSH_THORN_GREEN: Color = Color("#1e3a1e")
const TERRA_BATIDA_BG: Color = Color("#261b11")
const TERRA_BATIDA_CRACK: Color = Color("#150e09")
const TERRA_BATIDA_STONE: Color = Color("#3a2b1c")
const LAJOTA_BG: Color = Color("#1e293b")
const LAJOTA_BORDER: Color = Color("#0f172a")
const MADEIRA_PISO: Color = Color("#291d13")
const MADEIRA_VEIO: Color = Color("#1a120b")
const MADEIRA_RUSTICA: Color = Color("#3b2615")
const MADEIRA_PLACA: Color = Color("#854d0e")
const CERAMICA_BARRO: Color = Color("#b45309")
const OURO_BRILHO: Color = Color("#fde047")
const TEXTO_DOURADO: Color = Color("#fef08a")
const ALERTA_AMARELO: Color = Color("#eab308")
const VERDE_PRENSA: Color = Color("#10b981")
const VERDE_PRENSA_BORDA: Color = Color("#34d399")
const GARRAFA_VERDE: Color = Color("#065f46")
const ROSA_PORCO: Color = Color("#f472b6")
const ROSA_FOCINHO: Color = Color("#ec4899")
const ROSA_ESCURO: Color = Color("#db2777")
const CINZA_JUMENTO: Color = Color("#78716c")
const CINZA_JUMENTO_ESCURO: Color = Color("#57534e")
const CINZA_PATAS: Color = Color("#44403c")
const BRANCO_GALINHA: Color = Color("#f8fafc")


static func get_named_color(color_name: String, fallback: Color = BLACK) -> Color:
	match color_name.to_lower().strip_edges():
		"papel_cordel", "kraft_paper":
			return PAPEL_CORDEL
		"papel_claro", "kraft_light":
			return PAPEL_CLARO
		"papel_escuro", "kraft_dark":
			return PAPEL_ESCURO
		"nanquim", "black":
			return NANQUIM
		"sepia", "brown_wood":
			return SEPIA
		"sepia_escuro", "dark_wood":
			return SEPIA_ESCURO
		"destaque", "gold_accent":
			return DESTAQUE
		"perigo", "red_accent":
			return PERIGO
		"white_hatch":
			return WHITE_HATCH
		"green_accent":
			return GREEN_ACCENT
		"purple_accent":
			return PURPLE_ACCENT
		"cyan_accent":
			return CYAN_ACCENT
		"dirt_road":
			return DIRT_ROAD
		"stone_grey":
			return STONE_GREY
		"stone_dark":
			return STONE_DARK
		_:
			return fallback
