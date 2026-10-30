class_name HttpJson
extends Node
## Requêtes HTTP(S) du serveur (API Web Steam, PostgREST), réponses JSON.
## Une requête = un HTTPRequest enfant, libéré à la fin. Doit être dans l'arbre de scènes.

const TIMEOUT := 10.0


## Appelle [done] avec (code HTTP, corps JSON décodé ou null). Code 0 : pas de réponse
## (réseau coupé, délai dépassé).
func request(url: String, done: Callable, headers: PackedStringArray = PackedStringArray(),
		method: HTTPClient.Method = HTTPClient.METHOD_GET, body: String = "") -> void:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			done.call(0, null)
			return
		var text := raw.get_string_from_utf8()
		done.call(code, JSON.parse_string(text) if text != "" else null))
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		done.call(0, null)
