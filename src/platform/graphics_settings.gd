extends Node
## Autoload "GraphicsSettings" : réglages graphiques du joueur, sauvegardés dans
## user://settings.cfg et appliqués au démarrage puis à chaque changement.
##
## Les réglages sont décrits une seule fois dans SETTINGS ; le menu Options
## (src/ui/options_menu.gd) construit ses lignes à partir de cette liste.
## Les effets de l'Environment et les ombres des lumières sont appliqués à chaque
## WorldEnvironment et Light3D qui entre dans l'arbre, quelle que soit la scène.

signal changed

const SAVE_PATH := "user://settings.cfg"
const SECTION := "graphics"
const CUSTOM := "custom"

## Description des réglages. type : "choice" (options = [[libellé, valeur], ...]),
## "toggle" ou "slider" (min, max, step ; affiché en % si percent).
const SETTINGS: Array[Dictionary] = [
	# --- Affichage
	{"key": "window_mode", "tab": "Affichage", "label": "Mode d'affichage", "type": "choice", "default": "windowed",
		"options": [["Fenêtré", "windowed"], ["Plein écran fenêtré", "borderless"], ["Plein écran", "fullscreen"]]},
	{"key": "resolution", "tab": "Affichage", "label": "Taille de la fenêtre", "type": "choice", "default": "1600x900",
		"options": [["1280 × 720", "1280x720"], ["1600 × 900", "1600x900"], ["1920 × 1080", "1920x1080"],
			["2560 × 1440", "2560x1440"], ["3840 × 2160", "3840x2160"]]},
	{"key": "vsync", "tab": "Affichage", "label": "Synchronisation verticale", "type": "choice", "default": "enabled",
		"options": [["Désactivée", "disabled"], ["Activée", "enabled"], ["Adaptative", "adaptive"], ["Mailbox", "mailbox"]]},
	{"key": "max_fps", "tab": "Affichage", "label": "Limite d'images par seconde", "type": "choice", "default": 0,
		"options": [["30", 30], ["60", 60], ["120", 120], ["144", 144], ["240", 240], ["Illimitée", 0]]},
	{"key": "brightness", "tab": "Affichage", "label": "Luminosité", "type": "slider", "default": 1.0,
		"min": 0.5, "max": 1.5, "step": 0.05, "percent": true},
	# --- Qualité
	{"key": "preset", "tab": "Qualité", "label": "Préréglage", "type": "choice", "default": "high",
		"options": [["Bas", "low"], ["Moyen", "medium"], ["Élevé", "high"], ["Ultra", "ultra"], ["Personnalisé", CUSTOM]]},
	{"key": "render_scale", "tab": "Qualité", "label": "Résolution du rendu 3D", "type": "slider", "default": 1.0,
		"min": 0.5, "max": 2.0, "step": 0.05, "percent": true},
	{"key": "upscaling", "tab": "Qualité", "label": "Mise à l'échelle", "type": "choice", "default": "fsr2",
		"options": [["Bilinéaire", "bilinear"], ["AMD FSR 1.0", "fsr"], ["AMD FSR 2.2", "fsr2"]]},
	{"key": "msaa", "tab": "Qualité", "label": "Anticrénelage MSAA", "type": "choice", "default": 2,
		"options": [["Désactivé", 0], ["2×", 1], ["4×", 2], ["8×", 3]]},
	{"key": "fxaa", "tab": "Qualité", "label": "Anticrénelage FXAA", "type": "toggle", "default": false},
	{"key": "taa", "tab": "Qualité", "label": "Anticrénelage temporel (TAA)", "type": "toggle", "default": false},
	{"key": "lod", "tab": "Qualité", "label": "Détail des modèles", "type": "choice", "default": 1.0,
		"options": [["Bas", 4.0], ["Moyen", 2.0], ["Élevé", 1.0], ["Ultra", 0.0]]},
	{"key": "debanding", "tab": "Qualité", "label": "Anti-bandes de couleur", "type": "toggle", "default": true},
	# --- Ombres
	{"key": "shadows", "tab": "Ombres", "label": "Ombres", "type": "toggle", "default": true},
	{"key": "shadow_size", "tab": "Ombres", "label": "Résolution des ombres", "type": "choice", "default": 4096,
		"options": [["1024", 1024], ["2048", 2048], ["4096", 4096], ["8192", 8192]]},
	{"key": "shadow_filter", "tab": "Ombres", "label": "Douceur des ombres", "type": "choice", "default": 3,
		"options": [["Nettes", 0], ["Très basse", 1], ["Basse", 2], ["Moyenne", 3], ["Haute", 4], ["Ultra", 5]]},
	# --- Effets
	{"key": "ssao", "tab": "Effets", "label": "Occlusion ambiante (SSAO)", "type": "choice", "default": 2,
		"options": [["Désactivée", -1], ["Très basse", 0], ["Basse", 1], ["Moyenne", 2], ["Haute", 3], ["Ultra", 4]]},
	{"key": "ssil", "tab": "Effets", "label": "Éclairage indirect (SSIL)", "type": "choice", "default": -1,
		"options": [["Désactivé", -1], ["Très bas", 0], ["Bas", 1], ["Moyen", 2], ["Haut", 3], ["Ultra", 4]]},
	{"key": "ssr", "tab": "Effets", "label": "Réflexions (SSR)", "type": "toggle", "default": true},
	{"key": "glow", "tab": "Effets", "label": "Halo lumineux (glow)", "type": "toggle", "default": true},
	{"key": "sdfgi", "tab": "Effets", "label": "Illumination globale (SDFGI)", "type": "toggle", "default": false},
	{"key": "volumetric_fog", "tab": "Effets", "label": "Brouillard volumétrique", "type": "toggle", "default": false},
]

