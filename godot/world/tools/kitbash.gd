class_name WQKitbash
extends RefCounted
## เมช "ต่อกล่อง" ที่สร้างจากโค้ด — ของชั่วคราวระหว่างรอโมเดล .glb จากคนปั้น
##
## ทำไมต้องมี: กล่องเปล่าใบเดียวจาก Sprint A ทำให้ดูไม่ออกว่ารถหรูต่างจากรถใหม่ตรงไหน
## ซึ่งเป็นหัวใจของกับดักที่ GDD 3A.2 ตั้งใจวางไว้ — ของต้องดูน่าอยากก่อน ตัวเลขถึงจะเบรกได้
##
## กติกาเดียวกับโมเดลจริงทุกข้อ เพื่อให้สลับเป็น .glb ทีหลังแล้วไม่มีอะไรเปลี่ยน:
##   · origin อยู่ที่ฐาน (y=0) · 1 unit = 1 เมตร · หันหน้า −Z
##   · flat shading (normal ต่อหน้า ไม่เกลี่ยข้ามหน้า)
##   · **วัสดุเดียวคือ world/materials/flat.tres** ไม่มีการ duplicate ไม่มี albedo_color
##     สีมาจากการ map UV ไปที่ช่องบนแผ่น palette.png ตามที่ ART-DIRECTION ข้อ 2.1 วางไว้
##
## งบสามเหลี่ยม (ART-DIRECTION 2.1): prop เล็ก 50–300 · พาหนะ 300–900
## world/tools/model_lint.gd เป็นคนตรวจว่าเกินหรือยัง

const FLAT_MAT := "res://world/materials/flat.tres"

## id ที่ต่อกล่องไว้แล้ว — ตรงกับ id ใน data/places.json เป๊ะ
const VEHICLES := ["public", "moto", "usedcar", "newcar", "luxury"]
const DEVICES := ["smartphone", "laptop"]


static func has(kind: String, id: String) -> bool:
	match kind:
		"vehicles": return VEHICLES.has(id)
		"devices": return DEVICES.has(id)
		"character": return id == "player"
	# อาคาร/prop และของบนแท่นโชว์อยู่คนละไฟล์เพราะยาวกว่าพาหนะทั้งหมดรวมกัน
	# แต่เข้าทางเดียวกันที่นี่ — ทุกคนที่อยากได้เมชต่อกล่องต้องถามผ่าน WQKitbash เท่านั้น
	# จะได้ไม่มีใครหลุดรายการ (ตัวอบ .glb · ตัวอบไอคอน · model_lint ถามที่เดียวกันหมด)
	return WQKitbashPlaces.has(kind, id) or WQKitbashItems.has(kind, id)


## คืน MeshInstance3D พร้อมใช้ หรือ null ถ้ายังไม่ได้ต่อกล่องของชิ้นนี้ไว้
static func build(kind: String, id: String) -> MeshInstance3D:
	if not has(kind, id): return null
	if WQKitbashPlaces.has(kind, id): return WQKitbashPlaces.build(kind, id)
	if WQKitbashItems.has(kind, id): return WQKitbashItems.build(kind, id)
	# character/player คือตัวละครเปล่าไม่ใส่ชุดอาชีพ — ชุดอาชีพเป็นเรื่องของหน้าเลือกอาชีพเท่านั้น
	if kind == "character": return WQKitbashChar.build()
	var st := WQMeshKit.begin()
	match kind:
		"vehicles": _vehicle(st, id)
		"devices": _device(st, id)
	return WQMeshKit.finish(st, id)


# ========== พาหนะ ==========

static func _vehicle(st: SurfaceTool, id: String) -> void:
	match id:
		"public": _bus(st)
		"moto": _moto(st)
		"usedcar": _car(st, 1.78, 4.25, 0.62, 0.72, &"neutral_3", false, false)
		"newcar": _car(st, 1.84, 4.60, 0.60, 0.78, &"neutral_2", true, false)
		"luxury": _car(st, 1.96, 5.25, 0.50, 0.66, &"accent_wood", true, true)


