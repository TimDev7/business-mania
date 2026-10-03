extends Node

## Thin wrapper over CrazyGames' own JS SDK (window.CrazyGames.SDK, loaded
## from https://sdk.crazygames.com/crazygames-sdk-v3.js by this addon's own
## index.html - see plugin.gd, which points the "CrazyGames" export
## preset's custom_html_shell at it).
##
## No official Godot 4 package exists for this SDK as shipped/reachable
## right now - verified directly, not assumed: both
## https://docs.crazygames.com/sdk/godot/intro/ and
## https://store.godotengine.org/asset/crazygames/crazysdk/ (the URLs
## CrazyGames' own generic docs point to) 404/403 as of writing. Their own
## community reference project
## (github.com/PlayWithFurcifer/GodotCrazySDKTemplate) hand-wraps the JS SDK
## via JavaScriptBridge the exact same way this file does - confirmed to be
## the accepted approach, not a workaround. The actual JS API called below
## (SDK.init(), SDK.environment, SDK.ad.requestAd(), SDK.game.*) is
## confirmed against docs.crazygames.com/sdk/intro, /sdk/video-ads, and
## /sdk/game directly, which DO resolve.
##
## Game code should go through SDK.gd (res://template/sdk/sdk.gd), not this
## file directly - same rule as Bridge/GPX.
##
## sdk is null until BOTH SDK.init()'s promise resolves AND CrazyGames
## reports itself not "disabled" (see docs.crazygames.com/sdk/intro: "on
## non-CrazyGames domains, all the calls to the SDK methods will throw an
## error") - every method below checks it first, same shape as GPX.gpx's
## own null-check, so callers never need their own environment check. This
## resolves asynchronously, so sdk can still be null for a brief window
## right after boot even on a real CrazyGames build - callers already
## tolerate that gracefully (see sdk.gd's own null-checked branches), the
## same way an early call racing GPX.gpx or a not-yet-loaded Bridge already
## degrades to a harmless no-op rather than a crash.
##
## NOT independently verified against a live browser session (this addon
## has never been exported and run on crazygames.com yet) - written
## directly from the docs pages above, not memory or a third-party guide,
## but still worth a real playtest before trusting it blindly. In
## particular, JavaScriptBridge.create_object("Object") + assigning named
## properties as the way to build the {adStarted, adFinished, adError}
## callbacks object requestAd() expects is standard Godot 4 JavaScriptBridge
## usage, but hasn't been run against the real CrazyGames SDK yet.
## Fires whenever CrazyGames' own player-facing settings change - right now
## only muteAudio is read (see is_audio_muted()/_on_settings_changed()), but
## the underlying event covers the whole settings object.
signal mute_setting_changed(muted: bool)

var sdk = null

## Cached mirror of sdk.game.settings.muteAudio - see is_audio_muted()'s own
## doc comment for why this is a cache updated only by genuine events,
## never a live re-read of the JS property.
var _is_audio_muted: bool = false

var _js_crazygames = null
var _init_then_cb = null
var _init_catch_cb = null
var _settings_changed_cb = null

var _ad_on_started: Callable
var _ad_on_finished: Callable
var _ad_on_error: Callable
var _ad_started_js_cb = null
var _ad_finished_js_cb = null
var _ad_error_js_cb = null


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	# CG is a global autoload present in EVERY export (Web/GamePix/CrazyGames
	# alike), not just this one - same situation as Bridge/GPX. Checking
	# window.CrazyGames's existence first via a quiet eval() (which logs
	# nothing on a false result), rather than calling
	# JavaScriptBridge.get_interface() unconditionally, avoids printing a
	# red "ERROR: No interface 'CrazyGames' registered." engine error on
	# every single page load of a Y8 or GamePix build - the exact class of
	# bug this addon's own README pointed out for bridge.gd/gpx.gd,
	# confirmed live in a real CrazyGames QA preview session for those two.
	if not JavaScriptBridge.eval("typeof window.CrazyGames !== 'undefined'", true):
		print("[CrazyGames SDK] window.CrazyGames not found - this export's index.html didn't load the CDN script, or it failed to load")
		return
	_js_crazygames = JavaScriptBridge.get_interface("CrazyGames")
	_init_then_cb = JavaScriptBridge.create_callback(_on_init_resolved)
	_init_catch_cb = JavaScriptBridge.create_callback(_on_init_rejected)
	print("[CrazyGames SDK] calling SDK.init() ...")
	_js_crazygames.SDK.init().then(_init_then_cb).catch(_init_catch_cb)


func _on_init_resolved(_args) -> void:
	var environment = _js_crazygames.SDK.environment
	print("[CrazyGames SDK] init() resolved, environment=", environment)
	if environment == "disabled":
		# Per docs.crazygames.com/sdk/intro: calls throw on a non-CrazyGames
		# domain. Staying inactive (sdk left null) here is what makes every
		# call below a safe no-op instead of an uncaught JS exception.
		return
	sdk = _js_crazygames.SDK
	# One-time seed from the live value - the only place this facade ever
	# reads sdk.game.settings.muteAudio directly. See is_audio_muted()'s own
	# doc comment for why every OTHER read goes through the cache instead.
	_is_audio_muted = bool(sdk.game.settings.muteAudio)
	_settings_changed_cb = JavaScriptBridge.create_callback(_on_settings_changed)
	sdk.game.addSettingsChangeListener(_settings_changed_cb)


