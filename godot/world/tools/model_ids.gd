class_name WQModelIds
extends RefCounted
## รายชื่อโมเดลทั้งหมดที่เกมต้องมี — อ่านจาก data/*.json ที่เดียว ไม่พิมพ์รายชื่อด้วยมือ
##
## ที่ต้องมีไฟล์นี้: ตัวอบไอคอน · ตัวตรวจโมเดล · ตัวสร้าง README ต้องมองเห็นรายการ
## ชุดเดียวกันเป๊ะ ไม่งั้นวันที่เพิ่มพาหนะคันใหม่ใน JSON จะมีบางตัวรู้ บางตัวไม่รู้
##
## กติกาชื่อ (ART-DIRECTION 2.1): ไฟล์โมเดลคือ `world/models/<kind>/<id>.glb`
## และ `<id>` ต้องตรงกับ id ใน data/*.json เป๊ะ
## ยกเว้นสามกลุ่มที่ data ไม่มี id ให้ตรงๆ จึงต้องตั้งกติกาเพิ่ม:
##   · แพ็กเกจ  → `gym_<id>` / `resort_<id>` (สองกลุ่มนี้ id ซ้ำกันได้ เช่น daily/day)
##   · ความฝัน  → `dream_<roll>` (dreams.json ใช้เลขทอยเต๋าเป็นตัวระบุ ไม่มีฟิลด์ id)
##   · ดีล      → ใช้ *ประเภท* ของดีล เพราะ id ของดีลเป็นเลขรันไทม์ ไม่คงที่ข้ามเกม
##   · prop     → ของประดับฉากล้วนๆ ไม่มีใน data เลย (Sprint C) รายชื่ออยู่ที่ WQKitbashPlaces.PROPS

const KINDS := ["places", "props", "vehicles", "devices", "packs", "assets", "dreams", "character"]

## งบสามเหลี่ยมต่อกลุ่ม [ต่ำสุดที่ตั้งใจ, เพดานห้ามเกิน] — ART-DIRECTION ข้อ 2.1
## อยู่ที่นี่เพราะทั้ง model_lint และ models_readme ต้องใช้ตัวเลขชุดเดียวกัน
## หมายเหตุ: assets กับ dreams ไม่มีตัวเลขระบุไว้ในเอกสาร ตั้งขึ้นเองให้สอดคล้องกับกลุ่มอื่น
## (assets = ของโชว์บนแท่น ขนาดกลาง · dreams = ชิ้นใหญ่และละเอียดที่สุดของเกม)
const BUDGET := {
	"devices": [50, 300], "packs": [50, 300],
	"vehicles": [300, 900],
	"places": [400, 1500],
	"props": [50, 300],
	"character": [800, 1500],
	"assets": [100, 600],
	"dreams": [400, 1500],
}


## [{kind, id}] เรียงตามลำดับใน KINDS
static func all() -> Array:
	var out: Array = []
	for k in KINDS:
		for id in for_kind(k):
			out.append({"kind": k, "id": id})
	return out


static func for_kind(kind: String) -> Array:
	match kind:
		"places": return WQData.places.map(func(p): return String(p.id))
		# prop ประดับฉาก (ต้นไม้ เสาไฟ ม้านั่ง) ไม่มี id ใน data เพราะไม่มีผลต่อกฎเกมเลย
		# รายชื่ออยู่ที่ WQKitbashPlaces.PROPS ที่เดียว — ที่นี่แค่ยืมมาให้ตัวตรวจ/ตัวสร้าง README เห็น
		"props": return WQKitbashPlaces.PROPS.duplicate()
		"vehicles": return WQData.vehicles.map(func(v): return String(v.id))
		"devices": return WQData.devices.map(func(d): return String(d.id))
		"packs":
			var out: Array = []
			for g in WQData.gym_packs: out.append("gym_" + String(g.id))
			for r in WQData.resort_packs: out.append("resort_" + String(r.id))
			return out
		"dreams": return WQData.dreams.map(func(d): return "dream_%d" % int(d.roll))
		"assets":
			var kinds := {}
			for pool in [WQData.deal_pool, WQData.big_deals, WQData.mega_deals]:
				for t in pool: kinds[String(t.kind)] = true
			return kinds.keys()
		"character": return ["player"]
	return []


## ตราประทับที่ `world/tools/glb_export.gd` เขียนลงช่อง `copyright` ของ glTF
## ใช้แยกว่าไฟล์ `.glb` ชิ้นนั้น "อบจากเมชต่อกล่อง" หรือ "คนปั้นมาจริง"
## อยู่ที่นี่ที่เดียว เพราะทั้งตัวอบ ตัวตรวจ และตัวสร้าง README ต้องอ่านตราเดียวกัน
const BAKED_MARK := "wealth-quest: baked from code (WQKitbash)"


## ตอนนี้ของชิ้นนี้มาจากไหน:
##   ".glb"        คนปั้นมาจริง
##   ".glb (อบ)"   ไฟล์จริงแต่อบมาจากเมชต่อกล่อง — **ยังไม่ใช่งานปั้น** งานอาร์ตยังไม่จบ
##   "kitbash"     เมชต่อกล่องที่สร้างตอนรัน ยังไม่มีไฟล์
##   ""            ยังไม่มีอะไรเลย ใช้กล่องเปล่า
static func source_of(kind: String, id: String) -> String:
	if WQShowcase.has_model(kind, id):
		return ".glb (อบ)" if is_baked(kind, id) else ".glb"
	if WQKitbash.has(kind, id): return "kitbash"
	return ""


## ไฟล์ .glb ชิ้นนี้อบมาจากโค้ดหรือเปล่า — อ่านตราประทับในไฟล์ ไม่ใช่เดาจากชื่อ
static func is_baked(kind: String, id: String) -> bool:
	var path := WQShowcase.model_path(kind, id)
	if not ResourceLoader.exists(path): return false
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK: return false
	return state.copyright == BAKED_MARK


## มีไฟล์ .glb ที่คนปั้นมาจริงแล้วกี่ชิ้น (ไม่นับของที่อบจากโค้ด)
static func sculpted_count() -> int:
	var n := 0
	for it in all():
		if source_of(String(it.kind), String(it.id)) == ".glb": n += 1
	return n
