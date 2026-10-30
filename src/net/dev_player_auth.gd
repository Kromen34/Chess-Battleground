class_name DevPlayerAuth
extends PlayerAuth
## Développement en local uniquement (serveur lancé avec --dev) : croit le SteamID
## annoncé par le client, sans preuve. Permet de tester avec deux fenêtres sans Steam
## (--steam-id=N côté client). Jamais en production : n'importe qui serait n'importe qui.


func authenticate(hello: Dictionary, done: Callable) -> void:
	done.call(Protocol.claimed_steam_id(hello))
