extends RefCounted
class_name SDK

## Thin, portable facade over three vendored portal SDKs: Playgama Bridge
## (res://addons/playgama_bridge, MIT-licensed, https://github.com/Playgama/bridge-godot-4)
## for portals it supports (Y8 and others - see its own platform id list),
## GamePix's own plugin (res://addons/gpx-godot-plugin) for GamePix
## specifically, and a hand-written wrapper
## (res://addons/crazygames_sdk/crazygames.gd) for CrazyGames specifically -
## no working official Godot package exists for it (see that addon's own
## README.md for what was actually verified, and why Playgama Bridge isn't
## used for this one portal even though its own platform list claims
## CrazyGames support: Playgama's actual CrazyGames adapter is a chunk
## loaded dynamically from Playgama's own CDN at runtime - not vendored in
## this repo, not auditable - so a portal that specifically needs its
## integration verified against a real, readable source is reason enough to
## integrate that one portal directly against its own docs instead; this
## bit a real project once as a portal rejecting a build over vague
## "stability" feedback with no verifiable adapter source to check). Game
## code calls SDK.* instead of touching Bridge.*/GPX.*/CG.* directly.
##
## All three are shipped as genuinely separate exports (see
## export_presets.cfg's "Web"/"GamePix"/"CrazyGames" presets - each portal's
## SDK needs its own custom_html_shell, so one build can't serve more than
## one at once), but this file stays a single codepath for all of them:
## GPX.gpx/CG.sdk are only non-null when that portal's own JS SDK is
## actually present (see gpx.gd's and crazygames.gd's own _ready()), so
## checking those at call time picks the right backend automatically no
## matter which preset produced the running build - ad/analytics calls for
## whichever SDKs weren't loaded in that build's HTML at all would otherwise
## silently no-op (or for GPX.rewardAd() specifically, instantly "succeed" -
## see show_rewarded()'s own comment on why that one specifically can't be
## called unconditionally).
##
## Bridge auto-detects the platform (OS.has_feature("web")) and falls back
## to safe mock modules everywhere else (editor, desktop, or a web export
## whose HTML never actually loaded window.bridge at all - e.g. the
## GamePix/CrazyGames presets) - see addons/playgama_bridge/modules/*/​*_editor_mock.gd
## and bridge.gd's own _ready(). That mock is what every GUT test in this
## project runs against, since tests always run outside a web export.
##
## Adding a new portal later: if it has its own Playgama Bridge-style module
## (see bridge.gd), no changes needed here at all. If it needs its own
## separate plugin (like GPX/CG), give that plugin the same "only non-null
## when its own JS SDK is actually present" shape as gpx.gd/crazygames.gd,
## and add one more branch alongside theirs below in each relevant method -
## never replace the Bridge branch, since a portal using Bridge still needs
## it.


## How long an ad's own promise/callback gets to fire before this facade
## gives up on it and recovers on its own. A plugin can pause the SceneTree
## itself right before firing an ad request and only unpause inside that
## request's own resolution (see gpx.gd's interstitialAd()/rewardAd()) - if
## that promise never settles (a JS-side SDK issue on the portal's end, not
## something fixable from this facade without patching the vendored
## plugin), the whole game would otherwise stay frozen forever. Generous on
## purpose - real interstitial/rewarded videos commonly run up to 30s, and
## this must never cut one off mid-play - it's purely a recovery net for a
## genuinely broken/hung call. A static var (not a const) so tests can
## shrink it instead of waiting on the wall clock.
static var ad_timeout_sec: float = 45.0


