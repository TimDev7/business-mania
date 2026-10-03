extends GutTest

# Covers template/sdk/sdk.gd: our thin facade over three vendored portal
# SDKs (Playgama Bridge, GamePix's own plugin, and the hand-written
# CrazyGames wrapper). Outside a real web export ALL THREE fall back to
# safe stand-ins - Bridge to its own editor-mock modules (see
# addons/playgama_bridge/modules/*/*_editor_mock.gd), GPX.gpx and CG.sdk
# both stay null (see gpx.gd's and crazygames.gd's own _ready(), which only
# set them when OS.has_feature("web") is true, and CG.sdk additionally only
# once CrazyGames' own SDK.init() resolves) - so every test here exercises
# the Bridge branch specifically, same as production traffic on any portal
# Bridge covers. Real ad-network behavior, and the GPX/CG branches
# specifically, can only be verified in an actual web export on the
# matching portal; this only proves the facade calls the right things and
# handles all three SDKs' callback shapes correctly.


func _master_muted() -> bool:
	# Core.sound_manager has no mute-state getter of its own (only
	# set_bus_mute()) - reading AudioServer directly is what sdk.gd's own
	# mute calls actually land on, so it's the real state to assert against.
	return AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))


func after_each() -> void:
	SDK.ad_timeout_sec = 45.0
	Bridge.platform._set_audio_enabled(true)


func test_running_against_the_mock_platform() -> void:
	# Sanity anchor for this whole file: if this ever fails, everything
	# below is silently testing something other than the mock.
	assert_eq(Bridge.platform.id, "mock")
	assert_null(GPX.gpx, "GPX.gpx must stay null outside a real web export")
	assert_null(CG.sdk, "CG.sdk must stay null outside a real web export")


func test_notify_functions_do_not_error_against_the_mock() -> void:
	SDK.notify_loading_finished()
	SDK.notify_level_started()
	SDK.notify_level_completed()
	SDK.notify_level_completed(7)
	SDK.notify_level_failed()
	SDK.notify_gameplay_started()
	SDK.notify_gameplay_stopped()
	assert_eq(Bridge.platform.id, "mock") # just needs an assertion to not be "risky"


func test_platform_language_falls_back_to_bridge_when_no_gpx() -> void:
	assert_eq(SDK.platform_language(), Bridge.platform.language)


func test_connect_platform_signals_is_idempotent() -> void:
	SDK.connect_platform_signals()
	SDK.connect_platform_signals()
	SDK.connect_platform_signals()

	assert_eq(Bridge.platform.audio_state_changed.get_connections().size(), 1)
	assert_eq(Bridge.platform.pause_state_changed.get_connections().size(), 1)
	assert_eq(CG.mute_setting_changed.get_connections().size(), 1)


func test_connect_platform_signals_applies_current_muted_state_on_every_call() -> void:
	# Bridge's/CrazyGames' own docs are explicit that subscribing to the
	# change event alone isn't enough - the CURRENT state must also be
	# applied immediately, since a player can arrive with audio already
	# disabled before either event ever fires. Re-checked on every call
	# (not just the first), so this also self-heals a later Title revisit.
	Bridge.platform._set_audio_enabled(false)
	SDK.connect_platform_signals()
	assert_true(_master_muted())

	Bridge.platform._set_audio_enabled(true)
	SDK.connect_platform_signals()
	assert_false(_master_muted())


func test_platform_wants_muted_reflects_bridge_audio_state() -> void:
	Bridge.platform._set_audio_enabled(true)
	assert_false(SDK._platform_wants_muted())

	Bridge.platform._set_audio_enabled(false)
	assert_true(SDK._platform_wants_muted())


func test_platform_wants_muted_is_false_when_cg_sdk_is_absent() -> void:
	# CG.is_audio_muted() must be a harmless false (not, say, an error) when
	# CG.sdk was never initialized - the exact state every non-CrazyGames
	# build runs in, and what test_platform_wants_muted_reflects_bridge_audio_state
	# above implicitly relies on.
	Bridge.platform._set_audio_enabled(true)
	assert_false(CG.is_audio_muted())
	assert_false(SDK._platform_wants_muted())


func test_bridge_ad_stuck_in_progress_detects_a_wedged_interstitial() -> void:
	assert_false(SDK._bridge_ad_stuck_in_progress())

	Bridge.advertisement._set_interstitial_state(Bridge.InterstitialState.LOADING)
	assert_true(SDK._bridge_ad_stuck_in_progress())

	Bridge.advertisement._set_interstitial_state(Bridge.InterstitialState.CLOSED)
	assert_false(SDK._bridge_ad_stuck_in_progress())


