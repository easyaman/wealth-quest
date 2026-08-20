class_name WQKitbashPlaces
extends RefCounted
## อาคาร 10 หลังในฉากเมือง + prop ที่ใช้ซ้ำรอบตึก — ต่อกล่องจากโค้ด (Sprint C ข้อ 1)
##
## ทำไมต่อกล่องแทนที่จะรอ .glb: Sprint A/B ทิ้งเมืองไว้เป็นกล่องสิบใบสูงไม่เท่ากัน
## ผู้เล่นแยกไม่ออกว่าหลังไหนคือธนาคาร หลังไหนคือฟิตเนส ต้องอ่านป้ายอย่างเดียว
## ซึ่งขัดกับ ART-DIRECTION ข้อ 1.3 ที่ต้องการให้ "รูปทรงเป็นตัวบอกว่าอะไรคืออะไร"
## วันที่ได้ .glb จริงมา ให้วางทับที่ world/models/places/<id>.glb แล้วไฟล์นี้จะถูกข้ามไปเอง
##
## กติกาเดียวกับโมเดลจริงทุกข้อ (model_lint ตรวจให้):
##   · origin ที่ฐาน y=0 · 1 unit = 1 เมตร · **ด้านหน้าอาคารหันไป +Z** (ฝั่งถนน)
##   · วัสดุเดียวคือ flat.tres · สีมาจากช่องบน palette.png เท่านั้น ไม่มี albedo_color
##   · งบสามเหลี่ยม places 400–1500 · props 50–300 (WQModelIds.BUDGET)
##
## **ความกว้างของอาคารถูกจำกัดด้วยช่องของตัวเองบนถนน** — x ใน places.json บางคู่ห่างกันแค่
## 3 หน่วย (บ้าน 50 · ฟิตเนส 56 · ธนาคาร 62) อาคารสามหลังนั้นจึงต้องแคบราว 2.4 ม.
## แล้วไปเอาเนื้อที่คืนทางความลึก (แกน Z) ซึ่งว่างเสมอ — เหมือนตึกแถวจริงที่หน้าแคบแต่ลึกมาก
## `sim/world_check.gd` มีเทสต์ "อาคารไม่มีหลังไหนกินเนื้อที่ทับกัน" คุมข้อนี้ไว้แล้ว
##
## **ห้ามใช้ money / time / health เป็นสีหลัก** — สามสีนั้นจองไว้บอกสถานะของผู้เล่น
## ถ้าเอาไปทาตึก ผู้เล่นจะอ่านฉากผิดว่าตึกนั้นกำลังบอกอะไรอยู่

const PLACES := ["home", "office", "bank", "estate", "gold",
	"cowork", "school", "gym", "mall", "resort"]

## prop ไม่มี id ใน data/*.json เพราะเป็นของประดับฉากล้วนๆ ไม่มีผลต่อกฎเกม
## จึงเป็นข้อยกเว้นเดียวของกติกา "ชื่อไฟล์ = id ใน data" — รายชื่ออยู่ที่นี่ที่เดียว
const PROPS := ["tree", "lamp", "bench"]


static func has(kind: String, id: String) -> bool:
	match kind:
		"places": return PLACES.has(id)
		"props": return PROPS.has(id)
	return false


static func build(kind: String, id: String) -> MeshInstance3D:
	if not has(kind, id): return null
	var st := WQMeshKit.begin()
	match kind:
		"places": _place(st, id)
		"props": _prop(st, id)
	return WQMeshKit.finish(st, id)


# ========== อาคาร ==========

static func _place(st: SurfaceTool, id: String) -> void:
	match id:
		"home": _home(st)
		"office": _office(st)
		"bank": _bank(st)
		"estate": _estate(st)
		"gold": _gold(st)
		"cowork": _cowork(st)
		"school": _school(st)
		"gym": _gym(st)
		"mall": _mall(st)
		"resort": _resort(st)