## Wraps each of on_fire so only the first of them - or, failing that,
## timeout_fallback once ad_timeout_sec elapses - actually runs; every
## other one (including a real SDK callback that finally arrives late,
## after this facade already gave up on it) becomes a silent no-op. Also
## unconditionally un-pauses the tree on timeout, on top of just calling
## timeout_fallback - see ad_timeout_sec's own comment on why that's
## needed here specifically (harmless when nothing was actually paused).
static func _first_to_fire(on_fire: Array[Callable], timeout_fallback: Callable) -> Array[Callable]:
	var fired := [false]
	var wrapped: Array[Callable] = []
	for c in on_fire:
		wrapped.append(func() -> void:
			if fired[0]:
				return
			fired[0] = true
			c.call()
		)
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(ad_timeout_sec).timeout.connect(func() -> void:
		if fired[0]:
			return
		fired[0] = true
		push_warning("SDK: ad_timeout_sec (%s s) elapsed with no ad callback - forcing recovery" % ad_timeout_sec)
		tree.paused = false
		timeout_fallback.call()
	)
	return wrapped


## The portal's own player language, an arbitrary tag ("en", "pt-BR", ...)
## - "en" outside a real web export/portal (the editor mock's
## platform_editor_mock.gd always reports "en"). Callers matching this
## against their own supported language list should normalize it first.
## Checked on GPX first since Bridge.platform.language falls back to its
## own mock (always "en") on a GamePix build - Playgama's own window.bridge
## script is never loaded there (see bridge.gd's _ready()), so it never has
## a real answer to give.
static func platform_language() -> String:
	if GPX.gpx != null:
		return GPX.lang()
	return Bridge.platform.language


## True once connect_platform_signals() has wired its connections, so
## calling it again (e.g. every time Title is revisited) doesn't stack a
## second listener on top of the first.
static var _platform_signals_connected: bool = false


## Wires Bridge's own portal-driven audio/pause signals (Bridge.platform.
## audio_state_changed / pause_state_changed - see platform.gd) and
## CrazyGames' own per-player mute setting (CG.mute_setting_changed) into
## this project's mute/pause systems. Per Playgama's own docs
## (https://wiki.playgama.com/playgama/bridge-sdk/api/platform): the portal
## raises these whenever IT wants the game muted/paused - a site-wide mute
## button, another game's ad overlay opening on the same page, the browser
## tab losing focus - and Playgama explicitly documents this as required,
## one universal handler covering every case, not just tab-switching.
## CrazyGames' own docs make the identical point about their muteAudio
## setting. Call from somewhere guaranteed to run after every autoload is
## ready (Bridge/GPX/CG load after Core in project.godot's [autoload] list,
## so Core's own _ready() is too early) - Title's own _ready(), right
## alongside notify_loading_finished(), fits and is idempotent-safe to call
## again on every Title revisit.
##
## Also applies the CURRENT platform-muted state every time this runs -
## including on repeat calls, not just the very first one - Playgama's own
## docs are explicit that "subscribing to the event alone is not enough - it
## only fires on subsequent changes, so the initial state must be applied
## manually", and CrazyGames' docs make the identical point about their
## muteAudio setting (see _platform_wants_muted()). A player arriving on a
## portal that already has audio disabled (site-wide mute, an ad overlay
## from a previous game still up, or CrazyGames' own ?muteAudio=true) would
## otherwise hear music/SFX play regardless, since neither change-event
## fires for a state that was already true before this ever ran. Re-applying
## on every call (not gated behind _platform_signals_connected like the
## actual signal wiring below) also means a later Title revisit self-heals
## if this was ever somehow out of sync.
static func connect_platform_signals() -> void:
	if not _platform_signals_connected:
		_platform_signals_connected = true
		# Each listener uses the fired event's OWN payload directly (not a
		# fresh Bridge.platform.is_audio_enabled/CG.is_audio_muted() re-read)
		# ORed with the OTHER backend's current state - the more direct,
		# less racy reading of "what just changed" than re-querying a moment
		# later regardless.
		Bridge.platform.audio_state_changed.connect(func(enabled: bool) -> void:
			Core.sound_manager.set_bus_mute("Master", not enabled or CG.is_audio_muted())
		)
		Bridge.platform.pause_state_changed.connect(func(should_pause: bool) -> void:
			Core.toggle_pause(should_pause, "platform")
		)
		CG.mute_setting_changed.connect(func(muted: bool) -> void:
			Core.sound_manager.set_bus_mute("Master", muted or not Bridge.platform.is_audio_enabled)
		)
	Core.sound_manager.set_bus_mute("Master", _platform_wants_muted())