## Valeurs imposées par chaque préréglage (les autres réglages ne bougent pas).
const PRESETS: Dictionary = {
	"low": {"render_scale": 0.75, "upscaling": "fsr", "msaa": 0, "fxaa": true, "taa": false, "lod": 4.0,
		"shadows": true, "shadow_size": 1024, "shadow_filter": 1, "ssao": -1, "ssil": -1, "ssr": false,
		"glow": false, "sdfgi": false, "volumetric_fog": false},
	"medium": {"render_scale": 1.0, "upscaling": "fsr2", "msaa": 1, "fxaa": false, "taa": false, "lod": 2.0,
		"shadows": true, "shadow_size": 2048, "shadow_filter": 2, "ssao": 1, "ssil": -1, "ssr": false,
		"glow": true, "sdfgi": false, "volumetric_fog": false},
	"high": {"render_scale": 1.0, "upscaling": "fsr2", "msaa": 2, "fxaa": false, "taa": false, "lod": 1.0,
		"shadows": true, "shadow_size": 4096, "shadow_filter": 3, "ssao": 2, "ssil": -1, "ssr": true,
		"glow": true, "sdfgi": false, "volumetric_fog": false},
	"ultra": {"render_scale": 1.0, "upscaling": "fsr2", "msaa": 3, "fxaa": false, "taa": true, "lod": 0.0,
		"shadows": true, "shadow_size": 8192, "shadow_filter": 5, "ssao": 4, "ssil": 2, "ssr": true,
		"glow": true, "sdfgi": false, "volumetric_fog": false},
}

const _WINDOW_MODES := {
	"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
	"borderless": DisplayServer.WINDOW_MODE_FULLSCREEN,
	"fullscreen": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
}
const _VSYNC := {
	"disabled": DisplayServer.VSYNC_DISABLED,
	"enabled": DisplayServer.VSYNC_ENABLED,
	"adaptive": DisplayServer.VSYNC_ADAPTIVE,
	"mailbox": DisplayServer.VSYNC_MAILBOX,
}
const _UPSCALING := {
	"bilinear": Viewport.SCALING_3D_MODE_BILINEAR,
	"fsr": Viewport.SCALING_3D_MODE_FSR,
	"fsr2": Viewport.SCALING_3D_MODE_FSR2,
}

var values: Dictionary = {}
var _headless: bool = false


func _ready() -> void:
	values = defaults()
	values.merge(load_values(SAVE_PATH), true)
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	get_tree().node_added.connect(_on_node_added)
	apply_all()


# --- Données (sans effet de bord, testables) ---------------------------------------

static func defaults() -> Dictionary:
	var out := {}
	for s in SETTINGS:
		out[s.key] = s.default
	return out


static func spec(key: String) -> Dictionary:
	for s in SETTINGS:
		if s.key == key:
			return s
	return {}


## Ramène [param value] à une valeur permise pour [param key], ou null si impossible.
static func sanitize(key: String, value: Variant) -> Variant:
	var s := spec(key)
	if s.is_empty():
		return null
	match s.type:
		"toggle":
			return bool(value) if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else null
		"slider":
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
				return null
			return clampf(float(value), s.min, s.max)
		"choice":
			for opt: Array in s.options:
				if opt[1] == value or (typeof(opt[1]) in [TYPE_INT, TYPE_FLOAT] and typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_equal_approx(float(opt[1]), float(value))):
					return opt[1]
	return null


## Lit les réglages sauvegardés en ignorant tout ce qui est inconnu ou invalide.
static func load_values(path: String) -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {}
	if cfg.load(path) != OK or not cfg.has_section(SECTION):
		return out
	for key in cfg.get_section_keys(SECTION):
		var v: Variant = sanitize(key, cfg.get_value(SECTION, key))
		if v != null:
			out[key] = v
	return out


