class_name WQKitbashItems
extends RefCounted
## ของที่ "โชว์บนแท่น" — ทรัพย์สิน 5 ประเภท · แพ็กเกจฟิตเนส/รีสอร์ต 6 · ความฝัน 6
##
## สามกลุ่มนี้เป็นกลุ่มสุดท้ายที่ยังเป็น **กล่องเปล่า** อยู่ในเกม (Sprint A–C ทำแต่ของที่อยู่
## ในฉากเมือง: อาคาร prop พาหนะ อุปกรณ์ ตัวละคร) ทั้งที่มันคือของที่ผู้เล่นจ้องนานที่สุด —
## การ์ดดีลทุกใบเอาของขึ้นแท่นโชว์ · แผงลงมือทำโชว์ไอคอนแพ็กเกจ · และความฝันคือ
## หน้าจอที่ตัดสินว่าเล่นเกมนี้ไปทำไม ถ้ายังเป็นลูกบาศก์เทาก็เท่ากับไม่มีอะไรให้อยาก
##
## กติกาเดียวกับทุกชิ้นในโปรเจกต์ (model_lint เป็นคนตรวจ):
##   · origin ที่ฐาน y=0 · 1 unit = 1 เมตร · หันหน้า +Z · flat shading
##   · วัสดุเดียวคือ flat.tres · สีมาจากช่องบน palette.png ไม่มี albedo_color รายชิ้น
##   · งบสามเหลี่ยม: assets 100–600 · packs 50–300 · dreams 400–1500 (WQModelIds.BUDGET)
##
## **ห้ามใช้ money / time / health เป็นสีหลัก** — สามสีนั้นจองไว้บอกสถานะผู้เล่น
## ของเก็งกำไรจึงไม่ใช่ "แท่งทองสีทอง" แต่เป็นแท่งโลหะสว่างในตู้โชว์ ให้ *ทรง* เป็นตัวบอกค่า
##
## **ทรงต้องอ่านออกตอนย่อเป็นไอคอน 128px** (ART-DIRECTION 4.3) ของทุกชิ้นในไฟล์นี้จึงถูกอบ
## เป็นไอคอนใน UI ด้วย รายละเอียดที่เล็กกว่าราว 5% ของความสูงจะหายไปตอนย่อ — อย่าเสีย tris ไปกับมัน

const ASSETS := ["micro", "business", "realestate", "speculation", "fund"]
const PACKS := ["gym_daily", "gym_monthly", "gym_trainer",
	"resort_day", "resort_weekend", "resort_abroad"]
const DREAMS := ["dream_1", "dream_2", "dream_3", "dream_4", "dream_5", "dream_6"]


static func has(kind: String, id: String) -> bool:
	match kind:
		"assets": return ASSETS.has(id)
		"packs": return PACKS.has(id)
		"dreams": return DREAMS.has(id)
	return false


static func build(kind: String, id: String) -> MeshInstance3D:
	if not has(kind, id): return null
	var st := WQMeshKit.begin()
	match kind:
		"assets": _asset(st, id)
		"packs": _pack(st, id)
		"dreams": _dream(st, id)
	return WQMeshKit.finish(st, id)


# ========== ทรัพย์สิน — ประเภทของดีล ==========
## ดีลไม่มี id คงที่ (id เป็นเลขรันไทม์) โมเดลจึงอ้างด้วย "ประเภท" ห้าอย่าง
## แต่ละประเภทต้องดูต่างกันตั้งแต่แวบแรก เพราะการ์ดดีลเปลี่ยนของบนแท่นทุกครั้งที่ชี้เมาส์
## ถ้าห้าประเภทดูคล้ายกัน แท่งโชว์จะกลายเป็นของประดับที่ไม่มีข้อมูล

static func _asset(st: SurfaceTool, id: String) -> void:
	match id:
		"micro": _micro(st)
		"business": _business(st)
		"realestate": _realestate(st)
		"speculation": _speculation(st)
		"fund": _fund(st)


## 💡 ธุรกิจจิ๋ว — ตู้หยอดเหรียญสามตู้เรียงกัน (ตรงกับชื่อดีลจริงในตาราง:
## ตู้กดน้ำ 3 ตู้ · ตู้เติมเงิน 5 ตู้) ของที่ "ตั้งทิ้งไว้แล้วมันทำงานเอง" ซึ่งคือนิยามของทรัพย์สิน
static func _micro(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.04, 0), Vector3(2.5, 0.08, 1.0), &"neutral_4")
	for i in 3:
		var x := (float(i) - 1.0) * 0.78
		WQMeshKit.box(st, Vector3(x, 0.88, 0), Vector3(0.7, 1.6, 0.62), &"neutral_3")
		# หน้ากระจกโชว์ของ = สิ่งที่ทำให้อ่านออกว่าเป็น "ตู้ขาย" ไม่ใช่ตู้ไฟฟ้า
		WQMeshKit.box(st, Vector3(x, 1.02, 0.32), Vector3(0.52, 1.0, 0.03), &"accent_steel")
		WQMeshKit.box(st, Vector3(x, 1.62, 0.33), Vector3(0.64, 0.2, 0.05), &"neutral_1")
		# ช่องหยอดเหรียญกับถาดรับของ — สองก้อนเล็กที่บอกว่ามันกินเหรียญแล้วคายของ
		WQMeshKit.box(st, Vector3(x + 0.2, 0.5, 0.33), Vector3(0.16, 0.1, 0.04), &"neutral_5")
		WQMeshKit.box(st, Vector3(x, 0.26, 0.33), Vector3(0.46, 0.22, 0.06), &"neutral_5")
		WQMeshKit.box(st, Vector3(x, 1.72, 0), Vector3(0.74, 0.08, 0.66), &"neutral_4")
	WQMeshKit.box(st, Vector3(0, 1.95, -0.1), Vector3(2.3, 0.34, 0.1), &"accent_wood")