## 🏠 บ้าน — หลังเล็กที่สุดในเมือง หลังคาจั่วชัดๆ ให้เห็นแต่ไกลว่านี่คือ "บ้าน" ไม่ใช่ตึก
static func _home(st: SurfaceTool) -> void:
	var w := 2.4
	var d := 3.4
	var h := 2.6
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"neutral_2")
	# หลังคาจั่ว = ปริซึมที่สอบเข้าจนเหลือสันเดียว ทำด้วย taper ที่บีบเฉพาะแกน Z ไม่ได้
	# จึงซ้อนกล่องแคบลงสามชั้นแทน — เหลี่ยมชัดกว่าและอยู่ในสไตล์ low poly เหมือนกัน
	for i in 3:
		var t := float(i)
		WQMeshKit.box(st, Vector3(0, h + 0.18 + t * 0.34, 0),
			Vector3(w + 0.25 - t * 0.5, 0.34, d + 0.35 - t * 0.28), &"accent_wood")
	_door(st, Vector3(0, 0, d * 0.5), 0.75, 1.5)
	for sx in [-1.0, 1.0]:
		_window(st, Vector3(sx * 0.75, 1.7, d * 0.5), 0.7, 0.6)
	_window(st, Vector3(w * 0.5, 1.6, -0.5), 0.6, 0.6, true)
	# รั้วเตี้ยหน้าบ้าน + พุ่มไม้ข้างรั้ว — ทำให้บ้านมี "เขตของตัวเอง" ไม่ลอยอยู่กลางทางเท้า
	for i in 5:
		WQMeshKit.box(st, Vector3(-1.2 + float(i) * 0.6, 0.28, d * 0.5 + 1.1),
			Vector3(0.09, 0.56, 0.09), &"neutral_1")
	for i in 4:
		WQMeshKit.box(st, Vector3(-1.05 + float(i) * 0.7, 0.22, d * 0.5 + 0.85),
			Vector3(0.6, 0.44, 0.34), &"foliage")
	# ทางเดินเข้าบ้านเป็นแผ่นทางเดิน — บอกทิศทางว่าประตูอยู่ฝั่งถนน
	for i in 3:
		WQMeshKit.box(st, Vector3(0, 0.03, d * 0.5 + 0.35 + float(i) * 0.42),
			Vector3(0.8, 0.06, 0.34), &"neutral_1")
	WQMeshKit.box(st, Vector3(1.05, 0.5, d * 0.5 + 1.1), Vector3(0.08, 1.0, 0.08), &"neutral_5")
	WQMeshKit.box(st, Vector3(1.05, 1.08, d * 0.5 + 1.1), Vector3(0.26, 0.2, 0.34), &"neutral_1")
	# ปล่องไฟ + หน้าต่างด้านข้าง ให้หลังคาไม่เป็นสามเหลี่ยมเปล่าเมื่อมองจากมุมกล้อง
	WQMeshKit.box(st, Vector3(-0.75, h + 1.15, -0.7), Vector3(0.42, 1.3, 0.42), &"neutral_4")
	WQMeshKit.box(st, Vector3(-0.75, h + 1.85, -0.7), Vector3(0.56, 0.16, 0.56), &"neutral_5")
	_window(st, Vector3(w * 0.5, 0.95, 0.55), 0.6, 0.7, true)
	_window(st, Vector3(w * 0.5, 1.7, -0.55), 0.6, 0.6, true)
	# กรอบหน้าต่างหน้าบ้าน — ขอบสว่างรอบกระจกทำให้บ้านดู "มีคนอยู่" ไม่ใช่กล่องเจาะรู
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 0.75, 1.7, d * 0.5 + 0.04),
			Vector3(0.84, 0.74, 0.05), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, h + 1.24, 0), Vector3(0.3, 0.22, d + 0.4), &"neutral_5")
	WQMeshKit.box(st, Vector3(0, 0.06, d * 0.5 + 1.62), Vector3(1.9, 0.12, 0.7), &"neutral_4")


## 🏢 ออฟฟิศ — ตึกสูงที่สุดในเมือง แถบหน้าต่างเรียงเป็นชั้นๆ อ่านออกทันทีว่าเป็นตึกทำงาน
static func _office(st: SurfaceTool) -> void:
	var w := 3.4
	var d := 3.6
	var floors := 8
	var fh := 1.35
	var h := float(floors) * fh
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"neutral_3")
	_floors(st, w, d, fh, floors, 0.9, 3, &"accent_steel")
	# แกนลิฟต์ยื่นขึ้นเหนือดาดฟ้า + ขอบดาดฟ้า — เงาสองก้อนนี้ทำให้ยอดตึกไม่แบน
	WQMeshKit.box(st, Vector3(0, h + 0.12, 0), Vector3(w + 0.3, 0.24, d + 0.3), &"neutral_4")
	WQMeshKit.box(st, Vector3(-0.6, h + 0.85, -0.4), Vector3(1.3, 1.5, 1.3), &"neutral_4")
	_canopy(st, d * 0.5, 2.2)
	_door(st, Vector3(0, 0, d * 0.5), 1.1, 1.9)


