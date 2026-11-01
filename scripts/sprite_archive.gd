extends RefCounted

## Extracts committed PNG sprite sheets from the archive into user://.
## This keeps binary art assets versioned in Git while letting Godot load PNGs
## as regular textures at runtime.

const ARCHIVE_PATH := "res://assets/sprites/sprite_sheets.zip"
const TARGET_DIRECTORY := "user://SkywardTales/sprites"

static func extract_if_needed() -> bool:
	var absolute_directory := ProjectSettings.globalize_path(TARGET_DIRECTORY)
	var make_directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if make_directory_error != OK and make_directory_error != ERR_ALREADY_EXISTS:
		push_error("Не удалось создать папку спрайтов: %s" % make_directory_error)
		return false

	var archive := ZIPReader.new()
	var open_error := archive.open(ARCHIVE_PATH)
	if open_error != OK:
		push_error("Не удалось открыть архив спрайтов: %s" % ARCHIVE_PATH)
		return false

	var all_extracted := true
	for entry_path in archive.get_files():
		if entry_path.ends_with("/"):
			continue
		var destination_path := TARGET_DIRECTORY.path_join(entry_path)
		var destination_directory := destination_path.get_base_dir()
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_directory))
		if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
			push_error("Не удалось создать папку спрайтов: %s" % destination_directory)
			all_extracted = false
			continue
		var output := FileAccess.open(destination_path, FileAccess.WRITE)
		if output == null:
			push_error("Не удалось записать спрайт: %s" % destination_path)
			all_extracted = false
			continue
		output.store_buffer(archive.read_file(entry_path))
		output.close()
	archive.close()
	return all_extracted
