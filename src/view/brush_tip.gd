class_name BrushTip
extends RefCounted
## Forme de la pointe du pinceau, commune à tous les outils qui touchent la figurine.
## Coordonnées de la pointe : x, y dans [-1, 1] sur le plan tangent à la surface (x = largeur
## de la pointe, perpendiculaire au trait quand elle le suit). weight() donne la quantité
## de peinture déposée (0 à 1) ; le même calcul dessine le curseur et les icônes.

enum Shape { ROUND, SQUARE, DIAMOND, FLAT, SPONGE, SPRAY, BRISTLE }

## [nom, aide]
const SHAPES := {
	Shape.ROUND: ["Rond", "Pointe ronde classique"],
	Shape.SQUARE: ["Carré", "Pointe carrée, bords nets"],
	Shape.DIAMOND: ["Losange", "Pointe en losange"],
	Shape.FLAT: ["Plat", "Pinceau plat : large en travers du trait, fin dans le sens du trait"],
	Shape.SPONGE: ["Éponge", "Tamponne une texture irrégulière (usure, rouille, pierre)"],
	Shape.SPRAY: ["Moucheté", "Projette des points épars (taches, poussière, sang)"],
	Shape.BRISTLE: ["Poils", "Laisse les traces des poils du pinceau dans le sens du trait"],
}
## Les formes allongées sont faites pour suivre le trait.
const FOLLOWS_STROKE := [Shape.FLAT, Shape.BRISTLE]

var shape: Shape = Shape.ROUND
## 0 : bord très doux ; 1 : bord net.
var hardness: float = 0.5
## Écrasement de la pointe dans le sens y (1 = pas d'écrasement).
var roundness: float = 1.0


## Quantité de peinture au point (x, y) de la pointe. [noise] dans [0, 1] : tirage propre
## au sommet (texture de l'éponge, points du moucheté) ; [bristle_seed] : décalage des poils.
func weight(x: float, y: float, noise: float, bristle_seed: int = 0) -> float:
	var yy := y / maxf(roundness, 0.05)
	var t: float
	match shape:
		Shape.SQUARE:
			t = maxf(absf(x), absf(yy))
		Shape.DIAMOND:
			t = absf(x) + absf(yy)
		Shape.FLAT:
			t = maxf(absf(x), absf(yy) * 4.0)
		_:
			t = sqrt(x * x + yy * yy)
	if t > 1.0:
		return 0.0
	var w := 1.0 if t <= hardness else 1.0 - smoothstep(hardness, 1.0, t)
	match shape:
		Shape.SPONGE:
			w *= smoothstep(0.45, 0.65, noise)
		Shape.SPRAY:
			# Points plus serrés au centre qu'au bord.
			w = 1.0 if noise < 0.3 * (1.0 - 0.7 * t) else 0.0
		Shape.BRISTLE:
			# Une vingtaine de poils en travers de la pointe, plus ou moins chargés.
			var hair := floori((x + 1.0) * 10.0)
			w *= 0.25 + 0.75 * hash3(hair, bristle_seed, 7)
	return w


## Rayon à explorer autour du centre, en fraction du rayon du pinceau (coins des pointes carrées).
func reach() -> float:
	return 1.42 if shape in [Shape.SQUARE, Shape.FLAT] else 1.0


## Nombre pseudo-aléatoire stable dans [0, 1] pour trois entiers.
static func hash3(a: int, b: int, c: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


## Image de la pointe (blanc, alpha = peinture déposée), pour le curseur et les icônes.
## [outline] : trace aussi le contour de la pointe.
func make_image(size: int, outline: bool = true) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var inside := PackedByteArray()
	inside.resize(size * size)
	for py in size:
		for px in size:
			var x := (px + 0.5) / size * 2.0 - 1.0
			var y := (py + 0.5) / size * 2.0 - 1.0
			# Pour l'aperçu, un tirage par petite case de pixels (taille de grain visible).
			var cell := maxi(1, size / 24)
			var noise := hash3(px / cell, py / cell, 3)
			var w := weight(x, y, noise, 1)
			inside[py * size + px] = 1 if _inside(x, y) else 0
			img.set_pixel(px, py, Color(1, 1, 1, w * 0.55))
	if outline:
		for py in size:
			for px in size:
				var here := inside[py * size + px]
				var edge := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qx := px + d.x
					var qy := py + d.y
					var there := inside[qy * size + qx] if qx >= 0 and qy >= 0 and qx < size and qy < size else 0
					if there != here:
						edge = true
				if edge and here == 1:
					img.set_pixel(px, py, Color(1, 1, 1, 0.95))
	return img


## Le point est-il dans l'enveloppe de la pointe (sans dureté ni texture) ?
func _inside(x: float, y: float) -> bool:
	var yy := y / maxf(roundness, 0.05)
	match shape:
		Shape.SQUARE:
			return maxf(absf(x), absf(yy)) <= 1.0
		Shape.DIAMOND:
			return absf(x) + absf(yy) <= 1.0
		Shape.FLAT:
			return maxf(absf(x), absf(yy) * 4.0) <= 1.0
		_:
			return x * x + yy * yy <= 1.0
