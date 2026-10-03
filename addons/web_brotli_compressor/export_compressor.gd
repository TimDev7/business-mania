extends EditorExportPlugin

const COMPRESSED_EXTENSIONS := ["wasm", "js", "pck"]
const BROTLI_QUALITY := "11"

var _export_dir := ""
var _should_compress := false


func _get_name() -> String:
	return "WebBuildCompressor"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return true


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	_should_compress = features.has("web") and not is_debug
	_export_dir = path if DirAccess.dir_exists_absolute(path) else path.get_base_dir()


func _export_end() -> void:
	if not _should_compress:
		return

	if OS.execute("brotli", ["--version"], []) == -1:
		push_error("WebBuildCompressor: brotli не найден в PATH — .br-файлы не созданы. Установи Brotli (идёт с Git for Windows, C:\\Program Files\\Git\\mingw64\\bin) или добавь его в PATH.")
		return

	var files := _collect_files(_export_dir)
	var failed := 0
	for file_path: String in files:
		var output := []
		var exit_code := OS.execute("brotli", ["-q", BROTLI_QUALITY, "-k", "-f", file_path, "-o", file_path + ".br"], output, true)
		if exit_code != 0:
			failed += 1
			push_error("WebBuildCompressor: не удалось сжать %s (код %d): %s" % [file_path, exit_code, output])

	print("WebBuildCompressor: сжато %d/%d файлов в %s" % [files.size() - failed, files.size(), _export_dir])


func _collect_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue

		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			result.append_array(_collect_files(full_path))
		elif entry.get_extension().to_lower() in COMPRESSED_EXTENSIONS and not entry.ends_with(".br"):
			result.append(full_path)

		entry = dir.get_next()

	return result
