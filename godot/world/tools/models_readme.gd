extends SceneTree
## สร้าง world/models/README.md ใหม่ทั้งไฟล์จาก data/*.json
##   godot --headless --path . --script res://world/tools/models_readme.gd
##
## **ห้ามแก้ README.md ด้วยมือ** — รันสคริปต์นี้แทน
## ตารางเช็กลิสต์จะได้ไม่มีวันหลุดจากความจริง เวลามีคนเพิ่มพาหนะหรือสถานที่ใน JSON

const OUT := "res://world/models/README.md"

const KIND_TITLE := {
	"places": "สถานที่ / อาคาร", "vehicles": "พาหนะ", "devices": "อุปกรณ์",
	"packs": "แพ็กเกจฟิตเนส / รีสอร์ต", "assets": "ทรัพย์สิน (ตามประเภทของดีล)",
	"dreams": "ความฝัน", "character": "ตัวละคร", "props": "prop ประดับฉาก",
}
const KIND_SOURCE := {
	"places": "`data/places.json` → `places[].id`",
	"vehicles": "`data/places.json` → `vehicles[].id`",
	"devices": "`data/places.json` → `devices[].id`",
	"packs": "`data/places.json` → `gym_packs[].id` / `resort_packs[].id` (เติมหน้า `gym_` / `resort_`)",
	"assets": "`data/deals.json` → `kind` ของทุก template (ดีลไม่มี id คงที่)",
	"dreams": "`data/dreams.json` → `dream_<roll>` (ไม่มีฟิลด์ id)",
	"character": "ริกเดียวใช้ทุกอาชีพ — ชุดอาชีพประกอบตอนรันด้วย `WQKitbashChar` (หมวก · เสื้อ · ของที่ถือ)",
	"props": "ไม่มีใน `data/*.json` เลย — เป็นของประดับฉากล้วน รายชื่ออยู่ที่ `WQKitbashPlaces.PROPS`",
}


