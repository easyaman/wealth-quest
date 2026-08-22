class_name WQSetup
extends RefCounted
## ทอยเต๋าตอนเริ่มเกม = ต้นทุนชีวิต (GDD บทที่ 7) — พอร์ตจาก `rollStart()` ใน ../engine.js
##
## แต้มเต๋าไม่ได้ตัดสินว่าได้อาชีพดีหรือไม่ดี แต่ตัดสินว่าได้ "ทางเลือกกี่ทาง"
## แต้มต่ำได้ชั่วโมงว่างเพิ่มมาชดเชย — ถ้าทอยแล้วเสียเปรียบล้วนๆ ผู้เล่นจะรู้สึกโดนโกงตั้งแต่ยังไม่เริ่ม
##
## ตารางแต้มอยู่ใน `data/config.json` คีย์ `roll_table` เท่านั้น ห้าม hardcode ที่นี่
##
## **ที่ตั้งใจให้ต่างจาก engine.js:** ฝั่ง JS สับไพ่ด้วย `sort(() => rng() - 0.5)`
## ซึ่งผลขึ้นกับอัลกอริทึม sort ของ V8 — พอร์ตให้ตรงเป๊ะไม่ได้ในทางปฏิบัติ
## ที่นี่จึงใช้ Fisher–Yates ที่กินตัวสุ่มตัวเดียวกัน ผลจึง deterministic ต่อ seed เหมือนกัน
## แต่ "ชุดอาชีพที่ได้" ของ seed เดียวกันอาจไม่ตรงกับเว็บต้นแบบ
## ไม่กระทบการตรวจ parity เพราะ `sim/parity_dump.gd` ระบุ job_id ตรงๆ ไม่ได้ผ่านการทอยเต๋า


## คืน {roll, jobs (Array ของ job dict), bonus_hours, label}
## forced_roll > 0 = บังคับแต้ม (ใช้ตอนทดสอบและตอนทำ tutorial)
static func roll_start(seed_value: int, forced_roll := 0) -> Dictionary:
	WQData.load_all()
	# ผสมเมล็ดแบบเดียวกับ engine.js: (seed || 1) * 2654435761 >>> 0
	var mixed := ((maxi(seed_value, 1) * 2654435761) & 0xFFFFFFFF)
	var rng := WQRng.new(mixed)
	var roll := forced_roll if forced_roll > 0 else 1 + rng.range_i(6)
	roll = clampi(roll, 1, 6)

	var t: Dictionary = WQData.cfg.roll_table[str(roll)]
	var tiers: Array = t.tiers
	var pool: Array = []
	for j in WQData.jobs:
		for tier in tiers:
			if int(j.tier) == int(tier):
				pool.append(j)
				break

	var picked: Array = []
	# แต้ม ≥ 4 การันตีอย่างน้อยหนึ่งอาชีพจาก tier สูงสุดที่ปลดล็อก (GDD บทที่ 7)
	if roll >= 4:
		var top := 0
		for tier in tiers: top = maxi(top, int(tier))
		var tops: Array = []
		for j in pool:
			if int(j.tier) == top: tops.append(j)
		if not tops.is_empty(): picked.append(tops[rng.range_i(tops.size())])

	var rest: Array = []
	for j in pool:
		if not picked.has(j): rest.append(j)
	_shuffle(rest, rng)
	while picked.size() < int(t.count) and not rest.is_empty():
		picked.append(rest.pop_back())

	_sort_by_tier_then_salary(picked)
	return {"roll": roll, "jobs": picked,
		"bonus_hours": int(t.bonusHours), "label": String(t.label)}


