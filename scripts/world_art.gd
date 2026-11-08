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

## Draws a prop so that its anchor sits on the node's position. World art
## with an HD version (assets/world_hd, from the asset pack) uses that one.
static func draw_prop(item: CanvasItem, rel_path: String, flip_x: bool = false, at: Vector2 = Vector2.ZERO, stretch: Vector2 = Vector2.ONE) -> void:
	var hd := hd_path(rel_path)
	if not hd.is_empty():
		var hd_tex := texture(hd)
		if hd_tex != null:
			item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			item.draw_set_transform(at, 0.0, Vector2(-0.5 if flip_x else 0.5, 0.5) * stretch)
			item.draw_texture(hd_tex, -origin(hd))
			item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	var plain_xform := flip_x or at != Vector2.ZERO or stretch != Vector2.ONE
	if plain_xform:
		item.draw_set_transform(at, 0.0, Vector2(-1.0 if flip_x else 1.0, 1.0) * stretch)
	var tex := texture(rel_path)
	if tex != null:
		item.draw_texture(tex, -origin(rel_path))
	if plain_xform:
		item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static var _hd_paths: Dictionary = {}

## "world/x.png" → "world_hd/x.png" when an HD version exists, else "".
static func hd_path(rel_path: String) -> String:
	if _hd_paths.has(rel_path):
		return _hd_paths[rel_path]
	var result := ""
	if rel_path.begins_with("world/") or rel_path.begins_with("props/"):
		var candidate := "world_hd/" + rel_path.trim_prefix("world/")
		if ResourceLoader.exists("res://assets/" + candidate):
			result = candidate
	_hd_paths[rel_path] = result
	return result

## The visible size of a prop in world pixels.
static func world_size(rel_path: String) -> Vector2:
	var hd := hd_path(rel_path)
	if not hd.is_empty():
		var tex := texture(hd)
		return tex.get_size() * 0.5 if tex != null else Vector2.ZERO
	var plain := texture(rel_path)
	return plain.get_size() if plain != null else Vector2.ZERO
