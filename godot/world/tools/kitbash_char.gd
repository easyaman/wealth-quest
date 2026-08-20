class_name WQKitbashChar
extends RefCounted
## ตัวละครผู้เล่นเป็นเมชต่อกล่อง + "ชุดอาชีพ" สำหรับหน้าเลือกอาชีพ (Sprint C ข้อ 5)
##
## ทำไมต้องมีชุดอาชีพ: หน้าเลือกอาชีพคือจุดที่ผู้เล่นตัดสินใจครั้งใหญ่ที่สุดของเกม (GDD บทที่ 7)
## ถ้าทุกอาชีพโชว์ตัวละครหน้าตาเหมือนกันหมด แท่นโชว์ก็ไม่ได้ช่วยตัดสินใจอะไรเลย
## เหลือแค่ตัวเลข — ซึ่งขัดกับ ART-DIRECTION ข้อ 1.3 ที่ให้ "ของต้องดูน่าอยากก่อน ตัวเลขค่อยเบรก"
##
## ชุดอาชีพประกอบจากคำศัพท์สามช่อง: หมวก · เสื้อ · ของที่ถือ
## 16 อาชีพจึงใช้ชิ้นส่วนไม่กี่ชิ้นมาสลับกัน แทนที่จะปั้นตัวละคร 16 ตัวแยกกัน
## (และวันที่มี .glb จริงของอาชีพไหน ก็วางทับที่ world/models/character/ ได้ตามปกติ)
##
## กติกาเดียวกับโมเดลอื่นทุกข้อ: origin ที่ฐาน · หันหน้า +Z · วัสดุเดียว · สีจากช่อง palette

## [หมวก, เสื้อ, ของที่ถือ] ต่ออาชีพ — id ตรงกับ data/jobs.json เป๊ะ
const OUTFIT := {
	"cleaner": ["cap", "apron", "bucket"],
	"convstore": ["cap", "apron", "none"],
	"rider": ["helmet", "vest", "box"],
	"teacher": ["none", "none", "book"],
	"nurse": ["nursecap", "coat", "none"],
	"technician": ["hardhat", "vest", "tool"],
	"accountant": ["none", "shirt", "case"],
	"police": ["peaked", "uniform", "none"],
	"engineer": ["hardhat", "vest", "tool"],
	"programmer": ["none", "shirt", "laptop"],
	"cafeowner": ["cap", "apron", "cup"],
	"salesmgr": ["none", "suit", "case"],
	"doctor": ["none", "coat", "board"],
	"lawyer": ["none", "suit", "book"],
	"pilot": ["peaked", "uniform", "none"],
	"executive": ["none", "suit", "case"],
}

const HEAD_Y := 1.46             ## ระดับกลางศีรษะ — จุดอ้างของหมวกทุกใบ
const HAND_Y := 0.78             ## ระดับมือที่ปล่อยข้างลำตัว — จุดอ้างของของที่ถือ


static func has_outfit(job_id: String) -> bool:
	return OUTFIT.has(job_id)


## job_id ว่าง = ตัวละครเปล่าๆ ไม่ใส่ชุดอาชีพ (ใช้เป็นโมเดล character/player ของเกม)
static func build(job_id := "") -> MeshInstance3D:
	var st := WQMeshKit.begin()
	_body(st)
	if OUTFIT.has(job_id):
		var kit: Array = OUTFIT[job_id]
		_hat(st, String(kit[0]))
		_top(st, String(kit[1]))
		_held(st, String(kit[2]))
	return WQMeshKit.finish(st, "player" if job_id == "" else job_id)