## 🏦 ธนาคาร — เสาหินหน้าอาคาร + บันได ภาษาภาพของ "สถาบันการเงิน" ที่อ่านได้ทั่วโลก
static func _bank(st: SurfaceTool) -> void:
	var w := 2.6
	var d := 3.8
	var h := 4.2
	# บันไดสามขั้นเต็มความกว้าง ทำให้อาคารดู "ต้องเดินขึ้นไป" ไม่ใช่เดินเข้าตรงๆ
	for i in 3:
		var t := float(i)
		WQMeshKit.box(st, Vector3(0, 0.11 + t * 0.22, d * 0.5 + 0.75 - t * 0.25),
			Vector3(w * 0.82 - t * 0.2, 0.22, 1.5 - t * 0.5), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, 0.66 + h * 0.5, 0), Vector3(w, h, d), &"neutral_2")
	for i in 3:
		var x := -0.85 + float(i) * 0.85
		WQMeshKit.cylinder_y(st, Vector3(x, 0.66, d * 0.5 + 0.12), 0.19, h - 0.5, 8, &"neutral_1")
	# หน้าจั่วสามเหลี่ยมบนหัวเสา — taper จนเหลือสันแคบ ไม่ใช่ปลายแหลม จะได้ยังเห็นเป็นแผ่นหนา
	WQMeshKit.box(st, Vector3(0, 0.66 + h - 0.2, d * 0.5 + 0.1),
		Vector3(w + 0.15, 0.4, 0.7), &"neutral_1")
	WQMeshKit.taper(st, Vector3(0, 0.66 + h, d * 0.5 + 0.1),
		Vector3(w, 0, 0.6), 0.75, 0.12, &"neutral_1")
	_door(st, Vector3(0, 0.66, d * 0.5), 1.2, 2.0)
	for sx in [-1.0, 1.0]:
		_window(st, Vector3(sx * w * 0.5, 0.66 + h * 0.62, 0.6), 1.1, 1.3, true)
		_window(st, Vector3(sx * w * 0.5, 0.66 + h * 0.62, -0.9), 1.1, 1.3, true)
	# ตู้เอทีเอ็มข้างบันได — ของชิ้นเล็กที่ยืนยันว่าเป็นธนาคาร ไม่ใช่ศาลากลาง
	WQMeshKit.box(st, Vector3(w * 0.5 + 0.75, 0.55, d * 0.5 + 0.5), Vector3(0.7, 1.1, 0.6),
		&"neutral_4")
	WQMeshKit.box(st, Vector3(w * 0.5 + 0.75, 0.85, d * 0.5 + 0.81), Vector3(0.44, 0.4, 0.05),
		&"accent_steel")
	WQMeshKit.box(st, Vector3(w * 0.5 + 0.75, 1.16, d * 0.5 + 0.5), Vector3(0.78, 0.12, 0.68),
		&"neutral_1")
	# บัวเชิงหลังคารอบตึก + กระถางสองข้างบันได
	WQMeshKit.box(st, Vector3(0, 0.66 + h + 0.12, 0), Vector3(w + 0.2, 0.24, d + 0.34),
		&"neutral_1")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * (w * 0.5 - 0.25), 0.28, d * 0.5 + 1.5),
			Vector3(0.55, 0.56, 0.55), &"neutral_2")
		WQMeshKit.taper(st, Vector3(sx * (w * 0.5 - 0.25), 0.56, d * 0.5 + 1.5),
			Vector3(0.66, 0, 0.66), 0.7, 0.3, &"foliage")
		WQMeshKit.box(st, Vector3(sx * 1.2, 0.66 + h * 0.5, d * 0.5 + 0.1),
			Vector3(0.2, h, 0.3), &"neutral_1")
		WQMeshKit.box(st, Vector3(sx * 1.05, 0.72, d * 0.5 + 1.25), Vector3(0.12, 0.28, 0.9),
			&"neutral_1")


## 🏬 ศูนย์อสังหาฯ — ป้ายบิลบอร์ดบนดาดฟ้า คือของที่บอกว่าที่นี่ "ขายของชิ้นใหญ่"
static func _estate(st: SurfaceTool) -> void:
	var w := 3.4
	var d := 3.8
	var floors := 5
	var fh := 1.3
	var h := float(floors) * fh
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"neutral_4")
	_floors(st, w, d, fh, floors, 0.85, 3, &"accent_steel")
	WQMeshKit.box(st, Vector3(0, h + 0.1, 0), Vector3(w + 0.24, 0.2, d + 0.24), &"neutral_5")
	# บิลบอร์ด: ขาสองข้าง + แผ่นป้าย เอียงเข้าหาถนนนิดหน่อยให้เห็นหน้าป้ายจากมุมกล้อง isometric
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 1.0, h + 0.9, -0.2), Vector3(0.14, 1.6, 0.14), &"neutral_5")
	WQMeshKit.box(st, Vector3(0, h + 1.85, -0.15), Vector3(2.9, 1.5, 0.12), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, h + 1.85, -0.05), Vector3(2.5, 1.15, 0.06), &"accent_wood")
	_canopy(st, d * 0.5, 2.4)
	_door(st, Vector3(0, 0, d * 0.5), 1.2, 1.9)