## Whether ANY backend currently wants Master muted for a reason outside
## this facade's own ad-driven mute (see _begin_ad_pause()/_end_ad_pause()) -
## the portal's own site-wide/audio-permission state
## (Bridge.platform.is_audio_enabled) or CrazyGames' own per-player
## muteAudio setting (docs.crazygames.com/sdk/game: "please disable the game
## audio if this is true... this SDK setting should take priority over your
## in-game audio settings"). Exactly one of these two is ever the real
## backend on a given build - the other's check is always inert (Bridge
## mocked-enabled=true / CG.sdk null -> is_audio_muted() false) - so ORing
## them together is always safe, never a false positive from the inactive
## one.
static func _platform_wants_muted() -> bool:
	return not Bridge.platform.is_audio_enabled or CG.is_audio_muted()


## GamePix.game.gameLoaded() specifically (not just Bridge's own GAME_READY
## message) is what unblocks EVERY GamePix ad call - per their docs,
## interstitialAd()/rewardAd() both reject with "GAMEPIX_LOADED_NOT_CALLED"
## until this fires, and the vendored plugin never calls it on its own.
## Called straight on the raw JS object (GPX.gpx), not through a gpx.gd
## wrapper, since gpx.gd doesn't expose one.
static func notify_loading_finished() -> void:
	Bridge.platform.send_message(Bridge.PlatformMessage.GAME_READY)
	if GPX.gpx != null:
		GPX.gpx.game.gameLoaded()


static func notify_level_started() -> void:
	Bridge.platform.send_message(Bridge.PlatformMessage.LEVEL_STARTED)


## CrazyGames documents gameplayStart() as required "whenever the player
## starts playing or resumes playing after a break (game start, resume,
## revive, enter next level, ...)" and gameplayStop() "on every game break
## (entering a menu, ending level, pausing the game, ...)" - and separately,
## CrazyGames' own ad requirements page lists "the game freezing between
## levels" and "ads interrupting active gameplay" as explicit rejection
## reasons, both plausible symptoms of the platform never being told
## gameplay had actually paused/ended. Call these from wherever the game
## marks a level starting/resuming vs. ending/pausing (same points
## notify_level_started()/notify_level_completed()/notify_level_failed()
## already mark, plus opening the pause menu). Bridge.platform.send_message()
## no-ops harmlessly on every OTHER platform (mock outside a real
## Bridge-backed web export, and GPX/CG don't load window.bridge at all),
## so wiring this in is safe everywhere, not just for CrazyGames.
##
## Also calls CG.gameplayStart()/gameplayStop() directly (CG.sdk == null is
## a safe no-op on every build that isn't the CrazyGames export) - this is
## the exact call CrazyGames' own docs describe, not something Bridge's
## generic message can stand in for on this specific portal (Bridge isn't
## even the backend in a CrazyGames build - see this file's own header
## comment on why).
static func notify_gameplay_started() -> void:
	Bridge.platform.send_message(Bridge.PlatformMessage.GAMEPLAY_STARTED)
	CG.gameplayStart()


static func notify_gameplay_stopped() -> void:
	Bridge.platform.send_message(Bridge.PlatformMessage.GAMEPLAY_STOPPED)
	CG.gameplayStop()