## ร่างพื้นฐาน — สัดส่วนเดียวกับตัวละครในฉากเมือง (world/city/avatar.gd)
## ต้องเป็นคนเดียวกันให้ได้ ไม่งั้นคนที่เลือกในหน้าเลือกอาชีพจะไม่ใช่คนที่เดินอยู่ในเมือง
static func _body(st: SurfaceTool) -> void:
	for sx in [-1.0, 1.0]:
		WQMeshKit.cylinder_y(st, Vector3(sx * 0.13, 0.0, 0), 0.09, 0.72, 8, &"neutral_4")
		WQMeshKit.box(st, Vector3(sx * 0.13, 0.05, 0.05), Vector3(0.2, 0.1, 0.3), &"neutral_5")
		# แขนต้องยาวถึงระดับบ่า (ยอดลำตัวอยู่ที่ 1.38) ไม่งั้นจะเห็นเป็นช่องว่างที่หัวไหล่
		# แล้วแขนจะดูเหมือนก้อนที่ลอยอยู่ข้างตัว ไม่ใช่แขนของคนคนนี้
		WQMeshKit.cylinder_y(st, Vector3(sx * 0.29, 0.74, 0), 0.07, 0.62, 8, &"neutral_2")
		WQMeshKit.box(st, Vector3(sx * 0.29, 1.34, 0), Vector3(0.19, 0.14, 0.24), &"accent_steel")
		WQMeshKit.box(st, Vector3(sx * 0.29, 0.75, 0), Vector3(0.15, 0.12, 0.15), &"neutral_2")
	WQMeshKit.box(st, Vector3(0, 0.8, 0), Vector3(0.5, 0.16, 0.3), &"neutral_5")      # เข็มขัด/สะโพก
	WQMeshKit.box(st, Vector3(0, 1.1, 0), Vector3(0.46, 0.56, 0.28), &"accent_steel") # ลำตัว
	# สาบเสื้อเล็กๆ พอให้รู้ว่าใส่เสื้ออยู่ — เคยทำใหญ่กว่านี้แล้วมันอ่านเป็นเอี๊ยมพาดหน้าอก
	WQMeshKit.box(st, Vector3(0, 1.16, 0.145), Vector3(0.09, 0.22, 0.02), &"neutral_1")
	WQMeshKit.cylinder_y(st, Vector3(0, 1.36, 0), 0.075, 0.08, 8, &"neutral_2")       # คอ
	WQMeshKit.box(st, Vector3(0, HEAD_Y, 0), Vector3(0.3, 0.32, 0.3), &"neutral_2")   # ศีรษะ
	WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.15, -0.02), Vector3(0.32, 0.1, 0.32), &"neutral_5")
	for sx in [-1.0, 1.0]:
		WQMeshKit.box(st, Vector3(sx * 0.07, HEAD_Y + 0.03, 0.15),
			Vector3(0.06, 0.05, 0.02), &"neutral_5")                                  # ตา
		WQMeshKit.box(st, Vector3(sx * 0.16, HEAD_Y, 0), Vector3(0.03, 0.1, 0.1), &"neutral_2")


static func _hat(st: SurfaceTool, kind: String) -> void:
	match kind:
		"cap":
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.21, -0.01), Vector3(0.33, 0.12, 0.33),
				&"accent_wood")
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.17, 0.21), Vector3(0.3, 0.05, 0.16),
				&"accent_wood")
		"hardhat":
			# หมวกนิรภัยมีสันกลางหมวก — เป็นสิ่งที่ทำให้แยกออกจากหมวกแก๊ปในเงาดำ
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.22, 0), Vector3(0.36, 0.16, 0.36),
				&"neutral_1")
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.31, 0), Vector3(0.1, 0.06, 0.36),
				&"neutral_1")
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.15, 0), Vector3(0.44, 0.05, 0.44),
				&"neutral_1")
		"peaked":
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.22, -0.01), Vector3(0.34, 0.14, 0.34),
				&"accent_steel")
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.16, 0.22), Vector3(0.34, 0.05, 0.18),
				&"neutral_5")
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.2, 0.17), Vector3(0.3, 0.07, 0.03),
				&"neutral_1")
		"nursecap":
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.2, -0.02), Vector3(0.3, 0.12, 0.26),
				&"neutral_1")
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.21, 0.11), Vector3(0.1, 0.04, 0.04),
				&"danger")
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.21, 0.11), Vector3(0.04, 0.1, 0.04),
				&"danger")
		"helmet":
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.13, 0), Vector3(0.38, 0.34, 0.38),
				&"neutral_1")
			WQMeshKit.box(st, Vector3(0, HEAD_Y + 0.08, 0.2), Vector3(0.3, 0.14, 0.04),
				&"accent_steel")


