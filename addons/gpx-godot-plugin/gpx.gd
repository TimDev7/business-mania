extends Node

var gpx = null
var _gpx_interstitial_cb = null
var _gpx_interstitial_cb_fn = null
var _gpx_reward_cb = null
var _gpx_reward_cb_success_fn = null
var _gpx_reward_cb_fail_fn = null

func _ready():
	# Same reasoning as bridge.gd's own _ready(): JavaScriptBridge.get_interface()
	# logs a red engine-level ERROR to the console whenever the named
	# interface doesn't exist, so this checks window.GamePix's existence
	# first via a quiet eval() and only calls get_interface() when it's
	# actually there - confirmed live in a real CrazyGames QA preview
	# session, which printed "ERROR: No interface 'GamePix' registered." on
	# every load despite this never being a GamePix build at all. The old
	# printerr() below only fires now for the genuinely unexpected case
	# (window.GamePix exists but get_interface() still somehow returns
	# null) - SDK.gd's own notify_loading_finished() already logs the
	# ordinary "not a GamePix build" case elsewhere.
	if OS.has_feature("web") and JavaScriptBridge.eval("typeof window.GamePix !== 'undefined'", true):
		gpx = JavaScriptBridge.get_interface("GamePix")
		if gpx == null:
			printerr("GamePix SDK not found")
		_gpx_interstitial_cb = JavaScriptBridge.create_callback(_interstitial_callback)
		_gpx_reward_cb = JavaScriptBridge.create_callback(_reward_callback)

func lang():
	if gpx != null:
		return gpx.lang()
	return "en"

func setItem(key, value):
	if gpx != null:
		gpx.localStorage.setItem(key, value)

func getItem(key):
	if gpx != null:
		return gpx.localStorage.getItem(key)
	
	return null

func updateScore(score):
	if gpx != null:
		gpx.updateScore(score)

func updateLevel(level):
	if gpx != null:
		gpx.updateLevel(level)

func happyMoment():
	if gpx != null:
		gpx.happyMoment()

func interstitialAd(fn = null):
	if gpx != null:
		_gpx_interstitial_cb_fn = fn
		get_tree().paused = true
		gpx.interstitialAd().then(_gpx_interstitial_cb)
	elif fn != null:
		fn.call()

func _interstitial_callback(args):
	if _gpx_interstitial_cb_fn != null:
		_gpx_interstitial_cb_fn.call()
	_gpx_interstitial_cb_fn = null
	get_tree().paused = false

func rewardAd(success = null, fail = null):
	if gpx != null:
		_gpx_reward_cb_success_fn = success
		_gpx_reward_cb_fail_fn = fail
		get_tree().paused = true
		gpx.rewardAd().then(_gpx_reward_cb)
	elif success != null:
		success.call()
	elif fail != null:
		fail.call()

func _reward_callback(args):
	if args[0].success:
		_gpx_reward_cb_success_fn.call()
	else:
		_gpx_reward_cb_fail_fn.call()

	_gpx_reward_cb_success_fn = null
	_gpx_reward_cb_fail_fn = null
	get_tree().paused = false
