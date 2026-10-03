extends Node
class_name CoreSoundManager

const _BUS_LAYOUT:AudioBusLayout = preload("uid://cnlrydd82c856")

const _SFX_POOL_MAX_SIZE:int = 50
var _sfx_pool: Array = []
var _idx:int = 0

var _music_player:AudioStreamPlayer

## The current playlist (set by play_music()/play_music_playlist()) and a
## shuffled play order through it - see _play_next_in_playlist().
var _music_playlist: Array[AudioStream] = []
var _music_shuffle_order: Array[int] = []
var _music_shuffle_position: int = 0


func _ready():
	for _i in range(_SFX_POOL_MAX_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	# Advances the playlist instead of relying on the imported file's own
	# "Loop" import setting - works the same whether that's checked or not,
	# and for a single-track "playlist" this just plays that same one
	# track again, so it still loops forever exactly like before.
	_music_player.finished.connect(_play_next_in_playlist)


## Connected by Core to event_bus.app_hidden_changed (see core.gd - that's
## where the actual browser tab-visibility detection lives, since it's a
## concern shared with CoreSaveManager's own save-on-blur, not something
## specific to sound). Silences everything (regardless of the player's own
## Music/SFX toggle state - those are separate, persisted preferences, not
## what this is about) the instant a web build's browser tab is hidden, and
## restores it once visible again - critical for a web game specifically,
## since without this the audio keeps playing in a background tab nobody's
## looking at. Muting "Master" rather than "Music"/"SFX" individually means
## there's no prior state to remember and restore - it's just a blanket
## switch sitting on top of whatever those two are already set to.
func _on_app_hidden_changed(hidden: bool) -> void:
	set_bus_mute("Master", hidden)


func set_bus_mute(bus_name:String, is_muted:bool) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, is_muted)


func set_bus_volume(bus_name:String, db_linear:float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(db_linear))


func play_sfx(stream:AudioStream, linear_db:float = 1.0, pitch_var:float = 0.0) -> void:
	var player:AudioStreamPlayer = _sfx_pool[_idx]

	player.stream = stream
	player.volume_db = linear_to_db(linear_db)
	player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	player.play()

	_idx = (_idx + 1) % _SFX_POOL_MAX_SIZE


func play_music(stream:AudioStream, linear_db:float = 1.0) -> void:
	play_music_playlist([stream], linear_db)


## Plays a set of tracks in shuffled order, forever - a fresh shuffle every
## time the order runs out, so a whole cycle always plays every track
## exactly once before any repeats (not "pick one at random each time",
## which can by chance keep trading off between just two of however many
## tracks there are while a third never comes up). The new cycle's first
## pick is also guaranteed not to be a repeat of whichever track JUST
## finished, so the seam between cycles can't sound like an accidental
## back-to-back repeat either.
func play_music_playlist(tracks: Array[AudioStream], linear_db: float = 1.0) -> void:
	if tracks.is_empty():
		return
	_music_playlist = tracks
	_music_shuffle_order = _shuffled_indices(tracks.size())
	_music_shuffle_position = 0
	_music_player.volume_db = linear_to_db(linear_db)
	_music_player.stream = _music_playlist[_music_shuffle_order[0]]
	_music_player.play()


func _play_next_in_playlist() -> void:
	if _music_playlist.is_empty():
		return
	_music_shuffle_position += 1
	if _music_shuffle_position >= _music_shuffle_order.size():
		var just_played: int = _music_shuffle_order[_music_shuffle_order.size() - 1]
		_music_shuffle_order = _shuffled_indices(_music_playlist.size(), just_played)
		_music_shuffle_position = 0
	_music_player.stream = _music_playlist[_music_shuffle_order[_music_shuffle_position]]
	_music_player.play()


## A true shuffle-bag (Fisher-Yates via Array.shuffle(), not "roll a random
## index every time") - re-rolled as a whole, not just its first slot,
## until the first entry isn't avoid_first (skipped when there's only one
## track, since then there's nothing else it COULD be).
func _shuffled_indices(count: int, avoid_first: int = -1) -> Array[int]:
	var indices: Array[int] = []
	for i in count:
		indices.append(i)
	indices.shuffle()
	while count > 1 and avoid_first >= 0 and indices[0] == avoid_first:
		indices.shuffle()
	return indices


## Lets a caller avoid restarting an already-playing track from the top
## (e.g. a Title screen re-entered via a Menu) - the music lives on this
## persistent singleton, not the scene the player's currently in, so
## re-entering a screen that starts music must not sound like the track
## skipped back to 0:00.
func is_music_playing() -> bool:
	return _music_player.playing
