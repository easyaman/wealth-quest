class_name WQSave
extends RefCounted
## บันทึก/โหลด — เก็บ state ของตัวสุ่มด้วยเสมอ ไม่งั้นผู้เล่นจะ save-scum ได้
## ไฟล์เซฟอยู่ที่ user://saves/ (ต่อ Steam Cloud ได้ตรงๆ)

const VERSION := 5   # 5 = เพิ่มระบบแผนที่/การเดินทาง (place, vehicle, devices, gym_pack, shield)
const DIR := "user://saves"

static func to_dict(m: WQMatch) -> Dictionary:
	var ps: Array = []
	for p in m.players:
		ps.append({
			"name": p.pname, "is_ai": p.is_ai, "job_id": p.job.id, "roll": p.roll,
			"bonus_hours": p.bonus_hours, "cash": p.cash, "salary": p.salary,
			"fixed_expenses": p.fixed_expenses, "food_base": p.food_base,
			"child_cost": p.child_cost, "child_hours": p.child_hours,
			"assets": p.assets, "liabilities": p.liabilities,
			"sleep_idx": p.sleep_idx, "food_id": p.food_id, "health": p.health,
			"time_penalty": p.time_penalty, "side_used": p.side_used,
			"study_level": p.study_level, "study_progress": p.study_progress,
			"downsize_left": p.downsize_left, "bankrupt": p.bankrupt,
			"finished": p.finished, "phase": p.phase, "dream": p.dream,
			"dream_done": p.dream_done, "retired": p.retired,
			"pending_dream": p.pending_dream, "hours": p.hours, "history": p.history,
			"place": p.place, "travel_used": p.travel_used, "vehicle": p.vehicle,
			"devices": p.devices, "gym_pack": p.gym_pack, "shield": p.shield,
			"exercise_this_month": p.exercise_this_month,
			"rested_this_month": p.rested_this_month})
	var ds: Array = []
	for d in m.active_disasters:
		ds.append({"id": d.def.id, "left": d.left})
	return {"v": VERSION, "mode": m.mode, "month": m.month, "rng": m.rng.s,
		"market_index": m.market_index, "market_trend": m.market_trend,
		"deal_id_seq": m.deal_id_seq, "deals": m.deals, "logs": m.logs,
		"state": m.state, "start_index": m.start_index, "turn": m.turn,
		"disaster_cooldown": m.disaster_cooldown, "active_disasters": ds,
		"disaster_history": m.disaster_history, "champions": m.champions,
		"players": ps}

static func from_dict(data: Dictionary) -> WQMatch:
	assert(int(data.get("v", 0)) == VERSION, "ไฟล์เซฟคนละเวอร์ชัน")
	WQData.load_all()
	var m := WQMatch.new()
	m.mode = data.mode; m.month = int(data.month)
	m.rng = WQRng.new(0); m.rng.s = int(data.rng)
	m.market_index = data.market_index; m.market_trend = data.market_trend
	m.deal_id_seq = int(data.deal_id_seq); m.deals = data.deals; m.logs = data.logs
	m.state = data.state; m.start_index = int(data.start_index); m.turn = int(data.turn)
	m.disaster_cooldown = int(data.disaster_cooldown)
	m.disaster_history = data.disaster_history; m.champions = data.champions
	for d in data.active_disasters:
		var def := WQData.disaster(d.id)
		if not def.is_empty(): m.active_disasters.append({"def": def, "left": int(d.left)})
	for pd in data.players:
		var p := WQPlayer.new()
		p.match_ref = m
		p.job = WQData.job(pd.job_id)
		p.pname = pd.name; p.is_ai = pd.is_ai; p.roll = int(pd.roll)
		p.bonus_hours = int(pd.bonus_hours); p.cash = pd.cash; p.salary = pd.salary
		p.fixed_expenses = pd.fixed_expenses; p.food_base = pd.food_base
		p.child_cost = pd.child_cost; p.child_hours = int(pd.child_hours)
		p.assets = pd.assets; p.liabilities = pd.liabilities
		p.sleep_idx = int(pd.sleep_idx); p.food_id = pd.food_id; p.health = pd.health
		p.time_penalty = int(pd.time_penalty); p.side_used = int(pd.side_used)
		p.study_level = int(pd.study_level); p.study_progress = pd.study_progress
		p.downsize_left = int(pd.downsize_left); p.bankrupt = pd.bankrupt
		p.finished = int(pd.finished); p.phase = int(pd.phase); p.dream = pd.dream
		p.dream_done = int(pd.dream_done); p.retired = pd.retired
		p.pending_dream = pd.pending_dream; p.hours = int(pd.hours); p.history = pd.history
		p.place = pd.get("place", "home"); p.travel_used = int(pd.get("travel_used", 0))
		p.vehicle = pd.get("vehicle", "public"); p.devices = pd.get("devices", [])
		p.gym_pack = pd.get("gym_pack", ""); p.shield = float(pd.get("shield", 0.0))
		p.exercise_this_month = int(pd.get("exercise_this_month", 0))
		p.rested_this_month = pd.get("rested_this_month", false)
		m.players.append(p)
	return m

static func write_slot(m: WQMatch, slot: int) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open("%s/slot%d.json" % [DIR, slot], FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(m)))
	return OK

static func read_slot(slot: int) -> WQMatch:
	var path := "%s/slot%d.json" % [DIR, slot]
	if not FileAccess.file_exists(path): return null
	var f := FileAccess.open(path, FileAccess.READ)
	return from_dict(JSON.parse_string(f.get_as_text()))