## 🏪 ธุรกิจ — ร้านหน้ากว้างพร้อมกันสาดลายทาง ป้ายร้าน และลังของหน้าร้าน
## ต่างจาก "ตู้หยอดเหรียญ" ตรงที่มันมี *หน้าร้าน* ให้คนเดินเข้า = มีค่าใช้จ่ายและมีคนดูแล
static func _business(st: SurfaceTool) -> void:
	var w := 3.6
	var d := 2.6
	var h := 2.9
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"neutral_2")
	WQMeshKit.box(st, Vector3(0, h + 0.12, 0), Vector3(w + 0.3, 0.24, d + 0.3), &"neutral_4")
	WQMeshKit.box(st, Vector3(0, h - 0.45, d * 0.5 + 0.04), Vector3(w * 0.8, 0.55, 0.1), &"accent_wood")
	# กันสาดลายทาง — ห้าแถบสลับสี ทำให้แวบเดียวก็รู้ว่าเป็นร้านค้า ไม่ใช่บ้าน
	for i in 5:
		var x := (float(i) - 2.0) * (w * 0.17)
		var slot: StringName = &"neutral_1" if i % 2 == 0 else &"accent_wood"
		WQMeshKit.box(st, Vector3(x, 2.05, d * 0.5 + 0.4), Vector3(w * 0.17, 0.12, 0.8), slot)
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * w * 0.28, 1.05, d * 0.5 + 0.02),
			Vector3(w * 0.3, 1.5, 0.06), &"accent_steel")
	WQMeshKit.box(st, Vector3(0, 1.0, d * 0.5 + 0.03), Vector3(0.9, 2.0, 0.08), &"neutral_5")
	WQMeshKit.box(st, Vector3(0, 2.02, d * 0.5 + 0.03), Vector3(1.0, 0.1, 0.1), &"neutral_1")
	# ลังของหน้าร้าน — ของสามก้อนที่บอกว่าร้านนี้ "มีของหมุนเวียน" ไม่ใช่ร้านร้าง
	for i in 3:
		WQMeshKit.box(st, Vector3(-w * 0.32 + float(i) * 0.34, 0.16, d * 0.5 + 0.55),
			Vector3(0.3, 0.32, 0.3), &"accent_wood")
	WQMeshKit.box(st, Vector3(w * 0.3, 0.3, d * 0.5 + 0.55), Vector3(0.5, 0.6, 0.4), &"neutral_3")


## 🏢 อสังหาฯ — อพาร์ตเมนต์สี่ชั้นที่ **มีระเบียงทุกชั้น**
## ระเบียงคือสิ่งเดียวที่แยก "ตึกให้คนเช่าอยู่" ออกจาก "ตึกออฟฟิศ" ได้ในทรงเดียวกัน
static func _realestate(st: SurfaceTool) -> void:
	var w := 3.0
	var d := 2.8
	var fh := 1.15
	var floors := 4
	var h := float(floors) * fh
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"neutral_2")
	for f in floors:
		var y := float(f) * fh + fh * 0.55
		WQMeshKit.box(st, Vector3(0, y - 0.3, d * 0.5 + 0.2), Vector3(w * 0.92, 0.08, 0.42), &"neutral_3")
		WQMeshKit.box(st, Vector3(0, y - 0.12, d * 0.5 + 0.4), Vector3(w * 0.92, 0.32, 0.06), &"neutral_1")
		for sx in [-1.0, 1.0]:
			WQMeshKit.box(st, Vector3(sx * w * 0.24, y, d * 0.5 + 0.02),
				Vector3(w * 0.34, fh * 0.5, 0.05), &"accent_steel")
			WQMeshKit.box(st, Vector3(sx * w * 0.5, y, 0), Vector3(0.05, fh * 0.5, d * 0.5), &"accent_steel")
	WQMeshKit.box(st, Vector3(0, h + 0.1, 0), Vector3(w + 0.24, 0.2, d + 0.24), &"neutral_4")
	# ถังน้ำบนดาดฟ้า — ของประจำตึกเช่าไทย และทำให้ยอดตึกไม่แบนตอนย่อเป็นไอคอน
	WQMeshKit.box(st, Vector3(-w * 0.25, h + 0.55, -0.4), Vector3(0.6, 0.7, 0.6), &"neutral_1")
	WQMeshKit.box(st, Vector3(w * 0.28, h + 0.35, -0.3), Vector3(0.8, 0.3, 0.7), &"neutral_3")
	WQMeshKit.box(st, Vector3(0, 1.0, d * 0.5 + 0.03), Vector3(0.85, 2.0, 0.08), &"neutral_5")
	WQMeshKit.box(st, Vector3(0, 2.15, d * 0.5 + 0.35), Vector3(1.5, 0.1, 0.8), &"neutral_1")


## 💰 ของเก็งกำไร — กองแท่งโลหะเรียงพีระมิดบนแท่นไม้ พร้อมกองเหรียญสองกอง
##
## **ไม่ใช้สีทอง** (money จองไว้บอกสถานะ) ให้ทรงพีระมิดกับแท่นวางเป็นตัวบอกว่า "ของมีค่า"
## ตอนแรกครอบตู้กระจกไว้ด้วย แต่พอย่อเป็นไอคอน 128px ฝาตู้บังกองแท่งจนดูเป็นโต๊ะมีหลังคา
## — ของชิ้นเล็กที่ต้องอ่านออกในไอคอน ห้ามมีอะไรมาคร่อมทับซิลูเอตของมันเอง
## ความหมายที่อยากให้อ่านได้คือ "ของที่ราคาขึ้นลงเอง ไม่ได้ผลิตอะไร" — มันจึงนอนนิ่งเป็นกอง
static func _speculation(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.09, 0), Vector3(2.0, 0.18, 1.4), &"accent_wood")
	WQMeshKit.box(st, Vector3(0, 0.21, 0), Vector3(1.7, 0.08, 1.15), &"neutral_4")
	# แท่งเรียงสามชั้น 3-2-1 — พีระมิดอ่านออกว่า "กองสมบัติ" ได้เร็วกว่าเรียงแถวเดียว
	# แท่งสูงกว่าของจริงมาก เพราะกองที่เตี้ยเกินไปจะหายไปในไอคอน
	var rows := [3, 2, 1]
	for r in rows.size():
		var n: int = rows[r]
		for i in n:
			var x := (float(i) - (float(n) - 1.0) * 0.5) * 0.52
			WQMeshKit.box(st, Vector3(x, 0.4 + float(r) * 0.3, 0),
				Vector3(0.48, 0.3, 0.74), &"neutral_1")
	for sx in [-1.0, 1.0]:
		WQMeshKit.cylinder_y(st, Vector3(sx * 0.82, 0.25, 0.42), 0.19, 0.3, 8, &"neutral_2")
	WQMeshKit.cylinder_y(st, Vector3(-0.82, 0.25, -0.4), 0.19, 0.18, 8, &"neutral_2")