## 💍 ร้านทอง — ร้านห้องแถวเตี้ยๆ กระจกโชว์ของเต็มหน้าร้าน + กันสาดลายทาง
static func _gold(st: SurfaceTool) -> void:
	var w := 3.0
	var d := 2.6
	var h := 3.0
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"accent_wood")
	# ตู้กระจกโชว์เกือบเต็มหน้าร้าน — ของในร้านนี้คือ "ของที่ต้องมองเห็น" (ทอง ของสะสม)
	WQMeshKit.box(st, Vector3(0, 1.15, d * 0.5 + 0.02), Vector3(w * 0.82, 1.5, 0.08), &"accent_steel")
	WQMeshKit.box(st, Vector3(0, 0.3, d * 0.5 + 0.03), Vector3(w * 0.82, 0.6, 0.1), &"neutral_5")
	for i in 5:
		WQMeshKit.box(st, Vector3(-1.0 + float(i) * 0.5, 2.1, d * 0.5 + 0.42),
			Vector3(0.5, 0.1, 0.9), &"neutral_1" if i % 2 == 0 else &"accent_wood")
	WQMeshKit.box(st, Vector3(0, h + 0.28, 0), Vector3(w + 0.24, 0.56, d * 0.5), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, h + 0.28, d * 0.25 + 0.04), Vector3(w * 0.8, 0.34, 0.06), &"neutral_5")
	# เหล็กดัดหน้าตู้กระจก — ร้านทองในไทยมีทุกร้าน และเป็นสัญญาณว่า "ของข้างในมีค่า"
	for i in 6:
		WQMeshKit.box(st, Vector3(-1.05 + float(i) * 0.42, 1.15, d * 0.5 + 0.08),
			Vector3(0.05, 1.5, 0.05), &"neutral_1")
	# ของในตู้ — ก้อนเล็กๆ เรียงเป็นแถว เห็นเป็นเงาผ่านกระจกจากมุมกล้อง
	for i in 4:
		WQMeshKit.box(st, Vector3(-0.72 + float(i) * 0.48, 0.72, d * 0.5 - 0.1),
			Vector3(0.3, 0.22, 0.18), &"neutral_1")
	# ชั้นบนเป็นที่พักเจ้าของร้าน — หน้าต่างบานเกล็ดสามช่อง + แอร์
	for i in 3:
		WQMeshKit.box(st, Vector3(-0.85 + float(i) * 0.85, 2.5, d * 0.5 + 0.02),
			Vector3(0.55, 0.6, 0.08), &"neutral_5")
	WQMeshKit.box(st, Vector3(w * 0.5 + 0.02, 2.4, -0.5), Vector3(0.1, 0.5, 0.7), &"neutral_1")
	WQMeshKit.box(st, Vector3(w * 0.5 + 0.02, 1.5, -0.5), Vector3(0.1, 0.5, 0.7), &"neutral_1")
	# ราวกันตกดาดฟ้า
	for i in 4:
		WQMeshKit.box(st, Vector3(-1.1 + float(i) * 0.73, h + 0.72, -d * 0.25),
			Vector3(0.08, 0.32, 0.08), &"neutral_5")
	WQMeshKit.box(st, Vector3(0, h + 0.88, -d * 0.25), Vector3(2.4, 0.08, 0.08), &"neutral_5")
	# ตัวอักษรบนป้ายหน้าร้าน — สี่ก้อนพอให้อ่านว่า "มีชื่อร้านเขียนอยู่" โดยไม่ต้องมี texture
	for i in 4:
		WQMeshKit.box(st, Vector3(-0.6 + float(i) * 0.4, h + 0.28, d * 0.25 + 0.09),
			Vector3(0.22, 0.22, 0.04), &"accent_wood")


## 💻 Co-working — กล่องกระจกเตี้ยกว้าง โปร่งกว่าทุกหลัง + ระเบียงต้นไม้บนดาดฟ้า
static func _cowork(st: SurfaceTool) -> void:
	var w := 3.5
	var d := 3.8
	var floors := 3
	var fh := 1.5
	var h := float(floors) * fh
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"accent_steel")
	# เสากรอบตั้งเป็นระยะ ทำให้ก้อนกระจกไม่กลายเป็นกล่องทึบก้อนเดียว
	for i in 5:
		WQMeshKit.box(st, Vector3(-w * 0.5 + float(i) * (w / 4.0), h * 0.5, d * 0.5 + 0.02),
			Vector3(0.16, h, 0.08), &"neutral_1")
	# คานนอนคั่นชั้น — เริ่มที่ชั้น 1 ไม่ใช่ชั้น 0 ไม่งั้นคานล่างสุดจะจมลงใต้พื้นครึ่งใบ
	# แล้ว model_lint จะจับได้ว่าฐานโมเดลไม่ได้อยู่ที่ y=0 (เจอจริงตอนต่อหลังนี้ครั้งแรก)
	for i in range(1, floors + 1):
		WQMeshKit.box(st, Vector3(0, float(i) * fh, d * 0.5 + 0.02),
			Vector3(w + 0.1, 0.14, 0.1), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, h + 0.09, 0), Vector3(w + 0.2, 0.18, d + 0.2), &"neutral_1")
	# กระถางต้นไม้บนดาดฟ้า — เอกลักษณ์ของ co-working ที่แยกมันออกจากออฟฟิศทั่วไป
	for sx in [-1.0, 0.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 1.1, h + 0.4, 0.8), Vector3(0.5, 0.44, 0.5), &"neutral_2")
		WQMeshKit.taper(st, Vector3(sx * 1.1, h + 0.62, 0.8), Vector3(0.62, 0, 0.62),
			0.7, 0.25, &"foliage")
	# โต๊ะทำงานเรียงในชั้นล่าง — มองทะลุกระจกเห็นเป็นเงา บอกว่าที่นี่คือที่ "นั่งทำงาน"
	for i in 3:
		WQMeshKit.box(st, Vector3(-1.05 + float(i) * 1.05, 0.72, 0.3),
			Vector3(0.85, 0.08, 0.55), &"neutral_5")
		WQMeshKit.box(st, Vector3(-1.05 + float(i) * 1.05, 0.36, 0.3),
			Vector3(0.12, 0.72, 0.12), &"neutral_5")
	# ที่จอดจักรยานหน้าอาคาร
	for i in 4:
		WQMeshKit.box(st, Vector3(-1.2 + float(i) * 0.4, 0.28, d * 0.5 + 0.9),
			Vector3(0.06, 0.56, 0.4), &"neutral_4")
	# ราวกันตกดาดฟ้า
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * (w * 0.5 - 0.1), h + 0.5, 0), Vector3(0.07, 0.6, d),
			&"neutral_1")
	WQMeshKit.box(st, Vector3(0, h + 0.5, d * 0.5 - 0.1), Vector3(w, 0.6, 0.07), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, h + 0.5, -d * 0.5 + 0.1), Vector3(w, 0.6, 0.07), &"neutral_1")
	# จักรยานที่จอดอยู่จริงหนึ่งคัน — ที่จอดว่างเปล่าอ่านไม่ออกว่าเป็นที่จอดอะไร
	WQMeshKit.box(st, Vector3(-0.85, 0.55, d * 0.5 + 0.9), Vector3(0.08, 0.5, 1.0), &"accent_wood")
	WQMeshKit.cylinder_x(st, Vector3(-0.85, 0.3, d * 0.5 + 1.3), 0.3, 0.04, 8, &"neutral_5")
	WQMeshKit.cylinder_x(st, Vector3(-0.85, 0.3, d * 0.5 + 0.5), 0.3, 0.04, 8, &"neutral_5")
	_door(st, Vector3(0, 0, d * 0.5), 1.0, 1.8)