## รถเก๋งหนึ่งคัน — ตัวถังล่าง + หลังคา + ล้อสี่วง แล้วแต่งเพิ่มตามระดับราคา
##   body_h  ความสูงตัวถังล่าง (เตี้ย = ดูสปอร์ต/แพง)
##   roof_h  ความสูงหลังคา
##   trim    มีแถบข้างสีอ่อน (รถใหม่ขึ้นไป)
##   posh    ของฟุ่มเฟือย: สปอยเลอร์ + สเกิร์ตข้าง + ไฟหน้าคู่ (เฉพาะรถหรู)
static func _car(st: SurfaceTool, w: float, l: float, body_h: float, roof_h: float,
		body: StringName, trim: bool, posh: bool) -> void:
	var wheel_r := 0.33
	var y0 := wheel_r * 0.55          # ท้องรถลอยเหนือพื้นนิดหน่อย

	_box(st, Vector3(0, y0 + body_h * 0.5, 0), Vector3(w, body_h, l), body)
	# ห้องโดยสารเป็นสองชั้น: แถบกระจกอยู่ล่าง หลังคาสีตัวถังปิดทับอยู่บน
	# ถ้าเอากล่องกระจกครอบหลังคาทั้งใบ (เคยทำแบบนั้น) หลังคาจะจมหาย
	# เหลือแต่ก้อนสีเหล็กก้อนเดียว จนดูไม่ออกว่ารถคันนี้สีอะไร
	var cabin_z := l * 0.06
	var glass_h := roof_h * 0.66
	_box(st, Vector3(0, y0 + body_h + glass_h * 0.5, cabin_z),
		Vector3(w * 0.89, glass_h, l * 0.52), &"accent_steel")
	# หลังคาแคบกว่าแถบกระจกนิดหน่อย ให้เห็นเป็นขอบหลังคาลาดเข้า
	_box(st, Vector3(0, y0 + body_h + glass_h + (roof_h - glass_h) * 0.5, cabin_z),
		Vector3(w * 0.84, roof_h - glass_h, l * 0.48), body)

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_wheel(st, Vector3(sx * w * 0.5, wheel_r, sz * l * 0.31), wheel_r, w * 0.09)

	if trim:
		for sx in [-1.0, 1.0]:
			_box(st, Vector3(sx * w * 0.5, y0 + body_h * 0.35, 0),
				Vector3(0.03, 0.07, l * 0.72), &"neutral_1")
	if posh:
		# สปอยเลอร์ท้าย + สเกิร์ตข้าง — รูปทรงเป็นตัวบอกว่า "ฟุ่มเฟือย" ไม่ใช่สี
		# (สี money/time/health ถูกจองไว้บอกสถานะ ห้ามเอามาทาของในฉาก)
		_box(st, Vector3(0, y0 + body_h + 0.10, -l * 0.47),
			Vector3(w * 0.82, 0.05, 0.28), &"neutral_1")
		for sx in [-1.0, 1.0]:
			_box(st, Vector3(sx * w * 0.44, y0 + body_h + 0.05, -l * 0.44),
				Vector3(0.06, 0.20, 0.10), &"neutral_1")
			_box(st, Vector3(sx * w * 0.5, y0 + 0.06, 0), Vector3(0.05, 0.10, l * 0.6), &"neutral_1")
	# ไฟหน้า
	for sx in [-1.0, 1.0]:
		_box(st, Vector3(sx * w * 0.32, y0 + body_h * 0.62, l * 0.5),
			Vector3(w * 0.22, 0.10, 0.04), &"neutral_1")


static func _bus(st: SurfaceTool) -> void:
	var w := 2.45
	var l := 8.2
	var h := 2.05
	var wheel_r := 0.48
	var y0 := wheel_r * 0.7
	_box(st, Vector3(0, y0 + h * 0.5, 0), Vector3(w, h, l), &"neutral_2")
	# แถบหน้าต่างยาวตลอดคัน — อ่านออกทันทีว่าเป็นรถโดยสาร ไม่ใช่รถบรรทุก
	for sx in [-1.0, 1.0]:
		_box(st, Vector3(sx * w * 0.5, y0 + h * 0.68, 0),
			Vector3(0.04, h * 0.34, l * 0.86), &"accent_steel")
	_box(st, Vector3(0, y0 + h * 0.68, l * 0.5), Vector3(w * 0.9, h * 0.36, 0.05), &"accent_steel")
	_box(st, Vector3(0, y0 + h + 0.06, 0), Vector3(w * 0.86, 0.12, l * 0.9), &"neutral_3")
	for sz in [-0.34, 0.30]:
		for sx in [-1.0, 1.0]:
			_wheel(st, Vector3(sx * w * 0.5, wheel_r, sz * l), wheel_r, w * 0.08)


