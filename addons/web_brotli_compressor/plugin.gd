@tool
extends EditorPlugin

const WebExportCompressor := preload("res://addons/web_brotli_compressor/export_compressor.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = WebExportCompressor.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