## 🎓 สถาบันสอน — ตึกแนวนอนสามชั้น + หอนาฬิกาตรงกลาง + เสาธง
static func _school(st: SurfaceTool) -> void:
	var w := 3.4
	var d := 3.8
	var floors := 3
	var fh := 1.4
	var h := float(floors) * fh
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"neutral_2")
	_floors(st, w, d, fh, floors, 0.85, 4, &"accent_steel")
	WQMeshKit.box(st, Vector3(0, h + 0.1, 0), Vector3(w + 0.26, 0.2, d + 0.26), &"accent_wood")
	# หอนาฬิกา: ยื่นออกหน้าอาคารเพื่อให้เห็นเป็นทางเข้าหลัก ไม่ใช่กล่องที่ตั้งบนหลังคาเฉยๆ
	var tw := 1.5
	WQMeshKit.box(st, Vector3(0, (h + 1.6) * 0.5, d * 0.5 - 0.3),
		Vector3(tw, h + 1.6, tw), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, h + 1.05, d * 0.5 - 0.3 + tw * 0.5),
		Vector3(0.72, 0.72, 0.08), &"neutral_5")
	WQMeshKit.taper(st, Vector3(0, h + 1.6, d * 0.5 - 0.3),
		Vector3(tw + 0.3, 0, tw + 0.3), 1.1, 0.0, &"accent_wood")
	# เสาธงย้ายมาอยู่ "หน้า" อาคารแทนที่จะอยู่ข้าง เพราะช่องของสถาบันสอนบนถนนกว้างแค่ 4 หน่วย
	# ถ้าปักไว้ข้างอาคารมันจะไปโผล่ในเขตของศูนย์อสังหาฯ ที่อยู่ติดกัน
	WQMeshKit.cylinder_y(st, Vector3(-1.3, 0, d * 0.5 + 1.1), 0.07, 3.4, 6, &"neutral_1")
	WQMeshKit.box(st, Vector3(-0.95, 3.05, d * 0.5 + 1.1),
		Vector3(0.66, 0.44, 0.04), &"accent_wood")
	_door(st, Vector3(0, 0, d * 0.5 + tw * 0.5 - 0.3), 0.9, 1.8)


## 🏋️ ฟิตเนส — กล่องเตี้ยหน้ากระจกยาว + ป้ายดัมเบลบนหลังคา (รูปทรงบอกได้โดยไม่ต้องอ่านป้าย)
static func _gym(st: SurfaceTool) -> void:
	var w := 2.4
	var d := 3.8
	var h := 3.4
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"neutral_4")
	WQMeshKit.box(st, Vector3(0, 2.0, d * 0.5 + 0.02), Vector3(w * 0.88, 1.7, 0.08), &"accent_steel")
	for i in 4:
		WQMeshKit.box(st, Vector3(-w * 0.36 + float(i) * (w * 0.24), 2.0, d * 0.5 + 0.05),
			Vector3(0.1, 1.7, 0.06), &"neutral_4")
	WQMeshKit.box(st, Vector3(0, h + 0.1, 0), Vector3(w + 0.2, 0.2, d + 0.2), &"neutral_5")
	# ดัมเบลบนหลังคา: คานนอน + จานสองข้างเป็นทรงกระบอกแกนนอน
	WQMeshKit.box(st, Vector3(0, h + 0.85, 0), Vector3(1.5, 0.16, 0.16), &"neutral_1")
	for sx in [-1.0, 1.0]:
		WQMeshKit.cylinder_x(st, Vector3(sx * 0.82, h + 0.85, 0), 0.4, 0.16, 8, &"neutral_1")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 1.0, h + 0.45, 0), Vector3(0.12, 0.7, 0.12), &"neutral_5")
	# หน้าต่างยาวด้านข้างด้วย — ฟิตเนสคือที่ที่ "คนข้างนอกมองเห็นคนข้างในออกกำลัง"
	WQMeshKit.box(st, Vector3(w * 0.5 + 0.02, 2.0, 0), Vector3(0.08, 1.6, d * 0.82),
		&"accent_steel")
	for i in 3:
		WQMeshKit.box(st, Vector3(w * 0.5 + 0.05, 2.0, -1.0 + float(i) * 1.0),
			Vector3(0.06, 1.6, 0.1), &"neutral_4")
	# กองแผ่นน้ำหนักกับเสาแบนเนอร์อยู่ "หน้า" ร้าน ไม่ใช่ข้างร้าน — ช่องของฟิตเนสกว้างแค่ 3 หน่วย
	for i in 3:
		WQMeshKit.cylinder_x(st, Vector3(-0.75, 0.34 + float(i) * 0.1, d * 0.5 + 0.6),
			0.34 - float(i) * 0.06, 0.07, 8, &"neutral_5")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 1.02, 1.4, d * 0.5 + 0.7), Vector3(0.1, 2.8, 0.1),
			&"neutral_5")
		WQMeshKit.box(st, Vector3(sx * 1.02, 2.2, d * 0.5 + 0.78), Vector3(0.45, 1.3, 0.05),
			&"accent_wood")
	# เครื่องปรับอากาศบนดาดฟ้า
	for i in 2:
		WQMeshKit.box(st, Vector3(-0.65 + float(i) * 1.3, h + 0.5, -0.8),
			Vector3(0.7, 0.6, 0.7), &"neutral_2")
	_door(st, Vector3(0, 0, d * 0.5), 1.0, 1.9)