## level_number (the level/stage just cleared), if the game has one, is
## also reported to GamePix via GPX.updateLevel() and GPX.updateScore() -
## GamePix has no dedicated "level completed" message, and updateScore()
## is the closest stand-in for a game whose own idea of "score" IS its
## level number. <= 0 (the default) skips both - a caller with nothing
## meaningful to report just doesn't.
static func notify_level_completed(level_number: int = 0) -> void:
	Bridge.platform.send_message(Bridge.PlatformMessage.LEVEL_COMPLETED)
	# GPX.happyMoment() ("something satisfying just happened") is GamePix's
	# own closest fit for a level clear. Safe to call unconditionally - a
	# no-op when GPX.gpx is null (see gpx.gd's happyMoment()).
	GPX.happyMoment()
	if level_number > 0:
		GPX.updateLevel(level_number)
		GPX.updateScore(level_number)


static func notify_level_failed() -> void:
	Bridge.platform.send_message(Bridge.PlatformMessage.LEVEL_FAILED)


## True from the moment show_interstitial()/show_rewarded() fires an ad
## request until its own completion callback runs (success, no-reward, or
## the ad_timeout_sec recovery). Centralized here - not left to each call
## site to track for itself - specifically so EVERY future caller gets
## this protection automatically: GamePix's own SDK rejects a second
## interstitialAd()/rewardAd() call made before the first resolves with an
## INTERSTITIAL_AD_CALLED_TWICE/REWARD_AD_CALLED_TWICE error outright (not
## just wasted - actively broken). A caller that also wants to grey out its
## own button while an ad is in flight still needs its own flag for that -
## this only prevents the actual double SDK call, it doesn't expose "is one
## in flight" itself.
static var _interstitial_in_progress: bool = false
static var _rewarded_in_progress: bool = false


## on_complete (optional) fires once the ad flow is fully done - shown and
## closed, skipped, failed, or (see ad_timeout_sec) given up on - never
## while it's still on screen. Callers that need to do something right
## after (e.g. reloading the next level) must wait for this instead of
## firing immediately alongside the ad request, to avoid reloading the
## scene before the ad flow's own pause/unpause has caught up. A call made
## while a previous one hasn't finished yet is silently ignored (on_complete
## is simply never called for it) - see _interstitial_in_progress.
static func show_interstitial(on_complete: Callable = Callable()) -> void:
	if _interstitial_in_progress:
		return
	_interstitial_in_progress = true
	# Tracks whether THIS specific flow actually muted/paused via
	# _begin_ad_pause()/the GPX mute line below, so finish() only ever
	# restores what this call itself set - see _end_ad_pause()'s doc comment
	# for the bug this guards against (restoring a mute this flow never
	# actually applied).
	var muted_for_this_ad := [false]
	var finish := func():
		_interstitial_in_progress = false
		if muted_for_this_ad[0]:
			_end_ad_pause()
		if on_complete.is_valid():
			on_complete.call()
	var complete: Callable = _first_to_fire([finish], finish)[0]
	if GPX.gpx != null:
		# gpx.gd already pauses the raw SceneTree itself around this call, but
		# GamePix's own plugin README is explicit that "you must pause the
		# game AND SOUNDS" when an ad is active, and pausing the tree alone
		# does not mute anything already playing (e.g. background music).
		muted_for_this_ad[0] = true
		Core.sound_manager.set_bus_mute("Master", true)
		GPX.interstitialAd(complete)
		return
	if CG.sdk != null:
		# CrazyGames' own docs put pause/mute specifically in the adStarted
		# callback (not at the request itself, which can still fail to find
		# an ad without ever showing anything) - only set once adStarted
		# actually fires, so a request CrazyGames rejects instantly (e.g.
		# "adsDisabledBasicLaunch") never marks this flow as having muted
		# anything, and finish() correctly leaves Master alone. "midgame"
		# (not "interstitial") is CrazyGames' own name for this ad type.
		CG.requestAd("midgame", func():
			muted_for_this_ad[0] = true
			_begin_ad_pause()
		, complete, complete)
		return
	if _bridge_ad_stuck_in_progress():
		# See _bridge_ad_stuck_in_progress()'s own comment: without this,
		# a stuck internal Bridge state silently swallows this call and
		# this facade sits waiting the full ad_timeout_sec for an event
		# that will never come.
		complete.call()
		return
	muted_for_this_ad[0] = true
	_begin_ad_pause()
	var self_ref := [Callable()]
	self_ref[0] = func(state: String) -> void:
		# Plain if/elif on purpose: match's patterns need to resolve as
		# compile-time constants, and Bridge.InterstitialState.X is a
		# runtime lookup through the Bridge autoload, not one - match
		# silently never matched it.
		if state == Bridge.InterstitialState.CLOSED or state == Bridge.InterstitialState.FAILED:
			Bridge.advertisement.interstitial_state_changed.disconnect(self_ref[0])
			complete.call()
	Bridge.advertisement.interstitial_state_changed.connect(self_ref[0])
	Bridge.advertisement.show_interstitial()