## 📈 กองทุน/ตราสารหนี้ — แท่งกราฟไล่ขึ้นกับลูกศรแนวโน้ม
##
## ทรัพย์สินชิ้นเดียวในตารางที่ **จับต้องไม่ได้** ทรงจึงต้องเป็นตัวเลข ไม่ใช่ของ
## เดิมมีแผ่นหลังทึบสูงกว่าแท่ง ผลคือพอย่อเป็นไอคอนแล้วแท่งจมหายไปในแผ่น
## เหลือเป็นก้อนขาวลอยๆ — กราฟต้องเป็นซิลูเอตของตัวเอง ห้ามมีฉากหลัง
static func _fund(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.07, 0), Vector3(2.4, 0.14, 1.5), &"neutral_2")
	var hs := [0.45, 0.78, 0.66, 1.15, 1.55]
	for i in hs.size():
		var x := (float(i) - 2.0) * 0.44
		var bh: float = hs[i]
		WQMeshKit.box(st, Vector3(x, 0.14 + bh * 0.5, -0.15), Vector3(0.36, bh, 0.42), &"accent_steel")
		WQMeshKit.box(st, Vector3(x, 0.14 + bh + 0.05, -0.15), Vector3(0.42, 0.1, 0.48), &"neutral_1")
	# เส้นแนวโน้มทำเป็น "บันได" ของกล่องเล็กไล่ระดับ — meshkit ต่อกล่องแกนตรงเท่านั้น
	# เส้นเฉียงจริงจึงต้องเป็นขั้นบันได ซึ่งเข้ากับสไตล์ low poly อยู่แล้ว
	for i in 5:
		WQMeshKit.box(st, Vector3(-0.9 + float(i) * 0.44, 0.62 + float(i) * 0.24, 0.42),
			Vector3(0.42, 0.11, 0.11), &"accent_wood")
	WQMeshKit.taper(st, Vector3(1.0, 1.6, 0.42), Vector3(0.44, 0, 0.44), 0.5, 0.0, &"accent_wood")


# ========== แพ็กเกจฟิตเนส / รีสอร์ต ==========
## หกชิ้นนี้คือ "ตัวเลือกที่ต้องเทียบกัน" ในแผงลงมือทำ — ของแพงกว่าต้องดู *ใหญ่กว่าและมีของ
## มากกว่า* ตั้งแต่ในไอคอน ไม่ใช่ต่างกันแค่ตัวเลขข้างปุ่ม

static func _pack(st: SurfaceTool, id: String) -> void:
	match id:
		"gym_daily": _gym_daily(st)
		"gym_monthly": _gym_monthly(st)
		"gym_trainer": _gym_trainer(st)
		"resort_day": _resort_day(st)
		"resort_weekend": _resort_weekend(st)
		"resort_abroad": _resort_abroad(st)


## 🎫 จ่ายรายครั้ง — ดัมเบลอันเดียวกับบัตรผ่านประตูหนึ่งใบ "ได้แค่วันนี้"
##
## ของน้อยชิ้นที่สุดในหกแพ็กเกจ มันจึงต้อง **ใหญ่เต็มเฟรม** ไม่ใช่ของจิ๋วบนแผ่นรอง
## (เวอร์ชันแรกวางดัมเบลขนาดจริงบนฐานสีเกือบดำ ผลคือไอคอนออกมาเป็นแผ่นดำเปล่าๆ)
static func _gym_daily(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.05, 0), Vector3(2.0, 0.1, 1.3), &"neutral_2")
	# จานน้ำหนักเป็นทรงกระบอก ไม่ใช่กล่อง — กล่องบนปลายบาร์อ่านเป็น "ก้อนดำสองก้อน"
	# ตอนย่อเป็นไอคอน (บทเรียนเดียวกับ gym_trainer) และ **บาร์ต้องไม่ใช่สีเดียวกับถาดรอง**
	# ไม่งั้นจานสองใบจะลอยแยกกันจนอ่านไม่ออกว่าเชื่อมถึงกัน
	WQMeshKit.box(st, Vector3(-0.12, 0.46, -0.12), Vector3(1.05, 0.14, 0.14), &"neutral_4")
	for sx in [-1.0, 1.0]:
		WQMeshKit.cylinder_x(st, Vector3(-0.12 + sx * 0.44, 0.46, -0.12), 0.26, 0.08, 8, &"neutral_5")
		WQMeshKit.cylinder_x(st, Vector3(-0.12 + sx * 0.56, 0.46, -0.12), 0.19, 0.06, 8, &"neutral_5")
	# ขาตั้งเตี้ยรับบาร์ไว้ ให้ดัมเบลลอยพ้นถาดชัดๆ ไม่จมไปกับพื้นรอง
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(-0.12 + sx * 0.2, 0.24, -0.12), Vector3(0.12, 0.3, 0.12), &"neutral_4")
	# บัตรผ่านวางอยู่ข้างหน้า — ตัวบอกว่า "ครั้งเดียวจบ" ไม่ใช่ของที่เป็นเจ้าของ
	WQMeshKit.box(st, Vector3(0.5, 0.16, 0.46), Vector3(0.66, 0.08, 0.44), &"neutral_1")
	WQMeshKit.box(st, Vector3(0.5, 0.21, 0.54), Vector3(0.46, 0.04, 0.12), &"accent_steel")
	WQMeshKit.box(st, Vector3(0.5, 0.21, 0.37), Vector3(0.2, 0.04, 0.1), &"neutral_5")


## 💪 แพ็กเกจรายเดือน — ชั้นวางดัมเบลสามคู่ "มีอุปกรณ์พร้อม" ตามที่ note ในตารางบอกไว้
static func _gym_monthly(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.05, 0), Vector3(1.5, 0.1, 0.6), &"neutral_5")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 0.68, 0.36, 0), Vector3(0.1, 0.62, 0.5), &"neutral_4")
	WQMeshKit.box(st, Vector3(0, 0.34, 0.0), Vector3(1.4, 0.07, 0.46), &"neutral_3")
	WQMeshKit.box(st, Vector3(0, 0.64, -0.06), Vector3(1.4, 0.07, 0.36), &"neutral_3")
	for i in 3:
		_dumbbell(st, Vector3((float(i) - 1.0) * 0.42, 0.44, 0.06), 0.3, 0.09)
	for i in 2:
		_dumbbell(st, Vector3((float(i) - 0.5) * 0.5, 0.74, -0.04), 0.26, 0.08)