## 🛒 ห้าง — กล่องกว้างที่สุดในเมือง + กันสาดทางเข้ายาว + เครื่องปรับอากาศเต็มดาดฟ้า
static func _mall(st: SurfaceTool) -> void:
	var w := 4.2
	var d := 4.4
	var h := 4.0
	WQMeshKit.box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), &"neutral_3")
	WQMeshKit.box(st, Vector3(0, 2.6, d * 0.5 + 0.02), Vector3(w * 0.9, 1.5, 0.08), &"accent_steel")
	# ทางเข้าโค้งเป็นชั้นๆ ให้ดูเป็นโถงสูง ไม่ใช่ประตูบานเดียวเหมือนตึกอื่น
	WQMeshKit.box(st, Vector3(0, 1.1, d * 0.5 + 0.06), Vector3(2.6, 2.2, 0.12), &"accent_steel")
	WQMeshKit.box(st, Vector3(0, 2.35, d * 0.5 + 0.55), Vector3(3.4, 0.18, 1.2), &"neutral_1")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 1.5, 1.15, d * 0.5 + 1.05), Vector3(0.12, 2.3, 0.12),
			&"neutral_1")
	WQMeshKit.box(st, Vector3(0, h + 0.12, 0), Vector3(w + 0.3, 0.24, d + 0.3), &"neutral_5")
	for i in 3:
		for j in 2:
			WQMeshKit.box(st, Vector3(-1.4 + float(i) * 1.4, h + 0.55, -0.9 + float(j) * 1.5),
				Vector3(0.85, 0.6, 0.8), &"neutral_2")
	# เสาป้ายริมถนน — ของที่ทำให้ห้างอ่านออกจากปลายถนนได้ แม้ตัวอาคารจะโดนตึกอื่นบัง
	# เสาป้ายอยู่ "หน้า" ห้าง ไม่ใช่ข้างห้าง — ข้างห้างเป็นเขตของร้านทองกับโรงแรม
	WQMeshKit.box(st, Vector3(-1.6, 2.2, d * 0.5 + 1.3), Vector3(0.22, 4.4, 0.22), &"neutral_5")
	WQMeshKit.box(st, Vector3(-1.6, 4.1, d * 0.5 + 1.3), Vector3(1.3, 1.1, 0.1), &"neutral_1")
	# หน้าต่างยาวด้านข้าง + ป้ายร้านย่อยเรียงใต้ชายคา — ห้างคือ "หลายร้านในหลังเดียว"
	WQMeshKit.box(st, Vector3(w * 0.5 + 0.02, 2.6, 0), Vector3(0.08, 1.4, d * 0.86),
		&"accent_steel")
	for i in 4:
		WQMeshKit.box(st, Vector3(-1.6 + float(i) * 1.05, 1.35, d * 0.5 + 0.05),
			Vector3(0.9, 0.4, 0.06), &"neutral_1")
	# เสากั้นทางเท้าหน้าห้าง + ที่เก็บรถเข็น
	for i in 5:
		WQMeshKit.box(st, Vector3(-1.8 + float(i) * 0.9, 0.3, d * 0.5 + 1.6),
			Vector3(0.14, 0.6, 0.14), &"neutral_5")
	WQMeshKit.box(st, Vector3(w * 0.5 - 0.6, 0.5, d * 0.5 + 1.1), Vector3(1.0, 1.0, 0.7),
		&"neutral_2")
	WQMeshKit.box(st, Vector3(w * 0.5 - 0.6, 1.05, d * 0.5 + 1.1), Vector3(1.1, 0.1, 0.8),
		&"neutral_5")
	# เครื่องปรับอากาศเพิ่มอีกแถวบนดาดฟ้า + ปล่องระบายอากาศ
	for i in 3:
		WQMeshKit.box(st, Vector3(-1.4 + float(i) * 1.4, h + 0.45, 0.9),
			Vector3(0.8, 0.4, 0.7), &"neutral_2")
	WQMeshKit.cylinder_y(st, Vector3(1.6, h + 0.24, -1.2), 0.32, 1.1, 8, &"neutral_5")