func _on_init_rejected(args) -> void:
	printerr("[CrazyGames SDK] SDK.init() rejected: ", args)


## docs.crazygames.com/sdk/game: "please disable the game audio if this is
## true... this SDK setting should take priority over your in-game audio
## settings" - this is CrazyGames' own player-level mute control (their
## portal chrome, or the ?muteAudio=true test flag), separate from anything
## this game's own Settings menu does.
##
## Bug report: this used to read sdk.game.settings.muteAudio live on every
## call, on the assumption it was always safe to poll (mirroring
## Bridge.platform.is_audio_enabled's own "read the current value" contract
## - see sdk.gd's connect_platform_signals()). That assumption broke:
## CrazyGames appears to flip this property internally while preparing to
## show an ad - even one it then immediately rejects (confirmed live:
## "[AdError] adsDisabledBasicLaunch" during their own QA review, with
## muteAudio left reading true afterward) - WITHOUT ever firing
## addSettingsChangeListener for it (confirmed live too: no "settings
## changed" print ever appeared for that transition). Any code that
## happened to poll this live value shortly after an ad request, or at any
## later unrelated moment - sdk.gd's _end_ad_pause() right after an ad, but
## also connect_platform_signals()'s own re-apply on every Title revisit -
## could pick up that transient internal value and silence the game with no
## way back short of an unrelated tab-visibility toggle correcting it via a
## different path entirely.
##
## Now a plain cached getter: _is_audio_muted is set exactly twice - once
## from the live value right after SDK.init() resolves (see
## _on_init_resolved(), the one place still allowed to read the JS property
## directly, since there's no earlier event to have caught the initial
## state), and again only from genuine addSettingsChangeListener callbacks
## (_on_settings_changed()) - both of which are moments this facade knows
## for certain reflect the platform's real, event-worthy audio preference,
## not an internal ad-request side effect.
func is_audio_muted() -> bool:
	return _is_audio_muted


func _on_settings_changed(args) -> void:
	var new_settings = args[0]
	_is_audio_muted = bool(new_settings.muteAudio)
	print("[CrazyGames SDK] settings changed, muteAudio=", _is_audio_muted)
	mute_setting_changed.emit(_is_audio_muted)


## Whenever the player starts playing or resumes after a break (game start,
## resume, revive, enter next level, ...) - see docs.crazygames.com/sdk/game.
func gameplayStart() -> void:
	if sdk != null:
		sdk.game.gameplayStart()


## On every game break (entering a menu, ending level, pausing the game,
## ...) - do NOT call this for a tab switch/losing focus, the platform
## handles that itself (see the same docs page).
func gameplayStop() -> void:
	if sdk != null:
		sdk.game.gameplayStop()


## ad_type is "midgame" or "rewarded" (see docs.crazygames.com/sdk/video-ads -
## "preroll" isn't a thing here the way it is on Y8, this SDK only has these
## two). on_started fires once the ad actually begins covering the screen -
## CrazyGames' own docs are explicit pause/mute belongs THERE, not at the
## request itself, since a request can still fail to find/load an ad without
## ever showing anything. on_finished fires once the ad played through
## normally; on_error fires if it failed to load/play - CrazyGames'
## rewarded-ad rules require treating these differently (grant the reward
## only on adFinished, never on adError), so callers get them as two
## distinct Callables rather than one merged "done" signal. Both default to
## on_finished's own value when omitted isn't an option here (unlike
## show_rewarded()'s on_no_reward in sdk.gd) - a caller with nothing
## meaningful to distinguish just passes the same Callable for both, same as
## sdk.gd's show_interstitial() does.
func requestAd(ad_type: String, on_started: Callable, on_finished: Callable, on_error: Callable) -> void:
	if sdk == null:
		on_finished.call() # not on CrazyGames (or SDK unavailable) - just continue, matching gpx.gd's own not-on-this-platform fallback
		return
	_ad_on_started = on_started
	_ad_on_finished = on_finished
	_ad_on_error = on_error
	_ad_started_js_cb = JavaScriptBridge.create_callback(_on_ad_started)
	_ad_finished_js_cb = JavaScriptBridge.create_callback(_on_ad_finished)
	_ad_error_js_cb = JavaScriptBridge.create_callback(_on_ad_error)
	var callbacks = JavaScriptBridge.create_object("Object")
	callbacks.adStarted = _ad_started_js_cb
	callbacks.adFinished = _ad_finished_js_cb
	callbacks.adError = _ad_error_js_cb
	sdk.ad.requestAd(ad_type, callbacks)


func _on_ad_started(_args) -> void:
	if _ad_on_started.is_valid():
		_ad_on_started.call()


func _on_ad_finished(_args) -> void:
	if _ad_on_finished.is_valid():
		_ad_on_finished.call()
	_clear_ad_callbacks()


func _on_ad_error(args) -> void:
	print("[CrazyGames SDK] ad error: ", args)
	if _ad_on_error.is_valid():
		_ad_on_error.call()
	_clear_ad_callbacks()


func _clear_ad_callbacks() -> void:
	_ad_on_started = Callable()
	_ad_on_finished = Callable()
	_ad_on_error = Callable()