## 🏅 เทรนเนอร์ส่วนตัว — ม้านั่งเบนช์กับบาร์เบลบนขาตั้ง = อุปกรณ์ที่ต้องมีคนคุมถึงจะใช้
##
## จานน้ำหนักใช้ทรงกระบอกไม่ใช่กล่อง เพราะตอนย่อเป็นไอคอน กล่องสี่เหลี่ยมบนปลายบาร์
## อ่านเป็น "กล่องสองใบ" ไม่ใช่ "จานน้ำหนัก" — ทรงกลมคือสิ่งเดียวที่บอกว่านี่คือของหนัก
static func _gym_trainer(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.05, 0), Vector3(2.3, 0.1, 1.5), &"neutral_2")
	# เบาะยาวตามแกน Z + พนักเอียงท้าย — ซิลูเอตของ "ม้านั่งเบนช์" อยู่ที่เบาะยาวเตี้ย
	WQMeshKit.box(st, Vector3(0, 0.5, 0.05), Vector3(0.5, 0.16, 1.5), &"accent_wood")
	WQMeshKit.box(st, Vector3(0, 0.68, -0.62), Vector3(0.5, 0.18, 0.5), &"accent_wood")
	for sz in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(0, 0.22, sz * 0.62), Vector3(0.34, 0.44, 0.14), &"neutral_4")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 0.62, 0.62, -0.5), Vector3(0.14, 1.24, 0.14), &"neutral_4")
		WQMeshKit.box(st, Vector3(sx * 0.62, 1.2, -0.42), Vector3(0.14, 0.2, 0.3), &"neutral_5")
	WQMeshKit.box(st, Vector3(0, 1.26, -0.5), Vector3(2.1, 0.09, 0.09), &"neutral_2")
	for sx in [-1.0, 1.0]:
		WQMeshKit.cylinder_x(st, Vector3(sx * 0.86, 1.26, -0.5), 0.26, 0.05, 8, &"neutral_5")
		WQMeshKit.cylinder_x(st, Vector3(sx * 0.96, 1.26, -0.5), 0.2, 0.05, 8, &"neutral_5")


## 🌤️ เที่ยวใกล้บ้าน 1 วัน — ร่มกับเก้าอี้ผ้าใบตัวเดียวบนหาดทรายผืนเล็ก
static func _resort_day(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.05, 0), Vector3(2.2, 0.1, 1.6), &"neutral_2")
	WQMeshKit.cylinder_y(st, Vector3(-0.5, 0.1, -0.1), 0.05, 1.5, 6, &"accent_wood")
	WQMeshKit.taper(st, Vector3(-0.5, 1.25, -0.1), Vector3(1.5, 0, 1.5), 0.45, 0.0, &"accent_wood")
	WQMeshKit.box(st, Vector3(0.45, 0.36, 0.1), Vector3(0.62, 0.08, 0.9), &"neutral_1")
	WQMeshKit.box(st, Vector3(0.45, 0.55, -0.28), Vector3(0.62, 0.42, 0.08), &"neutral_1")
	for sz in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(0.45, 0.18, sz * 0.32), Vector3(0.5, 0.28, 0.07), &"accent_wood")
	WQMeshKit.box(st, Vector3(-0.05, 0.2, 0.5), Vector3(0.3, 0.2, 0.3), &"neutral_3")


## 🏖️ รีสอร์ตสุดสัปดาห์ — บังกะโลริมน้ำหนึ่งหลังกับต้นปาล์ม "ไปนอนค้าง ไม่ใช่ไปเช้าเย็นกลับ"
static func _resort_weekend(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.05, 0), Vector3(3.0, 0.1, 2.0), &"neutral_2")
	WQMeshKit.box(st, Vector3(0.9, 0.06, 0.75), Vector3(1.2, 0.06, 0.5), &"water")
	WQMeshKit.box(st, Vector3(-0.4, 0.65, -0.2), Vector3(1.6, 1.1, 1.3), &"neutral_1")
	for i in 3:
		var t := float(i)
		WQMeshKit.box(st, Vector3(-0.4, 1.28 + t * 0.16, -0.2),
			Vector3(1.85 - t * 0.4, 0.16, 1.55 - t * 0.34), &"accent_wood")
	WQMeshKit.box(st, Vector3(-0.4, 0.42, 0.46), Vector3(0.42, 0.74, 0.06), &"neutral_5")
	WQMeshKit.box(st, Vector3(-0.95, 0.75, 0.46), Vector3(0.36, 0.4, 0.05), &"accent_steel")
	WQMeshKit.box(st, Vector3(-0.4, 0.13, 0.68), Vector3(1.7, 0.08, 0.5), &"accent_wood")
	_palm(st, Vector3(0.95, 0.1, -0.35), 1.5)


## ✈️ ทริปต่างประเทศ — เครื่องบินลำเดียว ชิ้นที่อ่านออกเร็วที่สุดในหกอันโดยไม่ต้องมีป้าย
static func _resort_abroad(st: SurfaceTool) -> void:
	var y := 0.62
	WQMeshKit.box(st, Vector3(0, y, 0), Vector3(0.5, 0.5, 3.0), &"neutral_1")
	WQMeshKit.taper(st, Vector3(0, y - 0.25, 1.5), Vector3(0.5, 0, 0.5), 0.6, 0.25, &"neutral_1")
	WQMeshKit.box(st, Vector3(0, y + 0.1, 0.2), Vector3(0.52, 0.12, 1.9), &"accent_steel")
	# ปีกยื่นสองข้าง + ปีกหางเล็กกว่า — สัดส่วนนี้คือสิ่งที่ทำให้ดูเป็นเครื่องบินโดยสาร
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 1.15, y - 0.05, -0.1), Vector3(1.8, 0.09, 0.85), &"neutral_2")
		WQMeshKit.box(st, Vector3(sx * 0.62, y - 0.2, -0.1), Vector3(0.5, 0.26, 0.5), &"neutral_4")
		WQMeshKit.box(st, Vector3(sx * 0.45, y + 0.05, -1.3), Vector3(0.7, 0.07, 0.4), &"neutral_2")
	WQMeshKit.taper(st, Vector3(0, y + 0.2, -1.25), Vector3(0.12, 0, 0.8), 0.7, 0.55, &"accent_wood")
	WQMeshKit.box(st, Vector3(0, 0.16, 1.0), Vector3(0.1, 0.32, 0.1), &"neutral_5")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 0.3, 0.16, -0.3), Vector3(0.1, 0.32, 0.12), &"neutral_5")