## 🏨 โรงแรม & รีสอร์ต — ฐานกว้าง + ตึกพักสูง ระเบียงทุกชั้น + สระว่ายน้ำหน้าโรงแรม
static func _resort(st: SurfaceTool) -> void:
	var pw := 5.0
	var pd := 3.4
	var ph := 1.8
	WQMeshKit.box(st, Vector3(0, ph * 0.5, 0), Vector3(pw, ph, pd), &"neutral_2")
	WQMeshKit.box(st, Vector3(0, ph + 0.1, 0), Vector3(pw + 0.26, 0.2, pd + 0.26), &"accent_wood")
	var floors := 5
	var fh := 1.25
	var tw := 3.4
	var td := 2.6
	var top := ph + 0.2 + float(floors) * fh
	WQMeshKit.box(st, Vector3(0, ph + 0.2 + float(floors) * fh * 0.5, -0.2),
		Vector3(tw, float(floors) * fh, td), &"neutral_1")
	# ระเบียงยื่นทุกชั้น — เงาเป็นเส้นนอนถี่ๆ คือสิ่งที่ทำให้อ่านว่า "โรงแรม" ไม่ใช่ "ออฟฟิศ"
	for i in floors:
		var y := ph + 0.2 + float(i) * fh
		WQMeshKit.box(st, Vector3(0, y + fh * 0.62, td * 0.5 - 0.2 + 0.18),
			Vector3(tw * 0.92, 0.6, 0.1), &"accent_steel")
		WQMeshKit.box(st, Vector3(0, y + fh * 0.28, td * 0.5 - 0.2 + 0.3),
			Vector3(tw * 0.96, 0.14, 0.55), &"accent_wood")
	WQMeshKit.box(st, Vector3(0, top + 0.12, -0.2), Vector3(tw + 0.3, 0.24, td + 0.3),
		&"accent_wood")
	# สระว่ายน้ำหน้าโรงแรม — ที่เดียวในเมืองที่ใช้สีน้ำ ผู้เล่นจึงจำหลังนี้ได้จากสีเดียว
	WQMeshKit.box(st, Vector3(0, 0.06, pd * 0.5 + 1.15), Vector3(3.6, 0.12, 1.8), &"neutral_1")
	WQMeshKit.box(st, Vector3(0, 0.1, pd * 0.5 + 1.15), Vector3(3.1, 0.1, 1.35), &"water")
	# เตียงอาบแดดริมสระ + ร่ม — ของสามชิ้นนี้คือสิ่งที่ทำให้ "สระ" อ่านว่าพักผ่อน ไม่ใช่บ่อน้ำ
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 2.35, 0.22, pd * 0.5 + 1.15), Vector3(0.5, 0.12, 1.0),
			&"neutral_1")
		WQMeshKit.box(st, Vector3(sx * 2.35, 0.11, pd * 0.5 + 1.15), Vector3(0.1, 0.22, 0.8),
			&"neutral_5")
	WQMeshKit.cylinder_y(st, Vector3(0, 0.0, pd * 0.5 + 2.35), 0.06, 1.9, 6, &"neutral_1")
	WQMeshKit.taper(st, Vector3(0, 1.55, pd * 0.5 + 2.35), Vector3(1.9, 0, 1.9), 0.45, 0.1,
		&"accent_wood")
	# หน้าต่างด้านข้างตึกพัก — ให้ด้าน +X ที่กล้องเห็นไม่เป็นแผ่นเปล่า
	for i in 5:
		WQMeshKit.box(st, Vector3(tw * 0.5 + 0.02, ph + 0.2 + float(i) * fh + fh * 0.55, -0.2),
			Vector3(0.08, 0.62, td * 0.62), &"accent_steel")
	# หลังคาคลุมทางรถเข้า
	WQMeshKit.box(st, Vector3(0, 2.1, pd * 0.5 + 0.85), Vector3(3.0, 0.16, 1.7), &"accent_wood")
	for sx in [-1.0, 1.0]:
		WQMeshKit.cylinder_y(st, Vector3(sx * 1.3, 0, pd * 0.5 + 1.5), 0.11, 2.1, 6, &"neutral_1")
	_door(st, Vector3(0, 0, pd * 0.5), 1.2, 1.5)


# ========== ชิ้นส่วนที่ใช้ซ้ำระหว่างอาคาร ==========

## แถบหน้าต่างของทุกชั้น วางเฉพาะหน้า +Z กับ +X
## (กล้อง isometric อยู่มุม +X/+Z เสมอ อีกสองด้านผู้เล่นไม่มีวันเห็น — ใส่ไปก็เปลืองงบสามเหลี่ยม)
static func _floors(st: SurfaceTool, w: float, d: float, fh: float, floors: int,
		frac: float, cols: int, slot: StringName) -> void:
	var cw := w * frac / float(cols) * 0.68
	var dw := d * frac / float(cols) * 0.68
	for f in floors:
		var y := float(f) * fh + fh * 0.58
		for c in cols:
			var t := (float(c) + 0.5) / float(cols) - 0.5
			WQMeshKit.box(st, Vector3(t * w * frac, y, d * 0.5 + 0.02),
				Vector3(cw, fh * 0.46, 0.08), slot)
			WQMeshKit.box(st, Vector3(w * 0.5 + 0.02, y, t * d * frac),
				Vector3(0.08, fh * 0.46, dw), slot)