static func save_values(path: String, vals: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	for key: String in vals.keys():
		cfg.set_value(SECTION, key, vals[key])
	return cfg.save(path)


## Applique un préréglage à [param vals] (modifié en place).
static func apply_preset_to(vals: Dictionary, preset: String) -> void:
	vals["preset"] = preset
	if PRESETS.has(preset):
		vals.merge(PRESETS[preset], true)


# --- Modification ------------------------------------------------------------------

## Change un réglage, sauvegarde et applique. Choisir un préréglage règle tous les
## paramètres de qualité ; toucher à l'un d'eux passe en « Personnalisé ».
func set_value(key: String, value: Variant) -> void:
	var v: Variant = sanitize(key, value)
	if v == null:
		push_warning("GraphicsSettings : valeur refusée pour %s : %s" % [key, value])
		return
	if key == "preset":
		apply_preset_to(values, v)
	else:
		values[key] = v
		if _in_presets(key):
			values["preset"] = CUSTOM
	save_values(SAVE_PATH, values)
	if not _headless:
		apply_all()
	changed.emit()


func reset_to_defaults() -> void:
	values = defaults()
	save_values(SAVE_PATH, values)
	if not _headless:
		apply_all()
	changed.emit()


static func _in_presets(key: String) -> bool:
	return (PRESETS["high"] as Dictionary).has(key)


# --- Application -------------------------------------------------------------------

func apply_all() -> void:
	_apply_display()
	_apply_rendering()
	for env in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_environment((env as WorldEnvironment).environment)
	for light in get_tree().root.find_children("*", "Light3D", true, false):
		_apply_light(light as Light3D)


func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		# Différé : l'environment peut être affecté juste après l'entrée dans l'arbre.
		_apply_world_environment.call_deferred(node as WorldEnvironment)
	elif node is Light3D:
		_apply_light.call_deferred(node as Light3D)


func _apply_display() -> void:
	var mode: int = _WINDOW_MODES[values.window_mode]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		var parts: PackedStringArray = String(values.resolution).split("x")
		var size := Vector2i(parts[0].to_int(), parts[1].to_int())
		var screen := DisplayServer.screen_get_usable_rect().size
		size = size.min(screen)
		if DisplayServer.window_get_size() != size:
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect().position + (screen - size) / 2)
	DisplayServer.window_set_vsync_mode(_VSYNC[values.vsync])
	Engine.max_fps = int(values.max_fps)


func _apply_rendering() -> void:
	var vp := get_tree().root
	vp.msaa_3d = int(values.msaa) as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if values.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = values.taa
	vp.use_debanding = values.debanding
	vp.scaling_3d_mode = _UPSCALING[values.upscaling]
	vp.scaling_3d_scale = float(values.render_scale)
	vp.mesh_lod_threshold = float(values.lod)
	var size := int(values.shadow_size)
	vp.positional_shadow_atlas_size = size
	RenderingServer.directional_shadow_atlas_set_size(size, true)
	var filter := int(values.shadow_filter) as RenderingServer.ShadowQuality
	RenderingServer.directional_soft_shadow_filter_set_quality(filter)
	RenderingServer.positional_soft_shadow_filter_set_quality(filter)
	var ssao := int(values.ssao)
	if ssao >= 0:
		RenderingServer.environment_set_ssao_quality(ssao as RenderingServer.EnvironmentSSAOQuality, ssao < 3, 0.5, 2, 50.0, 300.0)
	var ssil := int(values.ssil)
	if ssil >= 0:
		RenderingServer.environment_set_ssil_quality(ssil as RenderingServer.EnvironmentSSILQuality, ssil < 3, 0.5, 4, 50.0, 300.0)


func _apply_world_environment(node: WorldEnvironment) -> void:
	if is_instance_valid(node):
		_apply_environment(node.environment)


func _apply_environment(env: Environment) -> void:
	if env == null:
		return
	env.ssao_enabled = int(values.ssao) >= 0
	env.ssil_enabled = int(values.ssil) >= 0
	env.ssr_enabled = values.ssr
	env.glow_enabled = values.glow
	env.sdfgi_enabled = values.sdfgi
	env.volumetric_fog_enabled = values.volumetric_fog
	env.adjustment_enabled = true
	env.adjustment_brightness = float(values.brightness)


## Les lumières gardent leur choix d'origine (une bougie sans ombre reste sans ombre) ;
## le réglage « Ombres » ne fait que les couper toutes.
func _apply_light(light: Light3D) -> void:
	if not is_instance_valid(light):
		return
	if not light.has_meta("_casts_shadow"):
		light.set_meta("_casts_shadow", light.shadow_enabled)
	light.shadow_enabled = bool(light.get_meta("_casts_shadow")) and values.shadows