## ดัมเบลหนึ่งอัน — แกนกับจานสองข้าง ใช้ซ้ำทั้งสามแพ็กเกจฟิตเนส
static func _dumbbell(st: SurfaceTool, at: Vector3, len: float, r: float) -> void:
	WQMeshKit.box(st, at, Vector3(len, r * 0.5, r * 0.5), &"neutral_2")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, at + Vector3(sx * len * 0.5, 0, 0),
			Vector3(r * 0.7, r * 2.0, r * 2.0), &"neutral_5")


## ต้นปาล์ม — ลำต้นเอียงไม่ได้ (กล่องแกนตรง) จึงให้ใบสามแฉกเป็นตัวบอกว่าเป็นปาล์ม ไม่ใช่ต้นไม้เมือง
static func _palm(st: SurfaceTool, base: Vector3, h: float) -> void:
	WQMeshKit.cylinder_y(st, base, 0.09, h, 6, &"accent_wood")
	for i in 3:
		var a := TAU * float(i) / 3.0
		WQMeshKit.box(st, base + Vector3(cos(a) * 0.42, h + 0.05, sin(a) * 0.42),
			Vector3(0.9, 0.07, 0.34), &"foliage")
	WQMeshKit.taper(st, base + Vector3(0, h, 0), Vector3(0.34, 0, 0.34), 0.26, 0.0, &"foliage")


# ========== ความฝัน ==========
## ชิ้นใหญ่และละเอียดที่สุดของเกม (400–1500 tris) เพราะมันคือของที่ผู้เล่นเห็นตอนตอบคำถามว่า
## "เล่นเกมนี้ไปทำไม" — หน้าทอยความฝันด่าน 2 เอาชิ้นนี้ขึ้นแท่นเต็มจอ

static func _dream(st: SurfaceTool, id: String) -> void:
	match id:
		"dream_1": _dream_beach_house(st)
		"dream_2": _dream_world_trip(st)
		"dream_3": _dream_foundation(st)
		"dream_4": _dream_clinic(st)
		"dream_5": _dream_cars(st)
		"dream_6": _dream_company(st)


## 🏝️ บ้านพักตากอากาศริมทะเล — บ้านยกพื้นบนหาด มีน้ำอยู่ฝั่งหน้า
static func _dream_beach_house(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.06, 0), Vector3(5.2, 0.12, 4.0), &"neutral_2")
	WQMeshKit.box(st, Vector3(0, 0.1, 1.62), Vector3(5.2, 0.1, 0.9), &"water")
	# ยกพื้นด้วยเสาตอม่อ = บ้านริมน้ำ ไม่ใช่บ้านในหมู่บ้านจัดสรร
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 0.0, 1.0]:
			WQMeshKit.box(st, Vector3(sx * 1.35, 0.32, sz * 0.95), Vector3(0.18, 0.5, 0.18), &"accent_wood")
	WQMeshKit.box(st, Vector3(0, 0.62, 0), Vector3(3.3, 0.14, 2.6), &"accent_wood")
	WQMeshKit.box(st, Vector3(-0.15, 1.42, -0.25), Vector3(2.5, 1.5, 2.0), &"neutral_1")
	for i in 3:
		var t := float(i)
		WQMeshKit.box(st, Vector3(-0.15, 2.28 + t * 0.2, -0.25),
			Vector3(2.9 - t * 0.6, 0.2, 2.4 - t * 0.5), &"accent_wood")
	WQMeshKit.box(st, Vector3(-0.15, 1.15, 0.78), Vector3(0.5, 0.9, 0.06), &"neutral_5")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(-0.15 + sx * 0.85, 1.5, 0.78), Vector3(0.6, 0.7, 0.05), &"accent_steel")
	WQMeshKit.box(st, Vector3(-1.42, 1.5, -0.25), Vector3(0.05, 0.7, 1.4), &"accent_steel")
	# ระเบียงหน้าบ้านกับราวกันตก — ที่นั่งมองทะเลคือหัวใจของความฝันข้อนี้
	WQMeshKit.box(st, Vector3(-0.15, 0.72, 1.15), Vector3(3.3, 0.1, 0.9), &"accent_wood")
	WQMeshKit.box(st, Vector3(-0.15, 0.95, 1.58), Vector3(3.3, 0.36, 0.07), &"neutral_1")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(-0.15 + sx * 1.62, 0.95, 1.15), Vector3(0.07, 0.36, 0.9), &"neutral_1")
	for i in 3:
		WQMeshKit.box(st, Vector3(1.1, 0.5 - float(i) * 0.16, 1.35 + float(i) * 0.3),
			Vector3(0.8, 0.1, 0.3), &"accent_wood")
	WQMeshKit.box(st, Vector3(0.85, 0.82, 1.2), Vector3(0.5, 0.1, 0.5), &"neutral_1")
	WQMeshKit.box(st, Vector3(0.85, 0.95, 0.98), Vector3(0.5, 0.36, 0.08), &"neutral_1")
	_palm(st, Vector3(-2.0, 0.12, 1.1), 2.1)
	_palm(st, Vector3(2.05, 0.12, -0.5), 1.7)


