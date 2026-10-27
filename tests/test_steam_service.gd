extends TestCase
## SteamService ne doit jamais dépendre de Steam pour démarrer : on teste ici
## uniquement la partie pure (construction de l'avatar).

const SteamServiceScript := preload("res://src/platform/steam_service.gd")


func test_avatar_from_valid_rgba_buffer() -> void:
	var buffer := PackedByteArray()
	buffer.resize(4 * 4 * 4)
	buffer.fill(255)
	var tex := SteamServiceScript.avatar_from_rgba(4, buffer)
	assert_not_null(tex)
	assert_eq(tex.get_width(), 4)
	assert_eq(tex.get_height(), 4)


func test_avatar_from_wrong_size_buffer_is_null() -> void:
	var buffer := PackedByteArray()
	buffer.resize(10)
	assert_null(SteamServiceScript.avatar_from_rgba(4, buffer))
	assert_null(SteamServiceScript.avatar_from_rgba(0, PackedByteArray()))
