class_name WQPlaceNode
extends Node3D
## อาคารหนึ่งหลังในฉากเมือง พร้อม prop รอบตึก (ต้นไม้ · ม้านั่ง)
##
## กฎเหล็ก (ART-DIRECTION 4.1): โหนดนี้ **อ่านอย่างเดียว** ไม่แตะ state ของเกม
## คลิกแล้วแค่บอก city.gd ว่าโดนคลิก คนตัดสินใจว่าจะเดินทางไหมคือ ui/main.gd
##
## ตัวอาคารมาจาก WQShowcase.model_for("places", id) — ทางเดียวกับที่แท่นโชว์และตัวอบไอคอนใช้
## เพื่อให้ตึกในเมือง ของบนแท่นโชว์ และไอคอนใน UI เป็นเมชชิ้นเดียวกันเสมอ
## ลำดับคือ .glb จริง → เมชต่อกล่อง (WQKitbashPlaces) → กล่องเปล่า
##
## **ตำแหน่ง prop ทุกชิ้นคำนวณจาก x ของสถานที่ ห้ามสุ่ม** (ART-DIRECTION 4.1 ข้อ 3)
## ถ้าสุ่ม เมืองจะสลับหน้าตาทุกครั้งที่เปิดเกม แล้วผู้เล่นจะจำไม่ได้ว่าตึกไหนคืออะไร

const SIGN_HEIGHT := 0.9        ## ป้ายชื่อลอยเหนือหลังคาเท่านี้
const STAND_GAP := 1.2          ## ตัวละครยืนห่างจากหน้าอาคารเท่านี้
const STAND_MIN_Z := 5.3        ## แต่ไม่ใกล้กว่าขอบทางเท้า — ตัวละครต้องยืนบนทางเท้าเสมอ
const FLAT_MAT := "res://world/materials/flat.tres"

var place: Dictionary = {}
var stand_point := Vector3.ZERO ## จุดที่ตัวละครไปยืนเมื่อมาถึงที่นี่
var bounds := AABB()            ## กรอบจริงของ "ตัวอาคาร" เท่านั้น (ไม่รวม prop บนทางเท้า)
var size := Vector3.ONE         ## ขนาดจริงของอาคารหลังนี้ (จาก AABB ของเมช)

var _body: MeshInstance3D       ## null เมื่อใช้โมเดล/เมชต่อกล่อง — มีค่าเฉพาะตอนตกกลับไปใช้กล่องเปล่า
var _sign: Label3D
var _ring: MeshInstance3D       ## วงไฟที่ฐาน บอกว่าอาคารนี้กำลังถูกชี้/ยืนอยู่
var _base_color := Color.WHITE


func setup(p: Dictionary, world_pos: Vector3) -> void:
	place = p
	position = world_pos

	var model := WQShowcase.model_for("places", String(p.id))
	add_child(model)
	bounds = WQShowcase.aabb_of(model)
	size = bounds.size

	# กล่องเปล่าของ Showcase สูงแค่ 1.1 ม. ซึ่งเตี้ยกว่าตัวละคร — ถ้าหลุดมาถึงตรงนี้แปลว่า
	# ยังไม่มีทั้ง .glb และเมชต่อกล่องของสถานที่นี้ ให้ขยายเป็นกล่องขนาดอาคารแทน
	# และคิดขนาดจาก x เหมือนเดิม เพื่อให้เมืองยังอ่านออกว่าหลังไหนเป็นหลังไหน
	if model.name == "Placeholder":
		_body = model as MeshInstance3D
		var h := 2.0 + float(int(p.x) % 7) * 0.6
		var w := 2.4 + float(int(p.x) % 3) * 0.4
		(_body.mesh as BoxMesh).size = Vector3(w, h, w)
		_body.position.y = h * 0.5
		_base_color = Color(String(p.color)).darkened(0.15) if p.has("color") else Color("8b8578")
		_body.material_override = _mat(_base_color)
		size = Vector3(w, h, w)
		bounds = AABB(Vector3(-w * 0.5, 0, -w * 0.5), size)

	_ring = _footprint()
	add_child(_ring)

	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.text = "%s %s" % [p.get("icon", ""), p.get("name", p.id)]
	_sign.font = WQFonts.thai()
	_sign.font_size = 64
	_sign.pixel_size = 0.014
	# เหลื่อมความสูงป้ายตาม x — บ้าน ฟิตเนส ธนาคาร อยู่ห่างกันแค่ 3 หน่วย
	# ถ้าป้ายทั้งสามลอยที่ความสูงเท่ากัน ตัวหนังสือจะทับกันจนอ่านไม่ออกสักอัน
	# หาร 5 ไม่ใช่ 3 — บ้าน(50) ฟิตเนส(56) ธนาคาร(62) หารสามแล้วเหลือเศษ 2 เท่ากันทั้งสามหลัง
	# ป้ายเลยลอยสูงเท่ากันเหมือนเดิม หาร 5 ได้ 0/1/2 คนละชั้นจริง
	_sign.position = Vector3(0, size.y + SIGN_HEIGHT + float(int(p.x) % 5) * 0.7, 0)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = true
	_sign.outline_size = 16
	_sign.outline_modulate = WQPalette.BG_DEEP
	add_child(_sign)

	# วัดจาก "หน้าอาคารจริง" ไม่ใช่ครึ่งหนึ่งของความลึก เพราะของหน้าอาคาร (บันได สระ กันสาด)
	# ทำให้ทรงแต่ละหลังไม่ได้สมมาตรรอบ z=0 — ถ้าใช้ size.z*0.5 ตัวละครจะไปยืนจมอยู่ในบันได
	stand_point = position + Vector3(0, 0, maxf(bounds.end.z + STAND_GAP, STAND_MIN_Z))


## วงสว่างที่ฐานอาคาร — ใช้บอกไฮไลต์แทนการเปลี่ยนสีตัวอาคาร
## เพราะเมชอาคารใช้สีจากแผ่น palette ทั้งชิ้น (ห้ามตั้ง albedo_color รายชิ้น ตาม ART-DIRECTION 2.1)
## จะย้อมให้สว่างขึ้นทีละหลังไม่ได้เลย — และวงที่พื้นยังอ่านง่ายกว่าในมุมกล้อง isometric
func _footprint() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Footprint"
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x + 1.6, size.z + 1.6)
	mi.mesh = pm
	mi.position.y = 0.03
	var m := _mat(WQPalette.NEUTRAL_1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(WQPalette.NEUTRAL_1, 0.16)
	mi.material_override = m
	mi.visible = false
	return mi


## ไฮไลต์ตอนเมาส์ชี้ / ตอนเป็นที่ที่ผู้เล่นยืนอยู่ — บอกด้วยความสว่าง ไม่ใช่สีใหม่
## เพราะสีในเกมนี้ถูกจองไว้บอกความหมาย (เงิน/เวลา/สุขภาพ) แล้ว
func set_highlight(on: bool) -> void:
	if _ring != null: _ring.visible = on
	if _body == null or _body.mesh == null: return
	_body.material_override = _mat(_base_color.lightened(0.35) if on else _base_color)


func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	m.albedo_texture = null      # เมชพื้นฐาน UV กินทั้งแผ่น palette จะได้แถบสีรุ้งแทนสีเดียว
	m.albedo_color = c
	return m