## 🌍 เที่ยวรอบโลก + กองทุนการศึกษาลูก — ลูกโลกบนขาตั้ง วงโคจร และกระเป๋าเดินทางที่พร้อมแล้ว
##
## ชิ้นเดียวในหกความฝันที่ไม่ใช่อาคาร ซิลูเอตจึงต้องมาจาก **ลูกโลกลูกเดียวที่ใหญ่พอ**
## เวอร์ชันแรกทำลูกโลกเท่าของจริงบนฐานสีเกือบดำ ผลคือไอคอนออกมาเป็นจุดน้ำเงินกลางแผ่นดำ
static func _dream_world_trip(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.08, 0), Vector3(4.4, 0.16, 3.4), &"neutral_2")
	WQMeshKit.box(st, Vector3(0, 0.34, 0), Vector3(1.3, 0.36, 1.3), &"accent_wood")
	WQMeshKit.box(st, Vector3(0, 0.78, 0), Vector3(0.26, 0.6, 0.26), &"neutral_4")
	# ลูกโลกทำจากทรงกระบอกซ้อนสามชั้น — meshkit ไม่มีทรงกลม และทรงกลมเนียนก็ผิดสไตล์อยู่แล้ว
	WQMeshKit.cylinder_y(st, Vector3(0, 1.02, 0), 0.62, 0.16, 10, &"water")
	WQMeshKit.cylinder_y(st, Vector3(0, 1.18, 0), 0.78, 0.5, 10, &"water")
	WQMeshKit.cylinder_y(st, Vector3(0, 1.68, 0), 0.56, 0.3, 10, &"water")
	# ทวีปเป็นก้อนแปะบนผิวโลก ไม่ต้องเหมือนแผนที่จริง แค่ให้ไม่ใช่ลูกบอลเปล่า
	# ต้องยื่นพ้นผิวชัดๆ ไม่งั้นตอนย่อจะกลายเป็นลูกบอลสีเดียว
	for it in [[0.6, 1.35, 0.34], [-0.5, 1.55, 0.42], [0.2, 1.2, -0.66], [-0.62, 1.2, -0.36]]:
		WQMeshKit.box(st, Vector3(it[0], it[1], it[2]), Vector3(0.56, 0.4, 0.5), &"foliage")
	WQMeshKit.box(st, Vector3(0, 1.98, 0), Vector3(0.44, 0.22, 0.44), &"foliage")
	# วงโคจร = ก้อนเรียงเป็นวง (กล่องแกนตรงหมุนไม่ได้ วงจึงเป็นจุดไข่ปลา ซึ่งอ่านออกเหมือนกัน)
	for i in 8:
		var a2 := TAU * float(i) / 8.0
		WQMeshKit.box(st, Vector3(cos(a2) * 1.35, 1.3 + sin(a2) * 0.2, sin(a2) * 1.35),
			Vector3(0.24, 0.14, 0.24), &"neutral_1")
	for i in 3:
		var x := -1.75 + float(i) * 0.5
		var hh := 0.62 - float(i) * 0.1
		WQMeshKit.box(st, Vector3(x, 0.16 + hh * 0.5, 1.15), Vector3(0.44, hh, 0.32), &"accent_wood")
		WQMeshKit.box(st, Vector3(x, 0.16 + hh + 0.07, 1.15), Vector3(0.14, 0.14, 0.08), &"neutral_2")
	_grad_cap(st, Vector3(1.62, 0.16, 1.1), 1.15)


## 🎓 มูลนิธิให้ทุนการศึกษา — อาคารเสาหน้ามุขแบบสถาบัน + หมวกบัณฑิตบนลาน
## ความฝันข้อนี้ขอ "กระแสเงินสดมากที่สุด" เพราะมูลนิธิต้องเลี้ยงตัวเองตลอดไป
## ทรงจึงต้องดูเป็น **สถาบันที่อยู่ถาวร** ไม่ใช่งานอีเวนต์ครั้งเดียว
static func _dream_foundation(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.08, 0), Vector3(5.0, 0.16, 3.6), &"neutral_2")
	WQMeshKit.box(st, Vector3(0, 1.35, -0.4), Vector3(3.6, 2.5, 2.2), &"neutral_1")
	for i in 3:
		WQMeshKit.box(st, Vector3(0, 0.24 + float(i) * 0.16, 1.0 - float(i) * 0.22),
			Vector3(3.0 - float(i) * 0.3, 0.16, 0.44), &"neutral_2")
	# เสาห้าต้นหน้ามุข — สัญญะของ "สถาบัน" ที่อ่านออกทันทีแม้ย่อเป็นไอคอน
	for i in 5:
		var x := (float(i) - 2.0) * 0.72
		WQMeshKit.box(st, Vector3(x, 1.5, 0.75), Vector3(0.22, 2.1, 0.22), &"neutral_1")
		WQMeshKit.box(st, Vector3(x, 2.62, 0.75), Vector3(0.32, 0.14, 0.32), &"neutral_2")
	WQMeshKit.box(st, Vector3(0, 2.75, 0.5), Vector3(3.9, 0.22, 1.0), &"neutral_2")
	WQMeshKit.taper(st, Vector3(0, 2.86, 0.4), Vector3(3.9, 0, 1.2), 0.7, 0.0, &"accent_wood")
	for i in 4:
		WQMeshKit.box(st, Vector3(-1.2 + float(i) * 0.8, 1.6, -1.51), Vector3(0.5, 0.8, 0.06), &"accent_steel")
	for i in 4:
		WQMeshKit.box(st, Vector3(-1.2 + float(i) * 0.8, 2.35, -1.51), Vector3(0.5, 0.5, 0.06), &"accent_steel")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 1.81, 1.7, -0.4), Vector3(0.06, 1.0, 1.6), &"accent_steel")
	WQMeshKit.box(st, Vector3(0, 1.05, 0.62), Vector3(0.9, 1.7, 0.1), &"neutral_5")
	WQMeshKit.box(st, Vector3(0, 2.2, 0.62), Vector3(2.0, 0.34, 0.08), &"accent_wood")
	# หมวกบัณฑิตบนแท่นหน้าอาคาร — ของที่บอกว่ามูลนิธินี้ให้ "ทุนการศึกษา" ไม่ใช่มูลนิธิอะไรก็ได้
	# ต้องยกขึ้นบนแท่นและใหญ่พอ ไม่งั้นตอนย่อเป็นไอคอนมันจะแบนไปกับพื้นจนอ่านไม่ออกว่าเป็นหมวก
	_grad_cap(st, Vector3(1.8, 0.16, 1.3), 1.3)
	_tree_small(st, Vector3(-1.85, 0.16, 1.3))


