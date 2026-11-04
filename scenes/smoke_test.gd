extends Node

var session: GameSession

func _ready() -> void:
	var errs := []
	GameConfig.load_default(errs)
	print("GameConfig errors: ", errs)

	session = GameSession.create_default()
	session.director_client = $DirectorClient
	session.cycle_started.connect(func(i): print("cycle_started ", i))
	session.cycle_finished.connect(func(summary): print("cycle_finished ", summary))
	session.piggy_changed.connect(func(v): print("piggy_changed ", v))

	session.new_player()
	var run := session.start_cycle()
	run.step_started.connect(func(step): print("step_started: ", step))
	run.step_finished.connect(func(step, outcome): print("step_finished: ", outcome))

func _process(delta: float) -> void:
	if session:
		session.tick(delta)
