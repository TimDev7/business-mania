extends Node
class_name GameEventBus
# warning-ignore-all:unused_signal

signal logged()

# --- CORE ---
signal ad_reward_received(ad_name) # ad_name: String

# --- GAME ---
signal buildings_changed()
signal upgrades_changed()
signal pps_recalculated()
signal enumerate_offline_production(pps) # pps: float


# --- UI ---
signal raise_window_with_data(data) # data: Dictionary
