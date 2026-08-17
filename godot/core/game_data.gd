class_name WQData
extends RefCounted
## โหลดตารางข้อมูลทั้งหมดจาก res://data/*.json
## ตัวเลขสมดุลอยู่ในไฟล์ JSON ทั้งหมด — แก้ได้โดยไม่ต้องแตะโค้ด

static var jobs: Array = []
static var deal_pool: Array = []
static var big_deals: Array = []
static var mega_deals: Array = []
static var events1: Array = []
static var events2: Array = []
static var disasters: Array = []
static var dreams: Array = []
static var places: Array = []
static var vehicles: Array = []
static var devices: Array = []
static var gym_packs: Array = []
static var resort_packs: Array = []
static var cfg: Dictionary = {}
static var _loaded := false

static func load_all() -> void:
	if _loaded: return
	jobs = _json("res://data/jobs.json")
	var d = _json("res://data/deals.json")
	deal_pool = d.pool; big_deals = d.big; mega_deals = d.mega
	var e = _json("res://data/events.json")
	events1 = e.phase1; events2 = e.phase2
	disasters = _json("res://data/disasters.json")
	dreams = _json("res://data/dreams.json")
	var pl = _json("res://data/places.json")
	places = pl.places; vehicles = pl.vehicles; devices = pl.devices
	gym_packs = pl.gym_packs; resort_packs = pl.resort_packs
	cfg = _json("res://data/config.json")
	_loaded = true

static func _json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "ไม่พบไฟล์ข้อมูล: " + path)
	return JSON.parse_string(f.get_as_text())

static func job(id: String) -> Dictionary:
	for j in jobs:
		if j.id == id: return j
	return jobs[0]

static func disaster(id: String) -> Dictionary:
	for d in disasters:
		if d.id == id: return d
	return {}

static func _by_id(arr: Array, id: String) -> Dictionary:
	for x in arr:
		if x.id == id: return x
	return {}

## เงินดาวน์ที่ถูกที่สุดที่ตลาดมีให้ — ใช้เป็นพื้นของการันตี "ดีลที่คนจนที่สุดเอื้อม"
## คำนวณจากตารางจริง ห้าม hardcode ไม่งั้นแก้ data แล้วเกณฑ์จะเพี้ยนเงียบๆ
static func cheapest_down() -> float:
	var lo := INF
	for t in deal_pool: lo = minf(lo, roundf(float(t.min) * float(t.downPct[0])))
	return 0.0 if lo == INF else lo

static func place(id: String) -> Dictionary: return _by_id(places, id)
static func device(id: String) -> Dictionary: return _by_id(devices, id)
static func gym_pack(id: String) -> Dictionary: return _by_id(gym_packs, id)
static func resort_pack(id: String) -> Dictionary: return _by_id(resort_packs, id)

## พาหนะเรียงจากช้าไปเร็ว — ลำดับใน array คือระดับ ใช้เทียบว่าอัปเกรดหรือดาวน์เกรด
static func vehicle(id: String) -> Dictionary:
	var v := _by_id(vehicles, id)
	return vehicles[0] if v.is_empty() else v

static func vehicle_index(id: String) -> int:
	for i in vehicles.size():
		if vehicles[i].id == id: return i
	return 0