static func _window(st: SurfaceTool, at: Vector3, w: float, h: float, on_x := false) -> void:
	var size := Vector3(0.08, h, w) if on_x else Vector3(w, h, 0.08)
	var off := Vector3(0.03 * signf(at.x), 0, 0) if on_x else Vector3(0, 0, 0.03)
	WQMeshKit.box(st, at + off, size, &"accent_steel")


static func _door(st: SurfaceTool, base: Vector3, w: float, h: float) -> void:
	WQMeshKit.box(st, base + Vector3(0, h * 0.5, 0.04), Vector3(w, h, 0.1), &"neutral_5")
	WQMeshKit.box(st, base + Vector3(0, h + 0.06, 0.06), Vector3(w + 0.2, 0.12, 0.14), &"neutral_1")


## กันสาดเหนือทางเข้า — ของชิ้นเล็กที่ทำให้ตึกสูงไม่ดูเหมือนแท่งที่ปักลงพื้นเฉยๆ
static func _canopy(st: SurfaceTool, front_z: float, w: float) -> void:
	WQMeshKit.box(st, Vector3(0, 2.25, front_z + 0.45), Vector3(w, 0.14, 0.9), &"neutral_1")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * w * 0.42, 1.6, front_z + 0.8),
			Vector3(0.1, 1.3, 0.1), &"neutral_1")


# ========== prop รอบตึก ==========

static func _prop(st: SurfaceTool, id: String) -> void:
	match id:
		"tree": _tree(st)
		"lamp": _lamp(st)
		"bench": _bench(st)


## ต้นไม้ — พุ่มสามชั้นสอบขึ้น เหลี่ยมชัด ไม่เอาทรงกลมเนียน
static func _tree(st: SurfaceTool) -> void:
	WQMeshKit.cylinder_y(st, Vector3.ZERO, 0.11, 0.95, 6, &"accent_wood")
	WQMeshKit.taper(st, Vector3(0, 0.8, 0), Vector3(1.35, 0, 1.35), 0.85, 0.62, &"foliage")
	WQMeshKit.taper(st, Vector3(0, 1.5, 0), Vector3(1.0, 0, 1.0), 0.8, 0.35, &"foliage")
	WQMeshKit.taper(st, Vector3(0, 2.15, 0), Vector3(0.6, 0, 0.6), 0.6, 0.0, &"foliage")


## เสาไฟ — โคมยื่นข้างเดียว หันไปทางถนน (+Z) เหมือนเสาไฟจริง
static func _lamp(st: SurfaceTool) -> void:
	WQMeshKit.box(st, Vector3(0, 0.09, 0), Vector3(0.36, 0.18, 0.36), &"neutral_5")
	WQMeshKit.cylinder_y(st, Vector3(0, 0.15, 0), 0.075, 3.1, 6, &"neutral_4")
	WQMeshKit.box(st, Vector3(0, 3.22, 0.32), Vector3(0.1, 0.1, 0.75), &"neutral_4")
	WQMeshKit.box(st, Vector3(0, 3.12, 0.66), Vector3(0.3, 0.16, 0.5), &"neutral_1")


## ม้านั่ง — หันหน้าไปทางถนน (+Z) เหมือนกัน เพื่อให้ทางเท้าดูมีทิศทางเดียวกันทั้งเส้น
static func _bench(st: SurfaceTool) -> void:
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 0.55, 0.2, 0), Vector3(0.1, 0.4, 0.42), &"neutral_5")
	WQMeshKit.box(st, Vector3(0, 0.44, 0), Vector3(1.4, 0.09, 0.46), &"accent_wood")
	WQMeshKit.box(st, Vector3(0, 0.72, -0.2), Vector3(1.4, 0.42, 0.08), &"accent_wood")
	WQMeshKit.box(st, Vector3(0, 0.5, -0.14), Vector3(1.4, 0.08, 0.1), &"accent_wood")


# ========== แคชเมชของ prop ==========
## prop ชิ้นเดียวกันถูกวางซ้ำหลายสิบจุดทั่วเมือง ต่อกล่องใหม่ทุกจุดคือการเสียแรงเปล่า
## เก็บ Mesh ไว้ใบเดียวแล้วแจก MeshInstance3D ที่ชี้มาที่ใบเดิม — Godot จะรวมเป็น draw call เดียวกันได้

static var _prop_mesh_cache := {}


static func prop_mesh(id: String) -> Mesh:
	if not PROPS.has(id): return null
	if not _prop_mesh_cache.has(id):
		var st := WQMeshKit.begin()
		_prop(st, id)
		_prop_mesh_cache[id] = st.commit()
	return _prop_mesh_cache[id]


static func prop_instance(id: String) -> MeshInstance3D:
	var mesh := prop_mesh(id)
	if mesh == null: return null
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = mesh
	mi.material_override = load(WQMeshKit.FLAT_MAT)
	return mi