## ตัวเลขของอาชีพหนึ่งที่หน้าเลือกอาชีพเอาไปโชว์ — **คำนวณจาก core ล้วนๆ**
## สร้าง WQPlayer จริงขึ้นมาหนึ่งตัวแล้วถาม ไม่ใช่คำนวณสูตรซ้ำในฝั่ง UI
##
## ผู้เล่นตัวอย่างไม่มี match — สูตรชั่วโมงทั้งหมดไม่แตะ match จึงถามได้ตามปกติ
## แต่ **ถามค่าใช้จ่ายรวมไม่ได้** เพราะ `get_debt_payments()` ต้องอ่านตัวคูณดอกเบี้ยจากภัยพิบัติ
## ผ่าน `match_ref.get_mods()` (เจอจริงตอนทำหน้าเลือกอาชีพ) ที่หน้าเลือกอาชีพยังไม่มีเกมให้ถาม
## และ "ภาระรายเดือน" ที่ผู้เล่นควรเห็นตอนนั้นคือของประจำอาชีพ ไม่ใช่ของที่ภัยพิบัติทำให้แพงขึ้น
static func job_preview(job_id: String, bonus_hours: int) -> Dictionary:
	var p := WQPlayer.new()
	p.setup(null, {"name": "ตัวอย่าง", "job_id": job_id, "bonus_hours": bonus_hours})
	var debts := 0.0
	for d in p.liabilities: debts += float(d.balance)
	return {
		"job": p.job,
		"free_hours": p.get_hours_max(),
		"raw_free_hours": p.get_raw_free_hours(),
		"salary": p.salary,
		"commute": p.get_commute_hours(),
		"work": p.get_work_hours(),
		"cash": p.cash,
		"health": p.health,
		"monthly_burden": float(p.job.fixed) + float(p.job.food),
		"debts": debts,
	}


## เรียงตาม tier ก่อน แล้วค่อยเงินเดือน — insertion sort เพราะต้อง stable
## (`sort_custom` ของ Godot ไม่ stable · โปรเจกต์นี้โดนพิษข้อนี้มาแล้วตอนพอร์ต best_move)
static func _sort_by_tier_then_salary(arr: Array) -> void:
	for i in range(1, arr.size()):
		var cur = arr[i]
		var j := i - 1
		while j >= 0 and _after(arr[j], cur):
			arr[j + 1] = arr[j]
			j -= 1
		arr[j + 1] = cur


static func _after(a: Dictionary, b: Dictionary) -> bool:
	if int(a.tier) != int(b.tier): return int(a.tier) > int(b.tier)
	return float(a.salary) > float(b.salary)


static func _shuffle(arr: Array, rng: WQRng) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.range_i(i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## ชื่อบอทประจำโต๊ะ — ยกมาจาก `engine.js:254` ให้ตรงกับต้นแบบเว็บ
const BOT_NAMES: Array[String] = [
	"พี่เอ๋ (บอท)", "เจ๊หมวย (บอท)", "น้องบีม (บอท)", "ลุงวิรัช (บอท)"]

## จำนวนที่นั่งของหนึ่งโต๊ะ — คนจริงกี่คนก็ได้ ที่เหลือเป็นบอท (GDD บทที่ 10)
const SEATS := 4


## รับที่นั่งของคนจริงเข้ามา คืนที่นั่ง **ทั้งโต๊ะ** ที่พร้อมส่งให้ `WQMatch.setup()`
##
## `rng` ต้องเป็นตัวสุ่ม **คนละตัว** กับของแมตช์เสมอ — ตัวสุ่มของแมตช์ต้องเดินตรงกับ
## `engine.js` ทีละครั้ง ถ้าดึงเลขจากมันมาเลือกอาชีพบอท ผลทั้ง 960 เกมจะเลื่อนหมด
## และไม่มีสูทไหนจับได้นอกจาก `parity_dump`
##
## บอทเลี่ยงอาชีพที่มีคนในโต๊ะใช้แล้ว (ตรงกับ `ui.html:421`) เพื่อให้โต๊ะหน้าตาไม่ซ้ำกัน
## ส่วนคนจริงเลือกซ้ำกันเองได้ ต้นแบบไม่เคยห้าม
static func fill_bots(seats: Array, rng: WQRng) -> Array:
	WQData.load_all()
	var out: Array = seats.duplicate()
	var used := {}
	for s in out:
		used[String((s as Dictionary).get("job_id", ""))] = true
	var pool: Array = []
	for j in WQData.jobs:
		if not used.has(String(j.id)): pool.append(j)
	var i := 0
	while out.size() < SEATS and not pool.is_empty():
		var j: Dictionary = pool.pop_at(rng.range_i(pool.size()))
		out.append({
			"name": BOT_NAMES[i % BOT_NAMES.size()],
			"job_id": String(j.id), "is_ai": true,
			# อาชีพรายได้น้อยได้ชั่วโมงว่างเพิ่มเหมือนที่คนจริงได้จากแต้มเต๋าต่ำ
			"bonus_hours": 20 if int(j.tier) <= 1 else 0})
		i += 1
	return out
