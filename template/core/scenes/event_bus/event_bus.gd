extends Node
class_name CoreEventBus
# warning-ignore-all:unused_signal

# --- DEBUG ---
signal logged()


# --- CORE ---
signal game_data_loaded(last_save_time) # last_save_time: String
## Broadcast by Core's own document.visibilitychange listener (see
## core.gd) - true when a web build's browser tab is hidden (backgrounded/
## switched away from), false when it's visible again. The one real signal
## for this; see core.gd's own comment on why Godot's built-in
## NOTIFICATION_APPLICATION_FOCUS_OUT/_IN can't be used for it on Web.
signal app_hidden_changed(hidden: bool)
