class_name BoardGenerator
extends RefCounted
## Interface d'un générateur de plateau. Une sous-classe par forme.
## La forme est choisie en fonction du nombre de joueurs ; le reste du jeu
## ne voit qu'un Board.


## Identifiant stable de la forme (sérialisé dans la partie réseau).
func shape_id() -> StringName:
	return &"abstract"


## Nombre de joueurs que cette forme accueille.
func player_count() -> int:
	return 0


func generate() -> Board:
	push_error("BoardGenerator.generate() doit être surchargée")
	return null


## Fabrique : retourne le générateur adapté au nombre de joueurs.
## Le jeu est en 1v1 uniquement : tout autre nombre de joueurs renvoie null
## et les règles refusent de démarrer la partie.
static func for_player_count(players: int) -> BoardGenerator:
	match players:
		2:
			return SquareGenerator.new()
		_:
			return null
