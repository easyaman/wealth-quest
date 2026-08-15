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
