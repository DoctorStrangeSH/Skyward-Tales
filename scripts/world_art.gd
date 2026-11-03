extends RefCounted
class_name WorldArt

## Shared access to generated art (tools/art/build.py). Textures are cached;
## the manifest stores each sprite's anchor point ("origin").

const MANIFEST_PATH := "res://assets/art_manifest.json"

static var _textures: Dictionary = {}
static var _manifest: Dictionary = {}

static func texture(rel_path: String) -> Texture2D:
	if _textures.has(rel_path):
		return _textures[rel_path]
	var path := "res://assets/" + rel_path
	var loaded: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if loaded == null:
		push_warning("Нет текстуры: " + path)
	_textures[rel_path] = loaded
	return loaded

static func origin(rel_path: String) -> Vector2:
	if _manifest.is_empty():
		var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			_manifest = parsed if parsed is Dictionary else {"_": {}}
		else:
			_manifest = {"_": {}}
	var entry: Variant = _manifest.get(rel_path, {})
	var value: Variant = entry.get("origin") if entry is Dictionary else null
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	var tex := texture(rel_path)
	return Vector2(tex.get_width() / 2.0, tex.get_height()) if tex != null else Vector2.ZERO

## Draws a prop so that its anchor sits on the node's position.
static func draw_prop(item: CanvasItem, rel_path: String) -> void:
	var tex := texture(rel_path)
	if tex != null:
		item.draw_texture(tex, -origin(rel_path))