static func _top(st: SurfaceTool, kind: String) -> void:
	match kind:
		"apron":
			WQMeshKit.box(st, Vector3(0, 1.02, 0.155), Vector3(0.4, 0.62, 0.03), &"neutral_1")
			for sx in [-1.0, 1.0]:
				WQMeshKit.box(st, Vector3(sx * 0.13, 1.32, 0.14), Vector3(0.05, 0.16, 0.03),
					&"neutral_1")
		"vest":
			# เสื้อกั๊กสะท้อนแสงมีแถบขวางสองเส้น — อ่านออกทันทีว่าเป็นงานภาคสนาม
			WQMeshKit.box(st, Vector3(0, 1.1, 0.15), Vector3(0.48, 0.5, 0.04), &"accent_wood")
			for i in 2:
				WQMeshKit.box(st, Vector3(0, 0.98 + float(i) * 0.2, 0.175),
					Vector3(0.48, 0.06, 0.03), &"neutral_1")
		"coat":
			WQMeshKit.box(st, Vector3(0, 1.0, 0.15), Vector3(0.5, 0.72, 0.04), &"neutral_1")
			WQMeshKit.box(st, Vector3(0.15, 0.92, 0.18), Vector3(0.14, 0.14, 0.02), &"neutral_2")
		"shirt":
			WQMeshKit.box(st, Vector3(0, 1.16, 0.15), Vector3(0.44, 0.42, 0.03), &"neutral_1")
		"uniform":
			WQMeshKit.box(st, Vector3(0, 1.14, 0.15), Vector3(0.46, 0.46, 0.03), &"accent_steel")
			for sx in [-1.0, 1.0]:
				WQMeshKit.box(st, Vector3(sx * 0.19, 1.36, 0.02), Vector3(0.14, 0.05, 0.2),
					&"neutral_1")
		"suit":
			WQMeshKit.box(st, Vector3(0, 1.1, 0.15), Vector3(0.48, 0.56, 0.03), &"neutral_5")
			WQMeshKit.box(st, Vector3(0, 1.22, 0.17), Vector3(0.07, 0.3, 0.02), &"danger")
			WQMeshKit.box(st, Vector3(0, 1.36, 0.16), Vector3(0.16, 0.06, 0.03), &"neutral_1")


static func _held(st: SurfaceTool, kind: String) -> void:
	var x := 0.42       # ของอยู่ในมือขวา (ฝั่ง +X) เสมอ เพื่อไม่ให้บังสาบเสื้อ
	match kind:
		"bucket":
			WQMeshKit.cylinder_y(st, Vector3(x, 0.0, 0.1), 0.16, 0.3, 8, &"accent_steel")
			WQMeshKit.box(st, Vector3(x, 0.36, 0.1), Vector3(0.34, 0.04, 0.04), &"neutral_5")
		"box":
			WQMeshKit.box(st, Vector3(0, 1.12, -0.28), Vector3(0.42, 0.42, 0.3), &"accent_wood")
			WQMeshKit.box(st, Vector3(0, 1.12, -0.44), Vector3(0.3, 0.3, 0.03), &"neutral_1")
		"book":
			WQMeshKit.box(st, Vector3(x, HAND_Y + 0.05, 0.14), Vector3(0.06, 0.24, 0.2),
				&"accent_wood")
			WQMeshKit.box(st, Vector3(x + 0.04, HAND_Y + 0.05, 0.14), Vector3(0.03, 0.21, 0.18),
				&"neutral_1")
		"tool":
			WQMeshKit.box(st, Vector3(x, HAND_Y, 0.08), Vector3(0.05, 0.34, 0.05), &"neutral_5")
			WQMeshKit.box(st, Vector3(x, HAND_Y + 0.2, 0.08), Vector3(0.14, 0.08, 0.08),
				&"accent_steel")
		"case":
			WQMeshKit.box(st, Vector3(x, HAND_Y - 0.06, 0.06), Vector3(0.1, 0.3, 0.4),
				&"accent_wood")
			WQMeshKit.box(st, Vector3(x, HAND_Y + 0.12, 0.06), Vector3(0.04, 0.1, 0.12),
				&"neutral_5")
		"laptop":
			WQMeshKit.box(st, Vector3(x, HAND_Y + 0.02, 0.14), Vector3(0.06, 0.26, 0.34),
				&"neutral_4")
			WQMeshKit.box(st, Vector3(x + 0.04, HAND_Y + 0.02, 0.14), Vector3(0.02, 0.22, 0.3),
				&"accent_steel")
		"cup":
			WQMeshKit.cylinder_y(st, Vector3(x, HAND_Y, 0.12), 0.07, 0.16, 8, &"neutral_1")
			WQMeshKit.box(st, Vector3(x, HAND_Y + 0.17, 0.12), Vector3(0.16, 0.02, 0.16),
				&"accent_wood")
		"board":
			WQMeshKit.box(st, Vector3(x, HAND_Y + 0.06, 0.12), Vector3(0.05, 0.3, 0.24),
				&"neutral_1")
			WQMeshKit.box(st, Vector3(x + 0.03, HAND_Y + 0.18, 0.12), Vector3(0.03, 0.06, 0.16),
				&"accent_steel")