## Pauses gameplay and mutes audio for exactly as long as a Bridge- or
## CrazyGames-driven ad request is in flight. Y8's own advertising docs put
## this on the GAME, not the platform: "Pause your game inside the
## before-ad callback and resume it inside the after-ad callback... mute
## your audio in the same place you pause, and restore it in the same place
## you resume" - and explicitly list "gameplay pauses and audio mutes when
## ad appears" / "resumes after" as submission testing requirements.
## CrazyGames' own docs say the same thing near-verbatim. "ad" is its own
## pause source (see core.gd's _pause_sources) so it layers safely with the
## Pause menu or a portal-driven pause happening at the same time. Not
## called from the GPX branch: GamePix's own ad flow (gpx.gd) already pauses
## the raw SceneTree itself around its own calls, so calling this there too
## would be redundant, not incorrect - but simplest to keep it scoped to the
## codepaths it was verified against.
static func _begin_ad_pause() -> void:
	Core.toggle_pause(true, "ad")
	Core.sound_manager.set_bus_mute("Master", true)


## Mirrors _begin_ad_pause(). Re-applies _platform_wants_muted() (rather
## than unconditionally unmuting) so a portal that independently wants audio
## muted for its own reason - Bridge's site-wide state, or CrazyGames' own
## muteAudio setting - stays muted once the ad's own mute lifts, instead of
## this stomping that back on. Every call site only calls this when it
## actually called _begin_ad_pause() (or, for GPX, muted directly) for that
## same flow - see show_interstitial()/show_rewarded()'s own
## muted_for_this_ad tracking - since re-applying unconditionally would
## "restore" a mute a flow never actually set (e.g. CrazyGames rejecting a
## request instantly before adStarted ever fires), using a transient reading
## that has nothing to do with the player's real audio preference.
static func _end_ad_pause() -> void:
	Core.toggle_pause(false, "ad")
	Core.sound_manager.set_bus_mute("Master", _platform_wants_muted())


## True when Playgama's own top-level showInterstitial()/showRewarded()
## would silently no-op a fresh call: it refuses to even start a new ad - no
## state change, no event, nothing - whenever EITHER ad type already
## reports itself mid-flight (interstitial LOADING/OPENED, or rewarded
## LOADING/OPENED/REWARDED). That state can get stuck there for real: if a
## previous ad's own portal-side callback never arrives, THIS facade's
## ad_timeout_sec recovers on our end, but Bridge's own internal state is
## never told the ad closed - so it stays stuck "in progress" forever.
## Without this check, the very next show_interstitial()/show_rewarded()
## call - e.g. every later "Next Level" press - would be silently swallowed
## by Playgama's own gate and this facade would then sit waiting the full
## ad_timeout_sec for an event that will never come. Confirmed to actually
## happen in a real, shipped project (read to QA as "the Next Level button
## doesn't work") - verified against the bundled JS source itself, not from
## memory.
static func _bridge_ad_stuck_in_progress() -> bool:
	var interstitial_busy: bool = Bridge.advertisement.interstitial_state == Bridge.InterstitialState.LOADING or Bridge.advertisement.interstitial_state == Bridge.InterstitialState.OPENED
	var rewarded_busy: bool = Bridge.advertisement.rewarded_state == Bridge.RewardedState.LOADING or Bridge.advertisement.rewarded_state == Bridge.RewardedState.OPENED or Bridge.advertisement.rewarded_state == Bridge.RewardedState.REWARDED
	return interstitial_busy or rewarded_busy