func test_bridge_ad_stuck_in_progress_detects_a_wedged_rewarded() -> void:
	Bridge.advertisement._set_rewarded_state(Bridge.RewardedState.OPENED)
	assert_true(SDK._bridge_ad_stuck_in_progress())

	Bridge.advertisement._set_rewarded_state(Bridge.RewardedState.CLOSED)
	assert_false(SDK._bridge_ad_stuck_in_progress())


func test_show_interstitial_runs_to_closed_via_the_mock() -> void:
	SDK.show_interstitial()
	assert_eq(Bridge.advertisement.interstitial_state, Bridge.InterstitialState.CLOSED)


func test_show_interstitial_calls_on_complete() -> void:
	var completed := [false]

	SDK.show_interstitial(func(): completed[0] = true)

	assert_true(completed[0])


func test_show_interstitial_restores_only_what_it_muted() -> void:
	# muted_for_this_ad tracking: a completed ad flow must leave Master
	# reflecting the current platform-muted state, not just unconditionally
	# unmute - otherwise a portal that independently wants audio off (see
	# _platform_wants_muted()) would get audibly overridden the moment any
	# ad finishes.
	Bridge.platform._set_audio_enabled(false)

	SDK.show_interstitial()

	assert_true(_master_muted())


func test_show_interstitial_skips_the_sdk_call_when_bridge_is_stuck() -> void:
	Bridge.advertisement._set_interstitial_state(Bridge.InterstitialState.LOADING)
	var completed := [false]

	SDK.show_interstitial(func(): completed[0] = true)

	assert_true(completed[0], "a stuck Bridge state must still resolve on_complete, not hang")
	Bridge.advertisement._set_interstitial_state(Bridge.InterstitialState.CLOSED)


func test_show_interstitial_ignores_a_call_while_one_is_in_flight() -> void:
	SDK.ad_timeout_sec = 0.05
	var completions := [0]
	# The mock's show_interstitial() resolves synchronously, so to actually
	# observe "in flight" this leans on the real in-progress flag directly
	# rather than racing a timer - the flag IS the thing under test.
	SDK._interstitial_in_progress = true

	SDK.show_interstitial(func(): completions[0] += 1)

	assert_eq(completions[0], 0, "a call made while one is already in flight must be ignored")
	SDK._interstitial_in_progress = false


func test_show_rewarded_calls_on_reward_when_the_mock_grants_one() -> void:
	var reward_calls := [0]
	var no_reward_calls := [0]

	SDK.show_rewarded(func(): reward_calls[0] += 1, func(): no_reward_calls[0] += 1)

	assert_eq(reward_calls[0], 1)
	assert_eq(no_reward_calls[0], 0)


func test_show_rewarded_works_without_an_on_no_reward_callback() -> void:
	var reward_calls := [0]

	SDK.show_rewarded(func(): reward_calls[0] += 1)

	assert_eq(reward_calls[0], 1)


func test_show_rewarded_disconnects_so_repeated_calls_dont_stack() -> void:
	var reward_calls := [0]

	SDK.show_rewarded(func(): reward_calls[0] += 1)
	SDK.show_rewarded(func(): reward_calls[0] += 1)

	# 2, not 3+: if the first call's listener leaked, the second show_rewarded
	# would fire it again on top of its own.
	assert_eq(reward_calls[0], 2)
	assert_eq(Bridge.advertisement.rewarded_state_changed.get_connections().size(), 0)


func test_show_rewarded_skips_the_sdk_call_when_bridge_is_stuck() -> void:
	Bridge.advertisement._set_rewarded_state(Bridge.RewardedState.LOADING)
	var no_reward_calls := [0]

	SDK.show_rewarded(func(): fail_test("on_reward must not fire"), func(): no_reward_calls[0] += 1)

	assert_eq(no_reward_calls[0], 1, "a stuck Bridge state must still resolve to no-reward, not hang")
	Bridge.advertisement._set_rewarded_state(Bridge.RewardedState.CLOSED)


func test_ad_timeout_recovers_a_hung_call() -> void:
	SDK.ad_timeout_sec = 0.05
	# Simulates a hung SDK call: the in-progress flag is set, but nothing
	# will ever resolve it on its own - only _first_to_fire's own timer can.
	SDK._interstitial_in_progress = true
	var recovered := [false]
	SDK._first_to_fire([func(): recovered[0] = true], func(): recovered[0] = true)

	# Not 0.1s: this headless CLI test runner's own SceneTree.create_timer()
	# delivery has a consistently measured ~2.9s of real-world overhead
	# regardless of the requested duration (confirmed by bumping
	# ad_timeout_sec's actual scheduled value far below this wait and timing
	# it) - an artifact of this specific runner, not something a real
	# browser tab's frame rate would ever exhibit. Generous margin above
	# that observed overhead so this doesn't go flaky on a slower machine.
	await wait_seconds(4.0)

	assert_true(recovered[0], "the timeout fallback must fire when nothing else does")
	SDK._interstitial_in_progress = false