## 🏥 ศูนย์สุขภาพชุมชน — ความฝันที่แพงที่สุดในตาราง จึงต้องเป็นอาคารที่ใหญ่ที่สุดในหกชิ้น
static func _dream_clinic(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.08, 0), Vector3(5.6, 0.16, 4.0), &"neutral_2")
	WQMeshKit.box(st, Vector3(0, 1.75, -0.6), Vector3(3.2, 3.3, 2.4), &"neutral_1")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 2.15, 1.05, -0.9), Vector3(1.3, 1.9, 1.8), &"neutral_1")
		WQMeshKit.box(st, Vector3(sx * 2.15, 2.06, -0.9), Vector3(1.45, 0.14, 1.95), &"neutral_3")
	WQMeshKit.box(st, Vector3(0, 3.48, -0.6), Vector3(3.4, 0.16, 2.6), &"neutral_3")
	# กากบาทบนหน้าอาคาร — สองกล่องที่ทำให้ไม่ต้องมีป้ายก็รู้ว่าเป็นสถานพยาบาล
	WQMeshKit.box(st, Vector3(0, 2.75, 0.63), Vector3(0.9, 0.28, 0.08), &"accent_wood")
	WQMeshKit.box(st, Vector3(0, 2.75, 0.63), Vector3(0.28, 0.9, 0.08), &"accent_wood")
	for f in 3:
		for i in 4:
			WQMeshKit.box(st, Vector3(-1.05 + float(i) * 0.7, 0.85 + float(f) * 0.9, 0.61),
				Vector3(0.45, 0.5, 0.05), &"accent_steel")
	for sx in [-1.0, 1.0]:
		for i in 2:
			WQMeshKit.box(st, Vector3(sx * 2.15, 0.8 + float(i) * 0.8, 0.01),
				Vector3(1.0, 0.45, 0.05), &"accent_steel")
	# กันสาดรถรับส่งผู้ป่วย — บอกว่าที่นี่รับคนตลอดเวลา ไม่ใช่คลินิกเปิดเป็นเวลา
	WQMeshKit.box(st, Vector3(0, 1.9, 1.55), Vector3(2.8, 0.16, 1.6), &"neutral_3")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 1.25, 0.95, 2.2), Vector3(0.16, 1.9, 0.16), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, 0.95, 0.62), Vector3(1.3, 1.9, 0.1), &"accent_steel")
	WQMeshKit.box(st, Vector3(0, 1.95, 0.62), Vector3(1.5, 0.12, 0.14), &"neutral_3")
	# รถพยาบาลคันเล็กจอดอยู่ใต้กันสาด
	WQMeshKit.box(st, Vector3(1.05, 0.42, 1.75), Vector3(0.8, 0.6, 1.5), &"neutral_1")
	WQMeshKit.box(st, Vector3(1.05, 0.85, 2.1), Vector3(0.74, 0.3, 0.7), &"accent_steel")
	WQMeshKit.box(st, Vector3(1.05, 0.9, 1.35), Vector3(0.3, 0.12, 0.3), &"accent_wood")
	_tree_small(st, Vector3(-2.35, 0.16, 1.5))


## 🏎️ คอลเลกชันรถในฝัน + บ้านหลังใหญ่ — ความฝันแบบบริโภคล้วนๆ (ขอรายได้ต่อเดือนน้อยที่สุด)
## โรงรถกระจกอยู่หน้าบ้าน เพราะสิ่งที่อยากโชว์คือรถ ไม่ใช่บ้าน
static func _dream_cars(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.08, 0), Vector3(5.6, 0.16, 4.0), &"neutral_2")
	WQMeshKit.box(st, Vector3(-1.3, 1.3, -1.0), Vector3(3.0, 2.4, 2.0), &"neutral_1")
	WQMeshKit.box(st, Vector3(0.9, 0.95, -1.3), Vector3(1.6, 1.7, 1.5), &"neutral_1")
	for i in 3:
		var t := float(i)
		WQMeshKit.box(st, Vector3(-1.3, 2.6 + t * 0.22, -1.0),
			Vector3(3.4 - t * 0.7, 0.22, 2.4 - t * 0.5), &"accent_wood")
	for i in 3:
		WQMeshKit.box(st, Vector3(-2.35 + float(i) * 0.9, 1.65, -0.01), Vector3(0.6, 0.7, 0.05), &"accent_steel")
	WQMeshKit.box(st, Vector3(-1.3, 0.85, -0.01), Vector3(0.9, 1.5, 0.08), &"neutral_5")
	WQMeshKit.box(st, Vector3(0.9, 1.2, -0.56), Vector3(1.0, 0.9, 0.05), &"accent_steel")
	# โรงรถกระจก — เสาสี่ต้นกับหลังคาบางๆ ให้เห็นรถข้างในเต็มๆ
	WQMeshKit.box(st, Vector3(1.5, 0.2, 1.35), Vector3(2.8, 0.12, 2.2), &"neutral_4")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			WQMeshKit.box(st, Vector3(1.5 + sx * 1.3, 0.75, 1.35 + sz * 1.0),
				Vector3(0.12, 1.1, 0.12), &"neutral_3")
	WQMeshKit.box(st, Vector3(1.5, 1.36, 1.35), Vector3(3.0, 0.14, 2.4), &"neutral_3")
	WQMeshKit.box(st, Vector3(1.5, 0.78, 0.2), Vector3(2.8, 1.05, 0.05), &"accent_steel")
	_toy_car(st, Vector3(0.85, 0.26, 1.35), &"accent_wood")
	_toy_car(st, Vector3(2.15, 0.26, 1.35), &"neutral_5")
	for i in 4:
		WQMeshKit.box(st, Vector3(-1.3, 0.14, 0.5 + float(i) * 0.42), Vector3(1.1, 0.06, 0.34), &"neutral_3")
	_tree_small(st, Vector3(-2.5, 0.16, 1.5))


