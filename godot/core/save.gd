class_name WQSave
extends RefCounted
## บันทึก/โหลด — เก็บ state ของตัวสุ่มด้วยเสมอ ไม่งั้นผู้เล่นจะ save-scum ได้
## ไฟล์เซฟอยู่ที่ user://saves/ (ต่อ Steam Cloud ได้ตรงๆ)

const VERSION := 6   # 6 = เพิ่มหัวไฟล์ (meta) สำหรับหน้าบันทึก/โหลด + ช่อง ui สำหรับสถานะการสอน
## โฟลเดอร์ไฟล์เซฟ — เป็น `static var` ไม่ใช่ const เพราะ **เทสต์ต้องเขียนคนละที่กับของผู้เล่น**
## (ถ้าเทสต์เขียนทับ `user://saves` วันไหนที่รันเทสต์บนเครื่องที่มีเกมเซฟจริงอยู่ ของผู้เล่นหายทันที)
static var dir := "user://saves"

## ช่องเซฟที่มีทั้งหมด — สามช่องแรกผู้เล่นกดเอง สามช่องหลังเกมเขียนให้เองทุกสิ้นเดือน
## (GDD 14.3 แนะนำ autosave วนเก็บ 3 ช่อง — เก็บช่องเดียวแปลว่าเดือนที่พลาดทับของเดิมไปแล้ว)
const MANUAL_SLOTS: Array[String] = ["1", "2", "3"]
const AUTO_SLOTS: Array[String] = ["auto1", "auto2", "auto3"]


static func path_for(slot: String) -> String:
	return "%s/slot%s.json" % [dir, slot]


static func is_auto(slot: String) -> bool:
	return AUTO_SLOTS.has(slot)


## `extra` คือของฝั่ง UI ที่ต้องกลับมาเหมือนเดิมตอนโหลด (ตอนนี้มีสถานะการสอน)
## core ไม่แตะข้างในเลย เก็บและคืนเป็นก้อนเดียว — กฎข้อ 1 ของโปรเจกต์ยังอยู่ครบ
static func to_dict(m: WQMatch, extra: Dictionary = {}) -> Dictionary:
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
	return {"v": VERSION, "meta": meta_of(m), "ui": extra,
		"mode": m.mode, "month": m.month, "rng": m.rng.s,
		"market_index": m.market_index, "market_trend": m.market_trend,
		"deal_id_seq": m.deal_id_seq, "deals": m.deals, "logs": m.logs,
		"state": m.state, "start_index": m.start_index, "turn": m.turn,
		"disaster_cooldown": m.disaster_cooldown, "active_disasters": ds,
		"disaster_history": m.disaster_history, "champions": m.champions,
		"players": ps}

## หัวไฟล์ที่หน้าบันทึก/โหลดเอาไปโชว์ — ต้องอ่านได้โดย **ไม่ต้องสร้าง WQMatch ขึ้นมาทั้งตัว**
## ไม่งั้นแค่เปิดหน้ารายการเซฟก็ต้องประกอบเกมหกเกมพร้อมกัน
static func meta_of(m: WQMatch) -> Dictionary:
	var who = null
	for p in m.players:
		if not p.is_ai:
			who = p
			break
	if who == null and not m.players.is_empty(): who = m.players[0]
	return {
		"saved_at": int(Time.get_unix_time_from_system()),
		"month": m.month, "mode": m.mode,
		"name": String(who.pname) if who != null else "",
		"job": String(who.job.get("name", "")) if who != null else "",
		"job_icon": String(who.job.get("icon", "")) if who != null else "",
		"job_id": String(who.job.get("id", "")) if who != null else "",
		"net_worth": roundi(who.get_net_worth()) if who != null else 0,
		"phase": int(who.phase) if who != null else 1,
	}


## ข้อมูลของช่องหนึ่งสำหรับหน้ารายการเซฟ — ไม่มีไฟล์ก็คืน `{"empty": true}`
## ไฟล์คนละเวอร์ชันต้องบอกให้ชัดว่าโหลดไม่ได้ ไม่ใช่ทำเป็นว่าช่องนั้นว่าง
static func slot_info(slot: String) -> Dictionary:
	var path := path_for(slot)
	if not FileAccess.file_exists(path): return {"empty": true, "slot": slot}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {"empty": true, "slot": slot}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY: return {"empty": true, "slot": slot, "broken": true}
	var info: Dictionary = (data as Dictionary).get("meta", {}).duplicate()
	info["empty"] = false
	info["slot"] = slot
	info["version_ok"] = int((data as Dictionary).get("v", 0)) == VERSION
	return info


static func has_any() -> bool:
	for slot in MANUAL_SLOTS + AUTO_SLOTS:
		if FileAccess.file_exists(path_for(slot)): return true
	return false


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

static func write_slot(m: WQMatch, slot: String, extra: Dictionary = {}) -> Error:
	return _write(slot, to_dict(m, extra))


static func _write(slot: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data))
	return OK


static func read_slot(slot: String) -> WQMatch:
	var path := path_for(slot)
	if not FileAccess.file_exists(path): return null
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY: return null
	return from_dict(data)


## ของฝั่ง UI ที่ฝากไว้ในไฟล์ (สถานะการสอน) — อ่านแยกจากตัวแมตช์เพราะคนละเจ้าของ
static func read_extra(slot: String) -> Dictionary:
	var path := path_for(slot)
	if not FileAccess.file_exists(path): return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY: return {}
	return (data as Dictionary).get("ui", {})


## autosave — วนทับ **ช่องที่เก่าที่สุด** เสมอ (ช่องว่างถือว่าเก่าที่สุด)
##
## เรียงลำดับด้วยตัวนับ `seq` ที่อ่านจากไฟล์จริง ไม่ใช่เวลานาฬิกา เพราะ `saved_at` ละเอียดแค่วินาที
## ผู้เล่นที่กด Space รัวๆ จบสามเดือนในวินาทีเดียวจะได้ autosave ที่เวลาเท่ากันหมด แล้ววง
## สามช่องจะยุบเหลือช่องเดียวทันทีตอนที่ต้องการมันที่สุด · และไม่เก็บตัวนับไว้นอกไฟล์
## เพราะวันที่ผู้เล่นลบไฟล์เองหรือย้ายเครื่อง ตัวนับกับไฟล์จะไม่ตรงกัน
static func write_auto(m: WQMatch, extra: Dictionary = {}) -> Error:
	var oldest: String = AUTO_SLOTS[0]
	var lowest := 1 << 62
	var next := 0
	for slot in AUTO_SLOTS:
		var info := slot_info(slot)
		var seq: int = -1 if info.get("empty", true) else int(info.get("seq", 0))
		next = maxi(next, seq + 1)
		if seq < lowest:
			lowest = seq
			oldest = slot
	var data := to_dict(m, extra)
	(data.meta as Dictionary)["seq"] = next
	return _write(oldest, data)