static func _moto(st: SurfaceTool) -> void:
	var wheel_r := 0.30
	_box(st, Vector3(0, 0.56, -0.05), Vector3(0.30, 0.26, 1.05), &"accent_steel")   # ตัวถัง
	_box(st, Vector3(0, 0.75, -0.30), Vector3(0.34, 0.14, 0.52), &"neutral_5")      # เบาะ
	_box(st, Vector3(0, 0.80, 0.36), Vector3(0.30, 0.34, 0.22), &"accent_steel")    # หน้ากาก
	_box(st, Vector3(0, 0.98, 0.30), Vector3(0.62, 0.05, 0.05), &"neutral_5")       # แฮนด์
	_box(st, Vector3(0, 1.02, 0.40), Vector3(0.16, 0.10, 0.04), &"neutral_1")       # ไฟหน้า
	_wheel(st, Vector3(0, wheel_r, 0.62), wheel_r, 0.11)
	_wheel(st, Vector3(0, wheel_r, -0.62), wheel_r, 0.13)


## ล้อ = ทรงกระบอกนอน 10 เหลี่ยม (เหลี่ยมชัดตามสไตล์ ไม่เอาวงกลมเนียน) + ดุมสีอ่อน
static func _wheel(st: SurfaceTool, at: Vector3, r: float, half_w: float) -> void:
	_cylinder_x(st, at, r, half_w, 10, &"neutral_5")
	_cylinder_x(st, at, r * 0.45, half_w * 1.12, 10, &"neutral_3")


# ========== อุปกรณ์ ==========

static func _device(st: SurfaceTool, id: String) -> void:
	match id:
		"smartphone": _phone(st)
		"laptop": _laptop(st)


## ของจริงขนาด 7 ซม. — วางตั้งบนขาตั้งเล็กๆ ไม่งั้นจะเห็นเป็นแผ่นบางๆ จากมุมกล้อง
static func _phone(st: SurfaceTool) -> void:
	_box(st, Vector3(0, 0.025, 0), Vector3(0.10, 0.05, 0.05), &"neutral_4")       # ขาตั้ง
	_box(st, Vector3(0, 0.13, 0), Vector3(0.075, 0.155, 0.009), &"neutral_5")     # ตัวเครื่อง
	_box(st, Vector3(0, 0.135, 0.006), Vector3(0.066, 0.132, 0.002), &"accent_steel")  # จอ


static func _laptop(st: SurfaceTool) -> void:
	_box(st, Vector3(0, 0.008, 0), Vector3(0.33, 0.016, 0.23), &"neutral_3")      # ฐาน
	_box(st, Vector3(0, 0.018, -0.02), Vector3(0.28, 0.004, 0.15), &"neutral_5")  # คีย์บอร์ด
	# จอเอนไปหลังนิดหน่อย ให้ดูเป็นโน้ตบุ๊กเปิดอยู่ ไม่ใช่กล่องแบน
	_box(st, Vector3(0, 0.115, -0.125), Vector3(0.33, 0.205, 0.014), &"neutral_3")
	_box(st, Vector3(0, 0.115, -0.116), Vector3(0.30, 0.18, 0.003), &"accent_steel")


# ========== ตัวต่อพื้นฐาน ==========
## ตัวต่อจริงอยู่ใน world/tools/meshkit.gd — ที่นี่เหลือแต่ชื่อเดิมไว้ให้โค้ดพาหนะเรียกเหมือนเดิม
## (Sprint C ย้ายออกไปเพราะอาคารกับ prop ในฉากเมืองต้องใช้ตัวต่อชุดเดียวกันเป๊ะ)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, slot: StringName) -> void:
	WQMeshKit.tri(st, a, b, c, slot)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		slot: StringName) -> void:
	WQMeshKit.quad(st, a, b, c, d, slot)


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, slot: StringName) -> void:
	WQMeshKit.box(st, center, size, slot)


static func _cylinder_x(st: SurfaceTool, center: Vector3, r: float, half_w: float,
		segments: int, slot: StringName) -> void:
	WQMeshKit.cylinder_x(st, center, r, half_w, segments, slot)