## on_reward is called only if the player watched the ad to completion.
## on_no_reward (optional) is called if the ad was skipped/closed early or
## failed to load - use it to just continue without the bonus, never to
## block the player. A call made while a previous one hasn't finished yet
## is silently ignored (neither callback fires for it) - see
## _rewarded_in_progress.
static func show_rewarded(on_reward: Callable, on_no_reward: Callable = Callable()) -> void:
	if _rewarded_in_progress:
		return
	_rewarded_in_progress = true
	# Same tracking as show_interstitial()'s own muted_for_this_ad.
	var muted_for_this_ad := [false]
	# gpx.gd's own _reward_callback() unconditionally .call()s whichever of
	# these it picks, so both must always be real, valid Callables - these
	# wrap the caller's own (on_no_reward may be unset) and always release
	# _rewarded_in_progress no matter which one fires.
	var finish_reward := func():
		_rewarded_in_progress = false
		if muted_for_this_ad[0]:
			_end_ad_pause()
		on_reward.call()
	var finish_no_reward := func():
		_rewarded_in_progress = false
		if muted_for_this_ad[0]:
			_end_ad_pause()
		if on_no_reward.is_valid():
			on_no_reward.call()
	if GPX.gpx != null:
		# _first_to_fire's timeout is the recovery path if GamePix's own
		# rewardAd() promise never resolves at all - past it, this treats
		# the ad as failed/no-reward and force-unpauses, rather than leaving
		# the player stuck on a frozen, paused game forever.
		var wrapped := _first_to_fire([finish_reward, finish_no_reward], finish_no_reward)
		muted_for_this_ad[0] = true
		Core.sound_manager.set_bus_mute("Master", true)
		GPX.rewardAd(wrapped[0], wrapped[1])
		return
	if CG.sdk != null:
		# CrazyGames' own rewarded-ad rule: grant only on adFinished, never
		# on adError - finish_reward/finish_no_reward map onto exactly those
		# two, not a single merged "done" signal. Wrapped through
		# _first_to_fire the same way the GPX branch above is: without it, a
		# hung requestAd() call (adStarted fires but neither adFinished nor
		# adError ever does) would have no recovery path at all.
		var cg_wrapped := _first_to_fire([finish_reward, finish_no_reward], finish_no_reward)
		CG.requestAd("rewarded", func():
			muted_for_this_ad[0] = true
			_begin_ad_pause()
		, cg_wrapped[0], cg_wrapped[1])
		return
	if _bridge_ad_stuck_in_progress():
		finish_no_reward.call()
		return
	muted_for_this_ad[0] = true
	_begin_ad_pause()
	# GDScript lambdas capture locals BY VALUE, and re-snapshot them on every
	# separate invocation - a mutation made during one signal emission is
	# NOT visible the next time this same lambda fires. A one-element Array
	# is a reference type, so slot 0 is a real shared mutable cell both
	# across invocations and for the self-disconnect below.
	var got_reward := [false]
	var self_ref := [Callable()]
	self_ref[0] = func(state: String) -> void:
		if state == Bridge.RewardedState.REWARDED:
			got_reward[0] = true
			finish_reward.call()
		elif state == Bridge.RewardedState.CLOSED or state == Bridge.RewardedState.FAILED:
			Bridge.advertisement.rewarded_state_changed.disconnect(self_ref[0])
			if not got_reward[0]:
				finish_no_reward.call()
	Bridge.advertisement.rewarded_state_changed.connect(self_ref[0])
	Bridge.advertisement.show_rewarded()