func _init() -> void:
	WQData.load_all()
	var lines: Array[String] = []
	var done := 0
	var total := 0
	var baked_or_more := 0     ## มีของให้เห็นในเกมแล้วกี่ชิ้น (นับทั้งที่ปั้นแล้ว อบไว้ และต่อกล่อง)

	lines.append("# world/models — สเปกและเช็กลิสต์โมเดล")
	lines.append("")
	lines.append("> **ไฟล์นี้สร้างจากสคริปต์ ห้ามแก้ด้วยมือ**")
	lines.append("> `godot --headless --path . --script res://world/tools/models_readme.gd`")
	lines.append("> ตัวเลขและรายชื่อทั้งหมดอ่านจาก `data/*.json` โดยตรง")
	lines.append("")
	lines.append("## สเปกก่อน export ทุกชิ้น")
	lines.append("")
	lines.append("| ข้อ | ต้องเป็น | ทำไม |")
	lines.append("|---|---|---|")
	lines.append("| ฟอร์แมต | `.glb` (glTF binary) | Godot นำเข้าได้ตรงๆ ไม่ต้องมีไฟล์ texture แยก |")
	lines.append("| ที่อยู่ไฟล์ | `world/models/<กลุ่ม>/<id>.glb` | โค้ดโหลดจาก id ตรงๆ ไม่มีตารางแปลงชื่อ |")
	lines.append("| ชื่อไฟล์ | **= id ใน `data/*.json` เป๊ะ** | ผิดตัวเดียว = ของหายจากแท่นโชว์แบบเงียบๆ |")
	lines.append("| origin | อยู่ที่ **ฐาน** (y = 0) | วางลงฉากเมืองแล้วต้องไม่ลอยและไม่จมพื้น |")
	lines.append("| หน่วย | 1 unit = 1 เมตร · **หันหน้า +Z** | +Z คือฝั่งถนน · ของที่มีอยู่ (รถ อาคาร) หันแบบนี้หมด |")
	lines.append("| shading | **flat** (Shade Flat, ปิด Auto Smooth) | สไตล์ทั้งเกมคือเห็นเหลี่ยมเห็นหน้า |")
	lines.append("| วัสดุ | **ชิ้นละ 1 วัสดุ ชื่อ `flat`** | หลายวัสดุ = หลาย draw call และหลุดสไตล์ palette แผ่นเดียว |")
	lines.append("| สี | map UV ไปที่ช่องบน `world/materials/palette.png` | เปลี่ยนสีทั้งเกมได้จาก `ui/theme/palette.gd` ไฟล์เดียว |")
	lines.append("| texture ในไฟล์ | **อย่าฝังแผ่น palette ลงไฟล์** | Godot จะแกะออกมาเป็น `<id>_palette.png` กองข้างโมเดล และ palette จะถูกก๊อปหลายสิบชุด · เกมสวม `flat.tres` ให้ตอนโหลดอยู่แล้ว |")
	lines.append("| bevel | ไม่มี ยกเว้นขอบใหญ่ที่จงใจ (1 ชั้น) | ขอบมนเยอะทำให้ทรงอ่านไม่ออกตอนย่อเป็นไอคอน |")
	lines.append("")
	lines.append("### งบสามเหลี่ยม")
	lines.append("")
	lines.append("| กลุ่ม | ต่ำสุดที่ตั้งใจ | เพดาน (ห้ามเกิน) |")
	lines.append("|---|---:|---:|")
	for k in WQModelIds.KINDS:
		if not WQModelIds.BUDGET.has(k): continue
		var b: Array = WQModelIds.BUDGET[k]
		lines.append("| %s | %d | %d |" % [KIND_TITLE.get(k, k), int(b[0]), int(b[1])])
	lines.append("")
	lines.append("ตรวจด้วย `godot --headless --path . --script res://world/tools/model_lint.gd`")
	lines.append("— ตรวจงบสามเหลี่ยม · วัสดุเดียว · ฐานอยู่ที่ y=0 · ชื่อโหนดตรงกับ id")
	lines.append("")
	lines.append("### สีที่ทาของในฉากได้")
	lines.append("")
	lines.append("`money` `time` `health` ถูกจองไว้บอกสถานะ **ห้ามใช้เป็นสีหลักของของในฉาก**")
	lines.append("เหลือให้ใช้: " + ", ".join(_object_slots()))
	lines.append("")
	lines.append("## เช็กลิสต์")
	lines.append("")
	lines.append("| สถานะ | หมายความว่า |")
	lines.append("|---|---|")
	lines.append("| ✅ ปั้นแล้ว | มีไฟล์ `.glb` ที่คนปั้นมาจริง — **งานอาร์ตของชิ้นนี้จบแล้ว** |")
	lines.append("| 🟠 อบจากโค้ด | มีไฟล์ `.glb` จริงบนดิสก์ แต่อบมาจากเมชต่อกล่องด้วย `world/tools/glb_export.gd` |")
	lines.append("| 🟡 ชั่วคราว | ยังไม่มีไฟล์ — ต่อกล่องขึ้นมาตอนรัน |")
	lines.append("| ⬜ ยังไม่ทำ | ไม่มีอะไรเลย ใช้กล่องเปล่า |")
	lines.append("")
	lines.append("**🟠 ยังไม่ใช่งานปั้น** — มันคือทรงเดียวกับที่โค้ดสร้าง แค่ย้ายมาเป็นไฟล์จริงเพื่อให้ท่อส่งงาน")
	lines.append("เดินได้ครบวง (อบ → นำเข้า → ตรวจ → เห็นในเกม) คนปั้นเอาไฟล์ของตัวเองมาวางทับได้ทีละชิ้น")
	lines.append("โดยไม่ต้องรอให้ครบ — **ตัวอบจะไม่แตะไฟล์ที่ไม่มีตราประทับของมันเด็ดขาด**")
	lines.append("")

	for kind in WQModelIds.KINDS:
		var ids := WQModelIds.for_kind(kind)
		if ids.is_empty(): continue
		var have := 0
		var rows: Array[String] = []
		for id in ids:
			var src := WQModelIds.source_of(kind, id)
			if src == ".glb": have += 1
			if src != "": baked_or_more += 1
			total += 1
			var mark := "⬜ ยังไม่ทำ"
			if src == ".glb": mark = "✅ ปั้นแล้ว"
			elif src == ".glb (อบ)": mark = "🟠 อบจากโค้ด"
			elif src != "": mark = "🟡 ชั่วคราว"
			rows.append("| `%s` | %s | %s |" % [id,
				"`%s`" % src if src != "" else "—", mark])
		done += have
		lines.append("### %s — ปั้นแล้ว %d/%d ชิ้น" % [KIND_TITLE.get(kind, kind), have, ids.size()])
		lines.append("")
		lines.append("ที่มาของรายชื่อ: %s" % KIND_SOURCE.get(kind, "—"))
		lines.append("")
		lines.append("| id (= ชื่อไฟล์ `.glb`) | ตอนนี้ใช้อะไรอยู่ | สถานะ |")
		lines.append("|---|---|---|")
		lines.append_array(rows)
		lines.append("")

	lines.append("---")
	lines.append("")
	lines.append("**งานปั้นจริง %d/%d ชิ้น** · มีของให้เห็นในเกมแล้ว %d/%d ชิ้น" % [
		done, total, baked_or_more, total])

	var err := FileAccess.open(OUT, FileAccess.WRITE)
	if err == null:
		printerr("models_readme: เขียน %s ไม่ได้" % OUT)
		quit(1)
		return
	err.store_string("\n".join(lines) + "\n")
	err.close()
	print("models_readme: %s — %d กลุ่ม %d ชิ้น (ปั้นจริง %d · มีของแล้ว %d)" % [
		OUT, WQModelIds.KINDS.size(), total, done, baked_or_more])
	quit(0)


## ช่องสีที่เอาไปทาของในฉากได้ (ตัดสีที่จองไว้บอกสถานะออก)
func _object_slots() -> Array:
	var reserved := [&"money", &"money_dark", &"time", &"health", &"danger", &"win",
		&"bg_deep", &"bg_scene_top", &"bg_scene_bot"]
	var out: Array = []
	for slot in WQPalette.SLOTS:
		if not reserved.has(slot): out.append("`%s`" % slot)
	return out