## 🚀 เปิดบริษัทของตัวเอง ส่งต่อให้ลูกหลาน — ตึกสำนักงานของตัวเองพร้อมป้ายชื่อและเสาธง
## "จากคนที่ทำงานให้เงิน กลายเป็นคนที่สร้างงานให้คนอื่น" — ทรงจึงเป็นตึกทำงาน ไม่ใช่จรวด
static func _dream_company(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.08, 0), Vector3(5.0, 0.16, 3.6), &"neutral_2")
	var floors := 5
	var fh := 0.86
	var h := float(floors) * fh
	WQMeshKit.box(st, Vector3(-0.5, h * 0.5 + 0.16, -0.7), Vector3(2.8, h, 2.2), &"neutral_3")
	WQMeshKit.box(st, Vector3(1.35, 1.35, -0.9), Vector3(1.2, 2.4, 1.8), &"neutral_4")
	for f in floors:
		var y := 0.16 + float(f) * fh + fh * 0.55
		for i in 3:
			WQMeshKit.box(st, Vector3(-1.35 + float(i) * 0.85, y, 0.41), Vector3(0.6, 0.46, 0.05), &"accent_steel")
		WQMeshKit.box(st, Vector3(-1.91, y, -0.7), Vector3(0.05, 0.46, 1.7), &"accent_steel")
	WQMeshKit.box(st, Vector3(-0.5, h + 0.28, -0.7), Vector3(3.0, 0.24, 2.4), &"neutral_4")
	WQMeshKit.box(st, Vector3(-0.5, h + 0.62, -1.1), Vector3(1.0, 0.5, 1.0), &"neutral_4")
	# ล็อบบี้กระจกชั้นล่าง + ป้ายชื่อบริษัท = "บริษัทของเรา" ไม่ใช่ตึกเช่าชั้นหนึ่ง
	WQMeshKit.box(st, Vector3(-0.5, 0.85, 0.44), Vector3(2.4, 1.3, 0.08), &"accent_steel")
	WQMeshKit.box(st, Vector3(-0.5, 0.72, 0.5), Vector3(0.9, 1.05, 0.06), &"neutral_5")
	WQMeshKit.box(st, Vector3(-0.5, 1.72, 0.46), Vector3(2.2, 0.36, 0.1), &"accent_wood")
	WQMeshKit.box(st, Vector3(-0.5, 1.55, 0.9), Vector3(2.6, 0.14, 0.9), &"neutral_1")
	for i in 3:
		WQMeshKit.box(st, Vector3(-0.5, 0.22 + float(i) * 0.1, 0.75 + float(i) * 0.24),
			Vector3(1.6, 0.1, 0.28), &"neutral_1")
	# เสาธงหน้าตึก — ของเล็กที่บอกว่าบริษัทนี้ "ตั้งอยู่จริง" และตั้งใจอยู่ยาว
	WQMeshKit.cylinder_y(st, Vector3(1.9, 0.16, 1.15), 0.06, 2.4, 6, &"neutral_1")
	WQMeshKit.box(st, Vector3(2.25, 2.25, 1.15), Vector3(0.7, 0.44, 0.04), &"accent_wood")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(-0.5 + sx * 1.5, 0.34, 1.35), Vector3(0.44, 0.36, 0.44), &"neutral_4")
		WQMeshKit.box(st, Vector3(-0.5 + sx * 1.5, 0.62, 1.35), Vector3(0.5, 0.3, 0.5), &"foliage")


## หมวกบัณฑิตบนแท่นเตี้ย — ใช้ทั้งความฝัน "กองทุนการศึกษาลูก" และ "มูลนิธิให้ทุน"
## แผ่นบนต้องกว้างกว่าตัวหมวกเกินเท่าตัวและมีพู่ห้อย ไม่งั้นมันคือกล่องสี่เหลี่ยมธรรมดา
static func _grad_cap(st: SurfaceTool, base: Vector3, scale: float) -> void:
	var u := scale
	# ตัวหมวกอยู่ใต้แผ่นบนและต้องมองเห็น — เวอร์ชันแรกวางแผ่นบนแท่นเตี้ย ผลคือมองจากมุมไอคอน
	# (yaw 45° pitch 30°) มันอ่านเป็น "โต๊ะดำ" เพราะเห็นแต่แผ่นกับขา
	WQMeshKit.box(st, base + Vector3(0, 0.16 * u, 0), Vector3(0.54 * u, 0.32 * u, 0.54 * u), &"neutral_4")
	WQMeshKit.box(st, base + Vector3(0, 0.36 * u, 0), Vector3(1.0 * u, 0.07 * u, 1.0 * u), &"neutral_5")
	# พู่ห้อย **ลง** ข้างแผ่น — เส้นเดียวที่ทำให้อ่านเป็นหมวกบัณฑิต ไม่ใช่แผ่นสี่เหลี่ยม
	WQMeshKit.box(st, base + Vector3(0.44 * u, 0.24 * u, 0.44 * u),
		Vector3(0.06 * u, 0.3 * u, 0.06 * u), &"neutral_1")
	WQMeshKit.box(st, base + Vector3(0.44 * u, 0.08 * u, 0.44 * u),
		Vector3(0.13 * u, 0.14 * u, 0.13 * u), &"neutral_1")
	WQMeshKit.box(st, base + Vector3(0, 0.42 * u, 0), Vector3(0.12 * u, 0.06 * u, 0.12 * u), &"neutral_1")


## ต้นไม้เล็กสำหรับลานหน้าอาคารความฝัน — เตี้ยกว่าต้นไม้ในเมืองเพื่อไม่ให้บังตัวอาคาร
static func _tree_small(st: SurfaceTool, base: Vector3) -> void:
	WQMeshKit.cylinder_y(st, base, 0.09, 0.6, 6, &"accent_wood")
	WQMeshKit.taper(st, base + Vector3(0, 0.5, 0), Vector3(0.95, 0, 0.95), 0.6, 0.55, &"foliage")
	WQMeshKit.taper(st, base + Vector3(0, 1.0, 0), Vector3(0.6, 0, 0.6), 0.5, 0.0, &"foliage")


## รถคันจิ๋วสำหรับโชว์ในโรงรถ — ไม่ใช้ WQKitbash._car เพราะคันจริงกินเกือบ 400 tris
## ทั้งความฝันมีงบ 1500 ถ้าใส่รถจริงสองคันก็หมดงบไปกับของที่อยู่หลังกระจก
static func _toy_car(st: SurfaceTool, at: Vector3, body: StringName) -> void:
	WQMeshKit.box(st, at + Vector3(0, 0.14, 0), Vector3(0.62, 0.28, 1.5), body)
	WQMeshKit.box(st, at + Vector3(0, 0.36, -0.1), Vector3(0.54, 0.22, 0.7), &"accent_steel")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			WQMeshKit.box(st, at + Vector3(sx * 0.31, 0.08, sz * 0.45),
				Vector3(0.08, 0.16, 0.3), &"neutral_5")
