## CrazyGames SDK (hand-written)

Hand-written wrapper over CrazyGames' own JS SDK
(https://sdk.crazygames.com/crazygames-sdk-v3.js), following the exact same
pattern as `addons/gpx-godot-plugin` in this repo. Written this way because,
as of writing, there is no working official Godot 4 package to install
instead - both URLs CrazyGames' own generic SDK docs point to for it
(`docs.crazygames.com/sdk/godot/intro/` and
`store.godotengine.org/asset/crazygames/crazysdk/`) 404/403. Their own
community reference project
(https://github.com/PlayWithFurcifer/GodotCrazySDKTemplate) hand-wraps the
JS SDK the same way - this is the accepted approach for CrazyGames+Godot
right now, not a workaround.

### Enabling

* Open **Project -> Project Settings -> Plugins**
* Enable **crazygames-sdk**
* This adds a **CrazyGames** Web export preset (pointed at this addon's own
  `index.html`) if one doesn't already exist, and registers the `CG`
  autoload - both done through the editor's own `EditorPlugin` API
  (`plugin.gd`), the same way `gpx-godot-plugin` does it, not by
  hand-editing `export_presets.cfg`.
* Export using the **CrazyGames** preset, publish the output on
  developer.crazygames.com.

### Using the SDK

Game code should go through `SDK.gd` (`res://template/sdk/sdk.gd`), not
`CG` directly - same rule this project already applies to `Bridge`/`GPX`.
`SDK.gd` already wires:

* `SDK.notify_gameplay_started()` / `notify_gameplay_stopped()` -> `CG.gameplayStart()` / `CG.gameplayStop()`
* `SDK.show_interstitial()` -> `CG.requestAd("midgame", ...)`
* `SDK.show_rewarded()` -> `CG.requestAd("rewarded", ...)`, rewarding only on `adFinished`, never `adError` (CrazyGames' own explicit rule)

`CG.sdk` is `null` until `SDK.init()`'s promise resolves AND CrazyGames
reports itself not `"disabled"` (i.e. not actually running on a CrazyGames
domain) - every `CG` method already checks this and no-ops safely, so
callers never need their own check.

### Not yet verified against a live browser session

This addon has not yet been exported and run on an actual crazygames.com
page. Every JS API call it makes (`SDK.init()`, `SDK.environment`,
`SDK.ad.requestAd()`, `SDK.game.gameplayStart()/gameplayStop()`) is
transcribed directly from docs.crazygames.com (`/sdk/intro`,
`/sdk/video-ads`, `/sdk/game`), not memory or a third-party guide - but a
real playtest on CrazyGames is still the only way to confirm the
`JavaScriptBridge.create_object("Object")` + property-assignment approach
for building the `{adStarted, adFinished, adError}` callbacks object
actually behaves as expected against their real SDK.
