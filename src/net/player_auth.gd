class_name PlayerAuth
extends RefCounted
## Vérifie l'identité Steam d'un client à partir de son message HELLO.
## Cette version de base ne reconnaît personne : tous les clients sont des invités
## (pas de collection). Voir SteamWebAuth (production) et DevPlayerAuth (local).


## Appelle [done] avec le SteamID vérifié du client, ou 0 s'il n'est pas reconnu.
## [done] peut être appelé plus tard (requête HTTP), le client a pu partir entre-temps.
func authenticate(_hello: Dictionary, done: Callable) -> void:
	done.call(0)
