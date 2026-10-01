extends RefCounted
## Deterministic lesson rules, independent of rendering and audio.
const TITLES := ["Find the notes", "Echo meadow", "Canopy concert", "Singing stairway"]
const MELODIES := [[], [[0, 2, 4], [4, 2, 0], [0, 1, 2]], [[0, 2, 4, 2], [2, 3, 4, 7], [7, 4, 2, 0]], [[0], [1], [2], [1], [0]]]
const MAX_SCORES := [80, 120, 150, 100]
var records: Array = []
var stage := 1
var phase := "explore"
var score := 0
var mistakes := 0
var round_index := 0
var answer_index := 0
var collected: Array = []
var stars := 0

func _init() -> void:
	for i in range(4): records.append({"complete": false, "score": 0, "stars": 0})
	begin(1)

func unlocked() -> int:
	for i in range(3):
		if not records[i].complete: return i + 1
	return 4

func begin(number: int) -> bool:
	if number < 1 or number > unlocked(): return false
	stage = number
	phase = "explore" if stage == 1 else "ready"
	score = 0
	mistakes = 0
	round_index = 0
	answer_index = 0
	stars = 0
	collected.clear()
	return true

func melody() -> Array:
	if stage == 1 or round_index >= MELODIES[stage - 1].size(): return []
	return MELODIES[stage - 1][round_index].duplicate()

func explore(note: int) -> bool:
	if stage != 1 or phase != "explore" or note < 0 or note > 7 or collected.has(note): return false
	collected.append(note)
	score += 10
	if collected.size() == 8: _finish()
	return true

func listen() -> bool:
	if stage == 1 or phase not in ["ready", "answer"]: return false
	phase = "listening"
	answer_index = 0
	return true

func demo_finished() -> void:
	if phase == "listening": phase = "answer"

func submit(note: int) -> String:
	if phase != "answer" or note < 0 or note > 7: return "ignored"
	var target := melody()
	if note != target[answer_index]:
		mistakes += 1
		answer_index = 0
		return "retry"
	answer_index += 1
	if answer_index < target.size(): return "correct"
	# Award each melody once, never each partial attempt.
	score += 20 if stage == 4 else target.size() * 10
	round_index += 1
	answer_index = 0
	if round_index == MELODIES[stage - 1].size():
		if stage != 4: score += maxi(0, 30 - mistakes * 5)
		_finish()
		return "complete"
	phase = "ready"
	return "round"

func _finish() -> void:
	phase = "complete"
	stars = 3 if mistakes == 0 else (2 if mistakes <= 3 else 1)
	var record: Dictionary = records[stage - 1]
	record.complete = true
	record.score = maxi(record.score, score)
	record.stars = maxi(record.stars, stars)

func total() -> int:
	var result := 0
	for record in records: result += int(record.score)
	return result

func progress() -> Dictionary:
	return {"version": 1, "records": records.duplicate(true)}

func restore(value: Variant) -> void:
	if not value is Dictionary or value.get("version") != 1: return
	var saved: Variant = value.get("records")
	if not saved is Array or saved.size() not in [3, 4]: return
	for i in range(saved.size()):
		var entry: Variant = saved[i]
		if not entry is Dictionary or entry.get("complete") != true: break
		if not (entry.get("score") is float or entry.get("score") is int): break
		if not (entry.get("stars") is float or entry.get("stars") is int): break
		records[i] = {"complete": true, "score": clampi(int(entry.score), 0, MAX_SCORES[i]), "stars": clampi(int(entry.stars), 1, 3)}

func snapshot() -> Dictionary:
	return {"stage": stage, "title": TITLES[stage-1], "phase": phase, "score": score,
		"mistakes": mistakes, "round": mini(round_index + 1, 5 if stage == 4 else 3), "answer": answer_index,
		"length": melody().size(), "collected": collected.size(), "stars": stars,
		"unlocked": unlocked(), "records": records, "total": total()}
